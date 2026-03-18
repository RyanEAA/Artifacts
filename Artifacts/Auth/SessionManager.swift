//
//  SessionManager.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/3/25.
//

import FirebaseAuth
import Firebase
import FirebaseFirestore

@MainActor
final class SessionManager: ObservableObject {
    @Published var user: User?
    @Published var userData: [String: Any]?
    @Published var errorMessage: String?

    @Published var isLoading = true
    @Published var isAuthInFlight = false

    private let db = Firestore.firestore()
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?

    init() {
        listen()
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        userListener?.remove()
    }

    func listen() {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.user = user
                self.isLoading = false
                if let user {
                    NotificationService.shared.start(for: user.uid)
                    self.loadCachedUserData(uid: user.uid)
                    self.listenToUserData(uid: user.uid)
                } else {
                    NotificationService.shared.stop()
                    self.userListener?.remove()
                    self.userListener = nil
                    self.userData = nil
                    self.errorMessage = nil
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        guard !isAuthInFlight else { return }
        isAuthInFlight = true
        errorMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        Auth.auth().signIn(withEmail: cleanEmail, password: cleanPassword) { [weak self] _, error in
            guard let self else { return }
            Task { @MainActor in
                self.isAuthInFlight = false
                if let error = error as NSError? {
                    self.errorMessage = self.mapAuthError(error)
                } else {
                    self.errorMessage = nil
                }
            }
        }
    }

    func signUp(email: String, password: String, username: String) {
        guard !isAuthInFlight else { return }

        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validationError = validateUsername(normalizedUsername) {
            errorMessage = validationError
            return
        }

        isAuthInFlight = true
        errorMessage = nil

        isUsernameUniqueBestEffort(normalizedUsername) { [weak self] shouldProceed in
            guard let self else { return }
            Task { @MainActor in
                if !shouldProceed {
                    self.isAuthInFlight = false
                    self.errorMessage = "Username is already taken."
                    return
                }

                Auth.auth().createUser(withEmail: cleanEmail, password: cleanPassword) { [weak self] result, error in
                    guard let self else { return }
                    Task { @MainActor in
                        if let error = error as NSError? {
                            self.isAuthInFlight = false
                            self.errorMessage = self.mapAuthError(error)
                            return
                        }

                        guard let user = result?.user else {
                            self.isAuthInFlight = false
                            self.errorMessage = "Unable to create account. Please try again."
                            return
                        }

                        let userDoc: [String: Any] = [
                            "username": normalizedUsername,
                            "email": cleanEmail,
                            "createdAt": Timestamp(),
                            "lastActive": Timestamp()
                        ]

                        self.db.collection("users").document(user.uid).setData(userDoc, merge: true) { [weak self] err in
                            guard let self else { return }
                            Task { @MainActor in
                                self.isAuthInFlight = false
                                if let err {
                                    self.errorMessage = "Account created, but profile setup failed: \(err.localizedDescription)"
                                } else {
                                    self.userData = userDoc
                                    self.persistUserData(userDoc, uid: user.uid)
                                    self.listenToUserData(uid: user.uid)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func sendPasswordReset(email: String) {
        guard !isAuthInFlight else { return }
        isAuthInFlight = true
        errorMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else {
            isAuthInFlight = false
            errorMessage = "Enter your email to reset your password."
            return
        }

        Auth.auth().sendPasswordReset(withEmail: cleanEmail) { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                self.isAuthInFlight = false
                if let error = error as NSError? {
                    self.errorMessage = self.mapAuthError(error)
                } else {
                    self.errorMessage = "Password reset email sent."
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            NotificationService.shared.stop()
            userListener?.remove()
            userListener = nil
            user = nil
            userData = nil
            errorMessage = nil
        } catch let signOutError as NSError {
            errorMessage = "Failed to sign out: \(signOutError.localizedDescription)"
        }
    }

    func updateUsername(to rawUsername: String) async throws {
        guard let uid = user?.uid else {
            throw NSError(domain: "SessionManager", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "You must be signed in to update your username."
            ])
        }

        let normalized = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let validationError = validateUsername(normalized) {
            throw NSError(domain: "SessionManager", code: 400, userInfo: [
                NSLocalizedDescriptionKey: validationError
            ])
        }

        let existing = try await db.collection("users")
            .whereField("username", isEqualTo: normalized)
            .limit(to: 1)
            .getDocuments()

        if let takenDoc = existing.documents.first, takenDoc.documentID != uid {
            throw NSError(domain: "SessionManager", code: 409, userInfo: [
                NSLocalizedDescriptionKey: "Username is already taken."
            ])
        }

        try await db.collection("users").document(uid).setData([
            "username": normalized,
            "lastActive": Timestamp()
        ], merge: true)

        var updated = userData ?? [:]
        updated["username"] = normalized
        userData = updated
        persistUserData(updated, uid: uid)
    }

    func deleteCurrentAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw NSError(domain: "SessionManager", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "You must be signed in to delete your account."
            ])
        }

        let uid = firebaseUser.uid
        try await firebaseUser.delete()

        UserDefaults.standard.removeObject(forKey: cacheKey(for: uid))
        NotificationService.shared.stop()
        userListener?.remove()
        userListener = nil
        user = nil
        userData = nil
        errorMessage = nil
    }

    private func listenToUserData(uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let data = snapshot?.data() {
                        self.userData = data
                        self.persistUserData(data, uid: uid)
                    } else if let error {
                        print("Error fetching user data: \(error.localizedDescription)")
                    }
                }
            }
    }

    private func loadCachedUserData(uid: String) {
        guard
            let cached = UserDefaults.standard.data(forKey: cacheKey(for: uid)),
            let payload = try? JSONDecoder().decode(CachedUserProfile.self, from: cached)
        else { return }

        userData = payload.asDictionary
    }

    private func persistUserData(_ data: [String: Any], uid: String) {
        let payload = CachedUserProfile(
            username: data["username"] as? String,
            email: data["email"] as? String,
            profilePictureURL: data["profilePictureURL"] as? String
        )
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey(for: uid))
    }

    private func cacheKey(for uid: String) -> String {
        "Artifacts.cachedUserData.\(uid)"
    }

    private struct CachedUserProfile: Codable {
        let username: String?
        let email: String?
        let profilePictureURL: String?

        var asDictionary: [String: Any] {
            var result: [String: Any] = [:]
            if let username { result["username"] = username }
            if let email { result["email"] = email }
            if let profilePictureURL { result["profilePictureURL"] = profilePictureURL }
            return result
        }
    }

    private func validateUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Username cannot be empty." }
        if trimmed.count > 15 { return "Username cannot be longer than 15 characters." }
        if trimmed.contains(" ") { return "Username cannot contain spaces." }
        return nil
    }

    private func isUsernameUniqueBestEffort(_ username: String, completion: @escaping (Bool) -> Void) {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        db.collection("users").whereField("username", isEqualTo: normalized).limit(to: 1).getDocuments { snapshot, error in
            if let error {
                print("Username uniqueness check failed: \(error.localizedDescription)")
                completion(true)
                return
            }
            let isUnique = snapshot?.documents.isEmpty ?? true
            completion(isUnique)
        }
    }

    private func mapAuthError(_ error: NSError) -> String {
        let domain = error.domain
        let code = error.code

        if domain != AuthErrorDomain {
            return "Auth error: \(error.localizedDescription) (domain \(domain) code \(code))"
        }

        guard let authCode = AuthErrorCode(rawValue: code) else {
            return "Auth error: \(error.localizedDescription) (code \(code))"
        }

        switch authCode {
        case .invalidEmail:
            return "The email address is invalid."
        case .missingEmail:
            return "Email is required."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .invalidCredential:
            return "Invalid login credentials. Please check your email and password."
        case .userNotFound:
            return "No account found with this email."
        case .userDisabled:
            return "This account has been disabled."
        case .emailAlreadyInUse:
            return "The email is already registered."
        case .weakPassword:
            return "Password is too weak. Please use at least 6 characters."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .operationNotAllowed:
            return "This sign in method is not enabled for the app."
        case .appNotAuthorized:
            return "App is not authorized. Check Firebase configuration."
        default:
            return "Auth error: \(error.localizedDescription) (code \(code))"
        }
    }
}

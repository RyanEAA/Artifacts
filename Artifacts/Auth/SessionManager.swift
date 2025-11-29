//
//  SessionManager.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/3/25.
//

import FirebaseAuth
import Firebase

class SessionManager: ObservableObject {
    @Published var user: User?
    @Published var userData: [String: Any]?
    @Published var errorMessage: String?
    @Published var isLoading = true

    private let db = Firestore.firestore()

    init() {
        listen()
    }

    func listen() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
            self.isLoading = false
            if let user = user {
                self.fetchUserData(uid: user.uid)
            } else {
                self.userData = nil
                self.errorMessage = nil
            }
        }
    }

    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error as NSError? {
                self.errorMessage = self.mapAuthError(error)
            } else {
                self.errorMessage = nil
            }
        }
    }

    func signUp(email: String, password: String, username: String) {
        if let validationError = validateUsername(username) {
            self.errorMessage = validationError
            return
        }
        
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        isUsernameUnique(normalizedUsername) { isUnique in
            DispatchQueue.main.async {
                if !isUnique {
                    self.errorMessage = "Username is already taken."
                    return
                }
                
                Auth.auth().createUser(withEmail: email, password: password) { result, error in
                    if let error = error as NSError? {
                        self.errorMessage = self.mapAuthError(error)
                        return
                    }
                    
                    guard let user = result?.user else { return }
                    
                    let userDoc: [String: Any] = [
                        "username": normalizedUsername,
                        "email": email,
                        "createdAt": Timestamp(),
                        "lastActive": Timestamp(),
                        "profilePictureURL": NSNull()
                    ]
                    
                    self.db.collection("users").document(user.uid).setData(userDoc) { err in
                        if let err = err {
                            self.errorMessage = "Error saving user data: \(err.localizedDescription)"
                        } else {
                            self.fetchUserData(uid: user.uid)
                        }
                    }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.userData = nil
            self.errorMessage = nil
        } catch let signOutError as NSError {
            self.errorMessage = "Failed to sign out: \(signOutError.localizedDescription)"
        }
    }

    private func fetchUserData(uid: String) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.userData = data
            } else if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                // Best-effort fallback to auth user fields
                self.userData = [
                    "username": self.user?.email?.components(separatedBy: "@").first ?? "anonymous_user",
                    "email": self.user?.email ?? ""
                ]
            } else {
                // No data returned; populate a lightweight default so UI doesn't show anonymous
                self.userData = [
                    "username": self.user?.email?.components(separatedBy: "@").first ?? "anonymous_user",
                    "email": self.user?.email ?? ""
                ]
            }
        }
    }

    private func validateUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Username cannot be empty."
        }
        
        if trimmed.count > 15 {
            return "Username cannot be longer than 15 characters."
        }
        
        if trimmed.contains(" ") {
            return "Username cannot contain spaces."
        }
        
        return nil
    }

    private func isUsernameUnique(_ username: String, completion: @escaping (Bool) -> Void) {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let usersRef = db.collection("users")
        
        usersRef.whereField("username", isEqualTo: normalized).getDocuments { snapshot, error in
            if let error = error {
                print("Error checking username uniqueness: \(error.localizedDescription)")
                self.errorMessage = "Unable to check username. Please try again."
                completion(false)
                return
            }
            
            let isUnique = snapshot?.documents.isEmpty ?? true
            completion(isUnique)
        }
    }
    
    func updateUserProfile(username: String, bio: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        var updates: [String: Any] = [
            "username": username,
            "bio": bio
        ]

        do {
            try await Firestore.firestore().collection("users").document(uid).updateData(updates)
            DispatchQueue.main.async {
                self.userData?.merge(updates) { _, new in new }
            }
        } catch {
            print("Error updating Firestore user profile: \(error)")
        }
    }

    private func mapAuthError(_ error: NSError) -> String {
        guard error.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: error.code) else {
            return "An unexpected error occurred. Please try again."
        }

        switch code {
        case .invalidEmail:
            return "The email address is invalid."
        case .wrongPassword:
            return "Incorrect password. Please try again."
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
        default:
            return "Authentication failed. Please try again."
        }
    }
}

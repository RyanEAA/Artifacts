//
//  AppController.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import Foundation
import SwiftUI
import FirebaseAuth

@main
struct AppController: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var session = SessionManager()

    var body: some Scene {
        WindowGroup {
            if session.user != nil {
                RootTabView()
                    .environmentObject(session)
            } else {
                AuthView()
                    .environmentObject(session)
            }
        }
    }
}

class SessionManager: ObservableObject {
    @Published var user: User?
    @Published var errorMessage: String?

    init() {
        listen()
    }

    func listen() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
            if user == nil {
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

    func signUp(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            if let error = error as NSError? {
                self.errorMessage = self.mapAuthError(error)
            } else {
                self.errorMessage = nil
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.errorMessage = nil
        } catch let signOutError as NSError {
            self.errorMessage = "Failed to sign out: \(signOutError.localizedDescription)"
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

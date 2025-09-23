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
    // attach AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var session = SessionManager()

    var body: some Scene {
        WindowGroup {
            if session.user != nil {
                ProfileView()
                    .environmentObject(session)
            } else {
                AuthView()
                    .environmentObject(session)
            }
        }
    }
}

// Manages auth state + login/logout/signup
class SessionManager: ObservableObject {
    @Published var user: User?
    @Published var errorMessage: String?

    init() {
        listen()
    }

    func listen() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                self.errorMessage = nil
            }
        }
    }

    func signUp(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                self.errorMessage = nil
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        self.user = nil
    }
}

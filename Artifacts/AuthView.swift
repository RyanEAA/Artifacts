//
//  AuthView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject var session: SessionManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Login")
                .font(.largeTitle).bold()

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            if let error = session.errorMessage {
                Text(error).foregroundColor(.red)
            }

            Button("Sign In") {
                session.signIn(email: email, password: password)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            Button("Sign Up") {
                session.signUp(email: email, password: password)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

//
//  ProfileView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        VStack(spacing: 20) {
            if let user = session.user {
                Text("Welcome, \(user.email ?? "User")!")
                    .font(.title)
            }

            Button("Sign Out") {
                session.signOut()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}
#Preview {
    ProfileView()
}

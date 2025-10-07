//
//  ProfileView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showingEditProfile = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 120, height: 120)
                .foregroundColor(.gray)

            Text(session.userData?["username"] as? String ?? "Unknown User")
                .font(.title)
                .fontWeight(.bold)

            Text(session.userData?["bio"] as? String ?? "No bio yet.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(spacing: 40) {
                VStack {
                    Text("\(session.userData?["artifactsCount"] as? Int ?? 0)")
                        .font(.headline)
                    Text("Artifacts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(session.userData?["friendsCount"] as? Int ?? 0)")
                        .font(.headline)
                    Text("Friends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Edit Profile") {
                showingEditProfile.toggle()
            }
            .buttonStyle(.borderedProminent)

            Button("Sign Out") {
                session.signOut()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
                .environmentObject(session)
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var newUsername: String = ""
    @State private var newBio: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Username", text: $newUsername)
                    .textFieldStyle(.roundedBorder)

                TextField("Bio", text: $newBio, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 60)

                Spacer()

                Button("Save Changes") {
                    Task {
                        await session.updateUserProfile(username: newUsername, bio: newBio)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Edit Profile")
            .onAppear {
                newUsername = session.userData?["username"] as? String ?? ""
                newBio = session.userData?["bio"] as? String ?? ""
            }
        }
    }
}

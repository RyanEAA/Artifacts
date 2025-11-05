//
//  FriendsListSheet.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import SwiftUI

struct FriendsListSheet: View {
    
    @EnvironmentObject var session: SessionManager
    
    @Binding var friends: [String]


    private var username: String {
        (session.userData?["username"] as? String) ?? "anonymous_user"
    }

    @State private var search = ""
    @State private var addText = ""
//    @State private var friends: [String] = ["sarah_creates", "devon_art", "luna_doodles"]

    private var filtered: [String] {
        guard !search.isEmpty else { return friends }
        return friends.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        TextField("Search friends…", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Add friend
                    HStack(spacing: 8) {
                        TextField("Add friend by username…", text: $addText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundColor(.white)

                        Button {
                            let candidate = addText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !candidate.isEmpty,
                                  candidate != username,
                                  !friends.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame })
                            else { return }
                            friends.append(candidate)
                            addText = ""
                        } label: {
                            Text("Add")
                                .font(.subheadline.bold())
                                .foregroundColor(.black)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // List
                    if filtered.isEmpty {
                        Text("No friends found")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 20)
                    } else {
                        List {
                            ForEach(filtered, id: \.self) { name in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.white)
                                    Text(name)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(role: .destructive) {
                                        friends.removeAll { $0 == name }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .listRowBackground(Color.black)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
                .navigationTitle("Friends")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    FriendsListSheet(
        friends: .constant(["sarah_creates","devon_art","luna_doodles"])
    )
    .environmentObject(SessionManager())   // so `username` resolves in preview
}

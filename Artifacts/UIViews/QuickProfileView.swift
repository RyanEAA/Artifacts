//
//  QuickProfileView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct QuickProfileView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var friendsService: FriendsService

    // Mock data for now
    @State private var friends: [String] = ["sarah_creates", "devon_art", "luna_doodles"]
    @State private var artifactsCount: Int = 10

    @State private var showFriends = false
    @State private var showFullMap = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.229, longitude: -97.756),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    private var username: String {
        (session.userData?["username"] as? String) ?? "anonymous_user"
    }

    var body: some View {
        ZStack {
            // subtle background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 112, height: 112)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)

                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .foregroundStyle(.tint)
                }
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.25), lineWidth: 2)
                        .frame(width: 112, height: 112)
                )
                .padding(.top, 15)

                // Username
                Text("@\(username)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Stats row
                HStack(spacing: 28) {
                    // friends button
                    Spacer()
                    Button {
                        showFriends = true
                    } label: {
                        statText(label: "Friends", value: "\(friends.count)")
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    Spacer()
                    statText(label: "Artifacts", value: "\(artifactsCount)")
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 2)

                // Map card
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 8)
                        .overlay(
                            Map(coordinateRegion: $region)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        )
                        .frame(height: 320)
                        .padding(.horizontal, 18)

                    Button {
                        showFullMap = true
                    } label: {
                        Text("View All")
                            .font(.subheadline.bold())
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.9))
                            )
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                    }
                    .padding(.trailing, 34)
                    .padding(.bottom, 18)
                }

                Spacer(minLength: 8)

                // Logout
                Button {
                    session.signOut()
                } label: {
                    Text("Logout")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.86, green: 0.27, blue: 0.23)) // soft red
                        .padding(.vertical, 12)
                        .padding(.horizontal, 36)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.86, green: 0.27, blue: 0.23).opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(Color(red: 0.86, green: 0.27, blue: 0.23).opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
        }
        // Friends sheet (uses mock list for now)
        .sheet(isPresented: $showFriends) {
            FriendsListSheet(friends: $friends)
                .presentationDetents([.medium, .large])
        }
        // Full screen map
        .fullScreenCover(isPresented: $showFullMap) {
            FullMapView(region: region) { newRegion in
                region = newRegion
            }
        }
    }

    // MARK: - UI helpers
    @ViewBuilder
    private func statText(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text("\(label): \(value)")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}



#Preview {
    QuickProfileView()
}

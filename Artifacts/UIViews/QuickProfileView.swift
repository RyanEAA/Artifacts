//
//  QuickProfileView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct QuickProfileView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var friendsService: FriendsService

    private let artifactsService = ArtifactsService()

    @State private var friendCount: Int = 0
    @State private var friends: [String] = []
    @State private var friendsListener: ListenerRegistration?

    @State private var artifacts: [ArtifactMapItem] = []
    @State private var artifactsListener: ListenerRegistration?

    @State private var showFriends = false
    @State private var showFullMap = false

    @State private var selectedArtifact: ArtifactMapItem?
    @State private var didAutoCenter = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    private var username: String {
        (session.userData?["username"] as? String) ?? "anonymous_user"
    }

    private var hasArtifacts: Bool { !artifacts.isEmpty }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ProfileBackground()
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    header

                    statsRow

                    mapCard
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .safeAreaInset(edge: .bottom) {
                logoutBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .background(Color.clear)
            }
        }
        .sheet(isPresented: $showFriends) {
            FriendsListSheet(friends: $friends)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showFullMap) {
            FullMapView(region: region, artifacts: artifacts) { newRegion in
                region = newRegion
            }
        }
        .sheet(item: $selectedArtifact) { item in
            ArtifactDetailSheet(item: item)
                .presentationDetents([.medium])
                .presentationBackground(.black)
        }
        .onAppear {
            startFriendsListener()
            startArtifactsListener()
        }
        .onDisappear {
            friendsListener?.remove()
            artifactsListener?.remove()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .stroke(Color("MintGreen").opacity(0.28), lineWidth: 1)
                    )

                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(username)")
                    .font(.custom("Poppins-Bold", size: 20))
                    .foregroundColor(Color.white.opacity(0.92))

                // Optional: show email if you want a second line that is actually useful.
                if let email = session.user?.email, !email.isEmpty {
                    Text(email)
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                showFullMap = true
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.92))
                    .frame(width: 38, height: 38)
                    .background(Color("MintGreen"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open full map")
        }
        .padding(14)
        .background(ProfileCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color("MintGreen").opacity(0.14), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.50), radius: 18, x: 0, y: 12)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            Button {
                showFriends = true
            } label: {
                StatChip(title: "Friends", value: "\(friendCount)", icon: "person.2.fill")
            }
            .buttonStyle(.plain)

            StatChip(title: "Artifacts", value: "\(artifacts.count)", icon: "mappin.and.ellipse")
        }
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundColor(Color.white.opacity(0.90))

                Spacer()

                Button {
                    showFullMap = true
                } label: {
                    Text("View all")
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .foregroundColor(Color.black.opacity(0.92))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color("MintGreen"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .bottomLeading) {
                Map(coordinateRegion: $region, annotationItems: artifacts) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        ArtifactPin(isSelected: selectedArtifact?.id == item.id)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedArtifact = item
                                withAnimation(.easeInOut(duration: 0.30)) {
                                    region.center = item.coordinate
                                }
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

                if !hasArtifacts {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color("MintGreen").opacity(0.92))
                        Text("Place an artifact to see pins here")
                            .font(.custom("Poppins-Regular", size: 13))
                            .foregroundColor(Color.white.opacity(0.80))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.black.opacity(0.60))
                    .overlay(
                        Capsule()
                            .stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .padding(12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
        }
        .padding(14)
        .background(ProfileCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.50), radius: 18, x: 0, y: 12)
    }

    private var logoutBar: some View {
        Button {
            session.signOut()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Log out")
                    .font(.custom("Poppins-SemiBold", size: 16))
            }
            .foregroundColor(Color.white.opacity(0.90))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.30), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func startFriendsListener() {
        do {
            friendsListener = try friendsService.listenFriendUIDs { uids in
                Task {
                    await MainActor.run { self.friendCount = uids.count }

                    let users = try? await friendsService.fetchUsernames(for: uids)
                    let names = (users ?? [])
                        .map { $0.username }
                        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

                    await MainActor.run { self.friends = names }
                }
            }
        } catch {
            print("⚠️ listenFriendUIDs failed:", error)
        }
    }

    private func startArtifactsListener() {
        do {
            artifactsListener = try artifactsService.listenMyArtifacts { items in
                Task { @MainActor in
                    self.artifacts = items

                    if !didAutoCenter, let first = items.first {
                        didAutoCenter = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            region.center = first.coordinate
                        }
                    }
                }
            }
        } catch {
            print("⚠️ listenMyArtifacts failed:", error)
        }
    }
}

private struct ProfileBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.00),
                    .init(color: Color("DarkGray").opacity(0.98), location: 0.55),
                    .init(color: Color.black.opacity(0.96), location: 1.00)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                gradient: Gradient(colors: [
                    Color("MintGreen").opacity(0.08),
                    Color.clear
                ]),
                startPoint: .topTrailing,
                endPoint: .center
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.55)
                ]),
                center: .center,
                startRadius: 140,
                endRadius: 620
            )
        }
    }
}

private struct ProfileCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color("MintGreen").opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.custom("Poppins-Bold", size: 16))
                    .foregroundColor(Color.white.opacity(0.92))
                Text(title)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.66))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(ProfileCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
    }
}

private struct ArtifactPin: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.78))
                .frame(width: isSelected ? 36 : 30, height: isSelected ? 36 : 30)
                .overlay(
                    Circle()
                        .stroke(Color("MintGreen").opacity(isSelected ? 0.85 : 0.55), lineWidth: isSelected ? 2 : 1)
                )

            Image(systemName: "sparkles")
                .font(.system(size: isSelected ? 14 : 12, weight: .bold))
                .foregroundColor(Color("MintGreen").opacity(0.92))
        }
        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 6)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

private struct ArtifactDetailSheet: View {
    let item: ArtifactMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color("MintGreen").opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("MintGreen").opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Poppins-Bold", size: 18))
                        .foregroundColor(Color.white.opacity(0.92))
                    Text("Scene \(item.sceneId.isEmpty ? "unknown" : item.sceneId)")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundColor(Color.white.opacity(0.60))
                        .lineLimit(1)
                }

                Spacer()
            }

            VStack(spacing: 8) {
                row("Latitude", String(format: "%.5f", item.coordinate.latitude))
                row("Longitude", String(format: "%.5f", item.coordinate.longitude))
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .cornerRadius(14)

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.black.ignoresSafeArea())
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundColor(Color.white.opacity(0.70))
            Spacer()
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 13))
                .foregroundColor(Color.white.opacity(0.90))
        }
    }
}

#Preview {
    QuickProfileView()
        .environmentObject(SessionManager())
        .environmentObject(FriendsService())
}

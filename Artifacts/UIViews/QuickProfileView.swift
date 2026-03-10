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
import FirebaseStorage

struct QuickProfileView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var friendsService: FriendsService

    private let artifactsService = ArtifactsService.shared

    @State private var friendCount: Int = 0
    @State private var friends: [String] = []
    @State private var friendUIDs: [String] = []
    @State private var friendsListener: ListenerRegistration?

    @State private var artifacts: [ArtifactMapItem] = []
    @State private var artifactsListener: ListenerRegistration?

    @State private var showFriends = false
    @State private var showFullMap = false

    @State private var selectedArtifact: ArtifactMapItem?
    @State private var selectedClusterID: String?
    @State private var didAutoCenter = false

    @State private var showArtifactManager = false


    @State private var lastObservedUID: String? = nil
    @State private var ownerAvatarURLs: [String: String] = [:]
    @State private var activeArtifactOwnerUIDs: Set<String> = []

    // Profile photo
    @State private var profileImageURL: String? = nil
    @State private var selectedProfileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isUploadingProfileImage = false
    @State private var uploadErrorMessage: String? = nil
    @State private var showUploadErrorAlert = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    private var username: String {
        (session.userData?["username"] as? String) ?? "anonymous_user"
    }

    private var hasArtifacts: Bool { !artifacts.isEmpty }
    private var clusters: [ArtifactCluster] {
        ArtifactMapClusterer.makeClusters(items: artifacts)
    }
    private var currentUID: String? {
        Auth.auth().currentUser?.uid
    }
    private var myArtifactCount: Int {
        guard let uid = currentUID else { return 0 }
        return artifacts.filter { $0.ownerUid == uid }.count
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                ProfileBackground()
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    header
                    statsRow
                    mapCard
                        .frame(maxWidth: .infinity)
//                        .frame(maxHeight: .infinity)
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
        }
        .fullScreenCover(isPresented: $showFullMap) {
            FullMapView(region: region, artifacts: artifacts, ownerAvatarURLs: ownerAvatarURLs) { newRegion in
                region = newRegion
            }
        }
        .sheet(item: $selectedArtifact) { item in
            ArtifactDetailSheet(item: item)
                .presentationDetents([.medium])
                .presentationBackground(.black)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedProfileImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showArtifactManager){
            MyArtifactsView(artifacts: artifacts)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedProfileImage) { newImage in
            guard let newImage else { return }
            uploadProfileImage(newImage)
        }
        .alert("Profile Photo Upload Failed", isPresented: $showUploadErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadErrorMessage ?? "An unknown error occurred.")
        }
        .onAppear {
            profileImageURL = (session.userData?["profilePictureURL"] as? String)
            handleAuthContextChange(to: session.user?.uid)
        }
        .onDisappear {
            friendsListener?.remove()
            artifactsListener?.remove()
        }
        .onChange(of: session.user?.uid) { newUID in
            handleAuthContextChange(to: newUID)
        }
        .onChange(of: session.userData?["profilePictureURL"] as? String) { newValue in
            profileImageURL = newValue
            if let myUid = currentUID {
                if let newValue, !newValue.isEmpty {
                    ownerAvatarURLs[myUid] = newValue
                } else {
                    ownerAvatarURLs.removeValue(forKey: myUid)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {

            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(Color("MintGreen").opacity(0.28), lineWidth: 1)
                        )

                    if let selectedProfileImage {
                        Image(uiImage: selectedProfileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                    } else if let urlString = profileImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(Color("MintGreen"))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color("MintGreen").opacity(0.92))
                            }
                        }
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color("MintGreen").opacity(0.92))
                    }

                    if isUploadingProfileImage {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 54, height: 54)
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile photo")

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(username)")
                    .font(.custom("Poppins-Bold", size: 20))
                    .foregroundColor(Color.white.opacity(0.92))

                if let email = session.user?.email, !email.isEmpty {
                    Text(email)
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
            }

            Spacer()


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

            Button {
                showArtifactManager = true
            } label: {
                StatChip(title: "Artifacts", value: "\(artifacts.count)", icon: "mappin.and.ellipse")
            }
            .buttonStyle(.plain)        }
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
                Map(coordinateRegion: $region, annotationItems: clusters) { cluster in
                    MapAnnotation(coordinate: cluster.coordinate) {
                        ArtifactMarkerView(
                            owners: markerOwners(for: cluster),
                            isSelected: selectedClusterID == cluster.id
                        )
                        .onTapGesture {
                            DispatchQueue.main.async {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedClusterID = cluster.id
                                handleClusterTap(cluster)
                            }
                        }
                        .onLongPressGesture {
                            DispatchQueue.main.async {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedClusterID = cluster.id
                                if let item = cluster.items.first {
                                    selectedArtifact = item
                                }
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No published artifacts yet")
                            .font(.custom("Poppins-Bold", size: 14))
                            .foregroundColor(Color.white.opacity(0.90))

                        Text("Place artifacts and press Save to publish them to your map.")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundColor(Color.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.52))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .cornerRadius(14)
                    .padding(12)
                }
            }
            .frame(maxHeight: .infinity)
//            .frame(height: 260)
        }
        .padding(14)
        .background(ProfileCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color("MintGreen").opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 12)
    }

    private var logoutBar: some View {
        Button {
            session.signOut()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .bold))
                Text("Log out")
                    .font(.custom("Poppins-SemiBold", size: 14))
            }
            .foregroundColor(Color.white.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private func handleClusterTap(_ cluster: ArtifactCluster) {
        withAnimation(.easeInOut(duration: 0.30)) {
            region.center = cluster.coordinate
        }

        if let item = cluster.items.first {
            openAppleMapsForArtifact(item)
        }
    }

    private func startFriendsListener() {
        friendsListener?.remove()
        do {
            friendsListener = try friendsService.listenFriendUIDs { uids in
                Task {
                    await MainActor.run {
                        self.friendCount = uids.count
                        self.friendUIDs = uids
                        self.refreshArtifactsListener()
                    }

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

    private func handleAuthContextChange(to newUID: String?) {
        guard lastObservedUID != newUID else { return }
        lastObservedUID = newUID

        friendsListener?.remove()
        artifactsListener?.remove()

        didAutoCenter = false
        selectedClusterID = nil
        selectedArtifact = nil

        friendCount = 0
        friends = []
        friendUIDs = []
        artifacts = []
        ownerAvatarURLs = [:]
        activeArtifactOwnerUIDs = []

        guard newUID != nil else { return }

        startFriendsListener()
        refreshArtifactsListener()
    }

    private func refreshArtifactsListener() {
        artifactsListener?.remove()
        artifactsListener = artifactsService.listenMyAndFriendsPublishedArtifacts(friendUIDs: friendUIDs) { items in
            Task { @MainActor in
                self.artifacts = items
                let ownerUIDSet = Set(items.map(\.ownerUid))
                if ownerUIDSet != self.activeArtifactOwnerUIDs {
                    self.activeArtifactOwnerUIDs = ownerUIDSet
                    Task { await updateOwnerAvatarURLs(for: Array(ownerUIDSet)) }
                }

                if !didAutoCenter, let first = items.first {
                    didAutoCenter = true
                    withAnimation(.easeInOut(duration: 0.35)) {
                        region.center = first.coordinate
                    }
                }
            }
        }
    }

    private func updateOwnerAvatarURLs(for ownerUIDs: [String]) async {
        guard !ownerUIDs.isEmpty else {
            await MainActor.run { ownerAvatarURLs = [:] }
            return
        }

        do {
            let users = try await friendsService.fetchUsernames(for: ownerUIDs)
            var merged: [String: String] = [:]
            for user in users {
                if let url = user.profilePictureURL, !url.isEmpty {
                    merged[user.id] = url
                }
            }

            if let myUid = Auth.auth().currentUser?.uid,
               let profileImageURL,
               !profileImageURL.isEmpty {
                merged[myUid] = profileImageURL
            }

            await MainActor.run {
                ownerAvatarURLs = merged
            }
        } catch {
            print("⚠️ updateOwnerAvatarURLs failed:", error.localizedDescription)
        }
    }

    private func avatarURL(for ownerUid: String) -> String? {
        if ownerUid == currentUID {
            return profileImageURL ?? ownerAvatarURLs[ownerUid]
        }
        return ownerAvatarURLs[ownerUid]
    }

    private func markerOwners(for cluster: ArtifactCluster) -> [ArtifactMarkerOwner] {
        cluster.ownerArtifactCounts.map { bucket in
            ArtifactMarkerOwner(
                ownerUid: bucket.ownerUid,
                imageURL: avatarURL(for: bucket.ownerUid),
                count: bucket.count
            )
        }
    }

    private func openAppleMapsForArtifact(_ item: ArtifactMapItem) {
        let placemark = MKPlacemark(coordinate: item.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.title

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsShowsTrafficKey: true
        ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            MKMapItem.openMaps(with: [mapItem], launchOptions: launchOptions)
        }
    }

    private func uploadProfileImage(_ image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else {
            uploadErrorMessage = "You must be signed in to upload a profile photo."
            showUploadErrorAlert = true
            return
        }

        guard !isUploadingProfileImage else { return }
        isUploadingProfileImage = true
        uploadErrorMessage = nil

        guard let data = image.jpegData(compressionQuality: 0.82) else {
            isUploadingProfileImage = false
            uploadErrorMessage = "Unable to process the selected image."
            showUploadErrorAlert = true
            return
        }

        let ref = Storage.storage().reference(withPath: "users/\(uid)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(data, metadata: metadata) { _, error in
            if let error {
                DispatchQueue.main.async {
                    self.isUploadingProfileImage = false
                    self.uploadErrorMessage = error.localizedDescription
                    self.showUploadErrorAlert = true
                }
                return
            }

            ref.downloadURL { url, error in
                if let error {
                    DispatchQueue.main.async {
                        self.isUploadingProfileImage = false
                        self.uploadErrorMessage = error.localizedDescription
                        self.showUploadErrorAlert = true
                    }
                    return
                }

                guard let url else {
                    DispatchQueue.main.async {
                        self.isUploadingProfileImage = false
                        self.uploadErrorMessage = "Could not get download URL."
                        self.showUploadErrorAlert = true
                    }
                    return
                }

                let urlString = url.absoluteString

                Firestore.firestore().collection("users").document(uid).setData([
                    "profilePictureURL": urlString,
                    "lastActive": Timestamp(date: Date())
                ], merge: true) { error in
                    DispatchQueue.main.async {
                        self.isUploadingProfileImage = false

                        if let error {
                            self.uploadErrorMessage = error.localizedDescription
                            self.showUploadErrorAlert = true
                            return
                        }

                        self.profileImageURL = urlString
                        self.selectedProfileImage = nil
                        self.ownerAvatarURLs[uid] = urlString

                        var updated = self.session.userData ?? [:]
                        updated["profilePictureURL"] = urlString
                        self.session.userData = updated
                    }
                }
            }
        }
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



#Preview {
    QuickProfileView()
        .environmentObject(SessionManager())
        .environmentObject(FriendsService())
}

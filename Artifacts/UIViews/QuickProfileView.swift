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
    @StateObject private var locationService = LocationService.shared

    private let artifactsService = ArtifactsService.shared

    @State private var friendCount: Int = 0
    @State private var friends: [String] = []
    @State private var friendUIDs: [String] = []
    @State private var friendsListener: ListenerRegistration?

    @State private var artifacts: [ArtifactMapItem] = []
    @State private var artifactsListener: ListenerRegistration?
    @State private var hasResolvedArtifactsOnce = false

    @State private var showFriends = false
    @State private var showFullMap = false
    @State private var showSettings = false

    @State private var selectedArtifact: ArtifactMapItem?
    @State private var selectedClusterID: String?
    @State private var didAutoCenter = false
    @State private var artifactListenerOwnerUIDs: Set<String> = []
    @State private var clusteredArtifacts: [ArtifactCluster] = []

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
    private var myArtifacts: [ArtifactMapItem] {
        guard let uid = currentUID else { return [] }
        return artifacts.filter { $0.ownerUid == uid }
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
        .sheet(isPresented: $showSettings) {
            ProfileSettingsSheet()
                .environmentObject(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
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
            MyArtifactsView(artifacts: myArtifacts)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
            locationService.start()
            if !didAutoCenter, !hasArtifacts, let coordinate = locationService.currentOrCachedCoordinate() {
                region.center = coordinate
            }
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
        .onChange(of: locationService.currentCoordinate?.latitude) { _, _ in
            guard
                !didAutoCenter,
                !hasArtifacts,
                let coordinate = locationService.currentCoordinate
            else { return }
            region.center = coordinate
        }
        .onChange(of: locationService.currentCoordinate?.longitude) { _, _ in
            guard
                !didAutoCenter,
                !hasArtifacts,
                let coordinate = locationService.currentCoordinate
            else { return }
            region.center = coordinate
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
                        CachedRemoteImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                                .tint(Color("MintGreen"))
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

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Color("MintGreen").opacity(0.24), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")

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
                StatChip(title: "Artifacts", value: "\(myArtifactCount)", icon: "mappin.and.ellipse")
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
                EmbeddedArtifactMap(
                    region: $region,
                    clusters: clusteredArtifacts,
                    selectedClusterID: $selectedClusterID,
                    markerOwners: markerOwners(for:),
                    onClusterTap: handleClusterTap(_:),
                    onClusterLongPress: handleClusterLongPress(_:)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

                if hasResolvedArtifactsOnce && !hasArtifacts {
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

    private func handleClusterLongPress(_ cluster: ArtifactCluster) {
        selectedClusterID = cluster.id
        selectedArtifact = cluster.items.first
    }

    private func startFriendsListener() {
        friendsListener?.remove()
        do {
            friendsListener = try friendsService.listenFriendUIDs { uids in
                Task {
                    let normalizedUIDs = Set(uids)
                    let cachedUsers = await MainActor.run { friendsService.cachedUsers(for: Array(normalizedUIDs)) }
                    let cachedNames = cachedUsers
                        .map(\.username)
                        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    let cachedAvatarMap: [String: String] = Dictionary(
                        uniqueKeysWithValues: cachedUsers.compactMap { user in
                            guard let url = user.profilePictureURL, !url.isEmpty else { return nil }
                            return (user.id, url)
                        }
                    )

                    await MainActor.run {
                        self.friendCount = normalizedUIDs.count
                        if !cachedNames.isEmpty {
                            self.friends = cachedNames
                        }
                        if !cachedAvatarMap.isEmpty {
                            self.ownerAvatarURLs.merge(cachedAvatarMap) { _, new in new }
                        }
                        if normalizedUIDs != Set(self.friendUIDs) {
                            self.friendUIDs = normalizedUIDs.sorted()
                            self.refreshArtifactsListener()
                        }
                    }

                    let users = try? await friendsService.fetchUsernames(for: uids)
                    let names = (users ?? [])
                        .map { $0.username }
                        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    let avatarMap: [String: String] = Dictionary(
                        uniqueKeysWithValues: (users ?? []).compactMap { user in
                            guard let url = user.profilePictureURL, !url.isEmpty else { return nil }
                            return (user.id, url)
                        }
                    )

                    await MainActor.run {
                        self.friends = names
                        self.ownerAvatarURLs.merge(avatarMap) { _, new in new }
                    }
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
        clusteredArtifacts = []
        hasResolvedArtifactsOnce = false
        artifactListenerOwnerUIDs = []
        ownerAvatarURLs = [:]
        activeArtifactOwnerUIDs = []

        guard newUID != nil else { return }

        startFriendsListener()
        refreshArtifactsListener()
    }

    private func refreshArtifactsListener() {
        let nextOwnerUIDs = Set(friendUIDs)
        guard nextOwnerUIDs != artifactListenerOwnerUIDs || artifactsListener == nil else { return }
        artifactListenerOwnerUIDs = nextOwnerUIDs
        artifactsListener?.remove()
        artifactsListener = artifactsService.listenMyAndFriendsPublishedArtifacts(friendUIDs: friendUIDs) { items in
            Task { @MainActor in
                self.hasResolvedArtifactsOnce = true
                guard self.artifacts != items else { return }
                self.artifacts = items
                self.clusteredArtifacts = ArtifactMapClusterer.makeClusters(items: items)
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
            await MainActor.run {
                if let myUid = Auth.auth().currentUser?.uid,
                   let profileImageURL,
                   !profileImageURL.isEmpty {
                    ownerAvatarURLs = [myUid: profileImageURL]
                } else {
                    ownerAvatarURLs = [:]
                }
            }
            return
        }

        let cachedUsers = await MainActor.run { friendsService.cachedUsers(for: ownerUIDs) }
        let cachedAvatarMap: [String: String] = Dictionary(
            uniqueKeysWithValues: cachedUsers.compactMap { user in
                guard let url = user.profilePictureURL, !url.isEmpty else { return nil }
                return (user.id, url)
            }
        )

        if !cachedAvatarMap.isEmpty {
            await MainActor.run {
                ownerAvatarURLs.merge(cachedAvatarMap) { _, new in new }
            }
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
                ownerAvatarURLs.merge(merged) { _, new in new }
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
        let recentCutoff = Date().addingTimeInterval(-86_400)
        return cluster.ownerArtifactCounts.map { bucket in
            ArtifactMarkerOwner(
                ownerUid: bucket.ownerUid,
                imageURL: avatarURL(for: bucket.ownerUid),
                count: bucket.count,
                isRecent: cluster.items.contains { item in
                    item.ownerUid == bucket.ownerUid && item.createdAt >= recentCutoff
                }
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

private struct ProfileSettingsSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var feedback: SettingsFeedback?
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isUsernameFocused: Bool

    private var canSave: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let current = (session.userData?["username"] as? String ?? "").lowercased()
        return !trimmed.isEmpty && trimmed != current && !isSaving && !isDeleting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsSheetBackground()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        topBar

                        sectionCard(title: "Profile") {
                            VStack(spacing: 12) {
                                if let feedback {
                                    SettingsBanner(feedback: feedback) {
                                        withAnimation(.easeInOut(duration: 0.20)) {
                                            self.feedback = nil
                                        }
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }

                                SettingsInputRow(
                                    systemImage: "person",
                                    title: "Username",
                                    text: $username,
                                    submitLabel: .done
                                )
                                .focused($isUsernameFocused)
                                .onSubmit {
                                    submitUsernameChange()
                                }
                                .onChange(of: username) { _, newValue in
                                    username = newValue.lowercased()
                                }

                                Button(action: submitUsernameChange) {
                                    ZStack {
                                        Text("Save Username")
                                            .opacity(isSaving ? 0 : 1)

                                        if isSaving {
                                            ProgressView()
                                                .tint(Color("DarkGray"))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SettingsPrimaryButtonStyle())
                                .disabled(!canSave)
                                .opacity(canSave ? 1 : 0.55)
                            }
                        }
                        .padding(.horizontal, 16)

                        sectionCard(title: "Account") {
                            VStack(alignment: .leading, spacing: 12) {
                                if showDeleteConfirmation {
                                    SettingsConfirmationCard(
                                        title: "Are you sure?",
                                        message: "Delete your account",
                                        confirmTitle: isDeleting ? "Yes..." : "Yes",
                                        cancelTitle: "No",
                                        isConfirmDisabled: isDeleting,
                                        onConfirm: deleteAccount,
                                        onCancel: {
                                            withAnimation(.easeInOut(duration: 0.20)) {
                                                showDeleteConfirmation = false
                                            }
                                        }
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }

                                Button {
                                    UIApplication.shared.endEditing()
                                    withAnimation(.easeInOut(duration: 0.20)) {
                                        feedback = nil
                                        showDeleteConfirmation = true
                                    }
                                } label: {
                                    Text("Delete Account")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SettingsDangerButtonStyle())
                                .disabled(isDeleting)
                                .opacity(showDeleteConfirmation ? 0.45 : 1)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 12)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
            }
            .navigationBarHidden(true)
            .presentationBackground(.black)
        }
        .animation(.easeInOut(duration: 0.22), value: feedback?.id)
        .animation(.easeInOut(duration: 0.22), value: showDeleteConfirmation)
        .onAppear {
            username = (session.userData?["username"] as? String) ?? ""
        }
        .onChange(of: session.userData?["username"] as? String) { _, newValue in
            guard !isUsernameFocused else { return }
            username = newValue ?? ""
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Settings")
                .font(.custom("Poppins-Bold", size: 22))
                .foregroundColor(Color.white.opacity(0.92))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.88))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle().stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("Poppins-SemiBold", size: 15))
                .foregroundColor(Color.white.opacity(0.90))

            content()
        }
        .padding(14)
        .background(SettingsCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.50), radius: 18, x: 0, y: 12)
    }

    private func submitUsernameChange() {
        guard canSave else { return }
        UIApplication.shared.endEditing()
        feedback = nil
        showDeleteConfirmation = false

        Task {
            await MainActor.run {
                isSaving = true
            }

            do {
                try await session.updateUsername(to: username)
                await MainActor.run {
                    isSaving = false
                    username = (session.userData?["username"] as? String) ?? username.lowercased()
                    feedback = SettingsFeedback(
                        kind: .success,
                        text: "Username updated successfully."
                    )
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    feedback = SettingsFeedback(
                        kind: .error,
                        text: error.localizedDescription
                    )
                }
            }
        }
    }

    private func deleteAccount() {
        feedback = nil

        Task {
            await MainActor.run {
                isDeleting = true
            }

            do {
                try await session.deleteCurrentAccount()
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    showDeleteConfirmation = false
                    feedback = SettingsFeedback(
                        kind: .error,
                        text: error.localizedDescription
                    )
                }
            }
        }
    }
}

private struct SettingsFeedback: Identifiable, Equatable {
    enum Kind {
        case success
        case error
    }

    let kind: Kind
    let text: String

    var id: String { "\(kind)-\(text)" }
}

private struct SettingsSheetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black, location: 0.00),
                    .init(color: Color("DarkGray").opacity(0.98), location: 0.60),
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
                    Color.black.opacity(0.60)
                ]),
                center: .center,
                startRadius: 140,
                endRadius: 640
            )
        }
    }
}

private struct SettingsCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

private struct SettingsBanner: View {
    let feedback: SettingsFeedback
    let onDismiss: () -> Void

    private var accentColor: Color {
        switch feedback.kind {
        case .success:
            return Color("MintGreen").opacity(0.95)
        case .error:
            return Color.red.opacity(0.95)
        }
    }

    private var iconName: String {
        switch feedback.kind {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(accentColor)

            Text(feedback.text)
                .font(.custom("Poppins-Regular", size: 14))
                .foregroundColor(Color.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel("Dismiss message")
        }
        .padding(12)
        .background(Color.black.opacity(0.62))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.28), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

private struct SettingsInputRow: View {
    let systemImage: String
    let title: String
    @Binding var text: String
    let submitLabel: SubmitLabel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(Color("MintGreen").opacity(0.92))
                .frame(width: 22)

            ZStack(alignment: .leading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(title)
                        .font(.custom("Poppins-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.40))
                        .padding(.leading, 2)
                }

                TextField("", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.username)
                    .submitLabel(submitLabel)
                    .foregroundColor(Color.white.opacity(0.92))
                    .tint(Color("MintGreen"))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

private struct SettingsConfirmationCard: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let isConfirmDisabled: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.red.opacity(0.92))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundColor(Color.white.opacity(0.92))

                Text(message)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .foregroundColor(Color.white.opacity(0.92))
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .clipShape(Capsule())

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.custom("Poppins-SemiBold", size: 13))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .foregroundColor(Color.white.opacity(0.94))
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.16))
                .overlay(
                    Capsule()
                        .stroke(Color.red.opacity(0.26), lineWidth: 1)
                )
                .clipShape(Capsule())
                .disabled(isConfirmDisabled)
                .opacity(isConfirmDisabled ? 0.55 : 1)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.62))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 16))
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color("MintGreen"))
            .foregroundColor(Color.black.opacity(0.92))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.25 : 0.55), radius: 18, x: 0, y: 14)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 16))
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.06))
            .foregroundColor(Color.white.opacity(0.90))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color("MintGreen").opacity(0.22), lineWidth: 1)
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.20 : 0.45), radius: 16, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SettingsDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Poppins-SemiBold", size: 16))
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.06))
            .foregroundColor(Color.red.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.24), lineWidth: 1)
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.36), radius: 14, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct EmbeddedArtifactMap: View {
    @Binding var region: MKCoordinateRegion
    let clusters: [ArtifactCluster]
    @Binding var selectedClusterID: String?
    let markerOwners: (ArtifactCluster) -> [ArtifactMarkerOwner]
    let onClusterTap: (ArtifactCluster) -> Void
    let onClusterLongPress: (ArtifactCluster) -> Void

    @State private var mapRegion: MKCoordinateRegion
    @State private var pendingRegionSync: DispatchWorkItem?

    init(
        region: Binding<MKCoordinateRegion>,
        clusters: [ArtifactCluster],
        selectedClusterID: Binding<String?>,
        markerOwners: @escaping (ArtifactCluster) -> [ArtifactMarkerOwner],
        onClusterTap: @escaping (ArtifactCluster) -> Void,
        onClusterLongPress: @escaping (ArtifactCluster) -> Void
    ) {
        _region = region
        self.clusters = clusters
        _selectedClusterID = selectedClusterID
        self.markerOwners = markerOwners
        self.onClusterTap = onClusterTap
        self.onClusterLongPress = onClusterLongPress
        _mapRegion = State(initialValue: region.wrappedValue)
    }

    var body: some View {
        Map(coordinateRegion: $mapRegion, annotationItems: clusters) { cluster in
            MapAnnotation(coordinate: cluster.coordinate) {
                ArtifactMarkerView(
                    owners: markerOwners(cluster),
                    isSelected: selectedClusterID == cluster.id
                )
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedClusterID = cluster.id
                    onClusterTap(cluster)
                }
                .onLongPressGesture {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onClusterLongPress(cluster)
                }
            }
        }
        .onChange(of: region.center.latitude) { _ in
            syncMapRegionFromParent()
        }
        .onChange(of: region.center.longitude) { _ in
            syncMapRegionFromParent()
        }
        .onChange(of: region.span.latitudeDelta) { _ in
            syncMapRegionFromParent()
        }
        .onChange(of: region.span.longitudeDelta) { _ in
            syncMapRegionFromParent()
        }
        .onChange(of: mapRegion.center.latitude) { _ in
            scheduleRegionSync()
        }
        .onChange(of: mapRegion.center.longitude) { _ in
            scheduleRegionSync()
        }
        .onChange(of: mapRegion.span.latitudeDelta) { _ in
            scheduleRegionSync()
        }
        .onChange(of: mapRegion.span.longitudeDelta) { _ in
            scheduleRegionSync()
        }
        .onDisappear {
            pendingRegionSync?.cancel()
            region = mapRegion
        }
    }

    private func syncMapRegionFromParent() {
        guard !regionsMatch(mapRegion, region) else { return }
        mapRegion = region
    }

    private func scheduleRegionSync() {
        let newValue = mapRegion
        guard !regionsMatch(region, newValue) else { return }
        pendingRegionSync?.cancel()
        let workItem = DispatchWorkItem {
            region = newValue
        }
        pendingRegionSync = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func regionsMatch(_ lhs: MKCoordinateRegion, _ rhs: MKCoordinateRegion) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) < 0.000_001 &&
        abs(lhs.center.longitude - rhs.center.longitude) < 0.000_001 &&
        abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < 0.000_001 &&
        abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < 0.000_001
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

//
//  ProfileView.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

enum FriendSubCategory: Int, CaseIterable {
    case posts = 0
    case users
    case requests
    
    var title: String {
        switch self {
        case .posts: return "Posts"
        case .users: return "Users"
        case .requests: return "Requests"
        }
    }
}

final class ProfileViewModel: ObservableObject {
    @Published var myPosts: [Post] = []
    @Published var friendPosts: [Post] = []
    @Published var publicPosts: [Post] = []
    @Published var allUsers: [UserModel] = []
    @Published var friends: [String] = []
    @Published var incomingRequests: [String] = []
    @Published var sentRequests: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private let currentUsername: String

    init(currentUsername: String) {
        self.currentUsername = currentUsername
        Task { await loadMockData() }
    }

    func loadMockData() async {
        try? await Task.sleep(nanoseconds: 120_000_000)

        let mine: [Post] = [
            Post(title: "Garden Flowers", username: currentUsername, date: "Oct 6, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.230, longitude: -97.756),
                 profileImage: ""),
            Post(title: "Downtown Art Piece", username: currentUsername, date: "Oct 8, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.233, longitude: -97.754),
                 profileImage: ""),
            Post(title: "Homemade Pottery", username: currentUsername, date: "Oct 9, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.231, longitude: -97.759),
                 profileImage: ""),
            Post(title: "Street Market Stall", username: currentUsername, date: "Oct 10, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.229, longitude: -97.751),
                 profileImage: ""),
            Post(title: "Sunset Overlook", username: currentUsername, date: "Oct 11, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.227, longitude: -97.755),
                 profileImage: ""),
            Post(title: "Campus Mural", username: currentUsername, date: "Oct 12, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.228, longitude: -97.758),
                 profileImage: "")
        ]

        let friendsPosts: [Post] = [
            Post(title: "Street Jazz Performance", username: "sarah_creates", date: "Oct 7, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.232, longitude: -97.753),
                 profileImage: "", visited: true),
            Post(title: "Coffee Mural", username: "devon_art", date: "Oct 9, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.226, longitude: -97.757),
                 profileImage: "", visited: true),
            Post(title: "Park Bench Sketch", username: "luna_doodles", date: "Oct 10, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.228, longitude: -97.749),
                 profileImage: "", visited: true),
            Post(title: "Neon Alley", username: "taylor_photog", date: "Oct 11, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.234, longitude: -97.752),
                 profileImage: "", visited: false),
            Post(title: "Morning Market", username: "mike_sculpts", date: "Oct 12, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.229, longitude: -97.760),
                 profileImage: "", visited: false),
            Post(title: "Theater Steps", username: "lisa_arts", date: "Oct 13, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.231, longitude: -97.755),
                 profileImage: "", visited: false)
        ]

        let pub: [Post] = [
            Post(title: "Skyline Painting", username: "austin_artist", date: "Oct 10, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.224, longitude: -97.755),
                 profileImage: "", visited: true),
            Post(title: "Bridge Light Show", username: "jeff_pizzas", date: "Oct 11, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.225, longitude: -97.750),
                 profileImage: "", visited: true),
            Post(title: "Capitol View", username: "wanderer_joe", date: "Oct 12, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.276, longitude: -97.742),
                 profileImage: "", visited: true),
            Post(title: "Food Truck Fiesta", username: "yummybytes", date: "Oct 13, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.245, longitude: -97.747),
                 profileImage: "", visited: false),
            Post(title: "Riverside Reflections", username: "photochaser", date: "Oct 14, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.240, longitude: -97.750),
                 profileImage: "", visited: false),
            Post(title: "Zilker Sculpture", username: "outdoor_muse", date: "Oct 15, 2025",
                 coordinate: CLLocationCoordinate2D(latitude: 30.266, longitude: -97.771),
                 profileImage: "", visited: false)
        ]

        let users: [UserModel] = [
            UserModel(id: "u_sarah", username: "sarah_creates", email: "sarah@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_devon", username: "devon_art", email: "devon@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_luna", username: "luna_doodles", email: "luna@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_taylor", username: "taylor_photog", email: "taylor@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_mike", username: "mike_sculpts", email: "mike@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_lisa", username: "lisa_arts", email: "lisa@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_alex", username: "alex_art", email: "alex@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_austin", username: "austin_artist", email: "austin@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_jeff", username: "jeff_pizzas", email: "jeff@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_wander", username: "wanderer_joe", email: "wander@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_lindo", username: "lindo_the_great", email: "lindogreat@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil),
            UserModel(id: "u_you", username: "jake_the_baker", email: "me@example.com", createdAt: Date(), lastActive: Date(), profilePictureURL: nil)
        ]

        let defaultFriends = ["sarah_creates", "devon_art", "luna_doodles"]
        let defaultIncoming = ["alex_art", "lisa_arts"]
        let defaultSent: [String] = ["wanderer_joe"]

        await MainActor.run {
            self.myPosts = mine
            self.friendPosts = friendsPosts
            self.publicPosts = pub

            self.allUsers = users
            self.friends = defaultFriends
            self.incomingRequests = defaultIncoming
            self.sentRequests = defaultSent
        }
    }

    func acceptFriendRequest(username: String) {
        Task { @MainActor in
            incomingRequests.removeAll { $0 == username }
            if !friends.contains(username) {
                friends.append(username)
            }
            if !friendPosts.contains(where: { $0.username == username }) {
                friendPosts.append(Post(title: "New from \(username)", username: username, date: "Oct 15, 2025", coordinate: CLLocationCoordinate2D(latitude: 30.229, longitude: -97.755), profileImage: "", visited: false))
            }
        }
    }

    func rejectFriendRequest(username: String) {
        Task { @MainActor in
            incomingRequests.removeAll { $0 == username }
        }
    }
    
    func unfriend(username: String) {
        Task { @MainActor in
            friends.removeAll { $0 == username }
            friendPosts.removeAll { $0.username == username }
        }
    }

    func toggleSendRequest(username: String) {
        Task { @MainActor in
            if sentRequests.contains(username) {
                sentRequests.removeAll { $0 == username }
            } else {
                sentRequests.append(username)
            }
        }
    }

    func isFriend(_ username: String) -> Bool { friends.contains(username) }
    func didReceiveRequest(from username: String) -> Bool { incomingRequests.contains(username) }
    func didSendRequest(to username: String) -> Bool { sentRequests.contains(username) }

    func fetchLatestFromBackend() async {
    }
}

struct ProfileView: View {
    @Binding var showProfile: Bool
    @StateObject private var vm: ProfileViewModel
    @EnvironmentObject var session: SessionManager


    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.229, longitude: -97.756),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var selectedPostIndex = 0
    @State private var categoryIndex = 0
    @State private var showViewAll = false
    @State private var selectedPost: Post? = nil

    private var currentPosts: [Post] {
        switch categoryIndex {
        case 1:
            return vm.friendPosts.filter { vm.isFriend($0.username) }
        case 2: return vm.publicPosts
        default: return vm.myPosts
        }
    }

    private var categoryName: String {
        switch categoryIndex {
        case 1: return "Friends"
        case 2: return "Public"
        default: return "Mine"
        }
    }

    private func iconForCategory(_ index: Int) -> String {
        switch index {
        case 0: return "person.fill"
        case 1: return "person.2.fill"
        default: return "globe"
        }
    }
    
    init(showProfile: Binding<Bool>) {
        _showProfile = showProfile
        _vm = StateObject(wrappedValue: ProfileViewModel(
            currentUsername: "anonymous_user"
        ))
    }

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: currentPosts) { post in
                MapAnnotation(coordinate: post.coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                }
            }
            .ignoresSafeArea()
            .onChange(of: selectedPostIndex) { newIndex in
                guard !currentPosts.isEmpty else { return }
                let bounded = min(max(newIndex, 0), currentPosts.count - 1)
                withAnimation(.easeInOut(duration: 1.0)) {
                    region.center = currentPosts[bounded].coordinate
                }
            }

            VStack {
                ZStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 34, height: 34)
                                .foregroundColor(.white)

                            Text("@\(session.userData?["username"] as? String ?? "jake_the_baker")")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: { session.signOut() }) {
                            Text("Log Out")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(width: 50)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Button(action: { withAnimation { showProfile = false } }) {
                            Text("Back")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(width: 50)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 16)

                Spacer()

                ZStack {
                    let post = currentPosts.isEmpty ? placeholderPost() : currentPosts[min(selectedPostIndex, max(0, currentPosts.count - 1))]

                    HStack(spacing: 12) {
                        Button(action: { switchCategory(left: true) }) {
                            Image(systemName: iconForCategory((categoryIndex + 2) % 3))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                        }

                        VStack(spacing: 8) {
                            ZStack {
                                HStack {
                                    Text(categoryName)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Capsule())

                                    Spacer()

                                    Button(action: { withAnimation { showViewAll = true } }) {
                                        Text("View All")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Capsule())
                                    }
                                }

                                Button(action: { showNextPost() }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Capsule())
                                }
                            }

                            VStack(spacing: 4) {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 34, height: 34)
                                        .foregroundColor(.white)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(post.title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        HStack {
                                            Text(post.username)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white.opacity(0.8))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Spacer()
                                            Text(post.date)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white.opacity(0.8))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button(action: { showPreviousPost() }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onEnded { gesture in
                                    let horizontalDistance = abs(gesture.translation.width)
                                    let verticalDistance = gesture.translation.height

                                    if verticalDistance < -50 && abs(verticalDistance) > horizontalDistance {
                                        showNextPost()
                                    } else if verticalDistance > 50 && verticalDistance > horizontalDistance {
                                        showPreviousPost()
                                    }
                                }
                        )

                        Button(action: { switchCategory(left: false) }) {
                            Image(systemName: iconForCategory((categoryIndex + 1) % 3))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 180)
                    .simultaneousGesture(
                        DragGesture()
                            .onEnded { value in
                                let horizontal = value.translation.width
                                let vertical = abs(value.translation.height)

                                if abs(horizontal) > vertical {
                                    if horizontal > 50 {
                                        switchCategory(left: true)
                                    } else if horizontal < -50 {
                                        switchCategory(left: false)
                                    }
                                }
                            }
                    )
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showViewAll) {
            ViewAllPostsView(
                categoryIndex: $categoryIndex,
                showViewAll: $showViewAll,
                selectedPost: $selectedPost,
                vm: vm,
                currentUsername: session.userData?["username"] as? String ?? "jake_the_baker"
            )
            .presentationBackground(.black)
        }
        .onChange(of: selectedPost) { post in
            if let post = post {
                withAnimation(.easeInOut(duration: 1.0)) {
                    region.center = post.coordinate
                }
                if let index = currentPosts.firstIndex(where: { $0.id == post.id }) {
                    selectedPostIndex = index
                }
            }
        }
        .task {
            if let first = currentPosts.first { region.center = first.coordinate }
        }
    }

    private func placeholderPost() -> Post {
        Post(title: "No posts", username: "nobody", date: "", coordinate: region.center, profileImage: "", visited: false)
    }

    private func showPreviousPost() {
        guard !currentPosts.isEmpty else { return }
        withAnimation(.easeInOut) {
            selectedPostIndex = (selectedPostIndex - 1 + currentPosts.count) % currentPosts.count
        }
    }

    private func showNextPost() {
        guard !currentPosts.isEmpty else { return }
        withAnimation(.easeInOut) {
            selectedPostIndex = (selectedPostIndex + 1) % currentPosts.count
        }
    }

    private func switchCategory(left: Bool) {
        withAnimation(.easeInOut) {
            if left { categoryIndex = (categoryIndex - 1 + 3) % 3 }
            else { categoryIndex = (categoryIndex + 1) % 3 }
            selectedPostIndex = 0
            region.center = currentPosts.first?.coordinate ?? region.center
        }
    }
}

struct ViewAllPostsView: View {
    @Binding var categoryIndex: Int
    @Binding var showViewAll: Bool
    @Binding var selectedPost: Post?

    @ObservedObject var vm: ProfileViewModel
    let currentUsername: String

    @State private var searchText: String = ""
    @State private var selectedFriendSubCategory: FriendSubCategory = .posts

    private var receivedUsers: [UserModel] {
        vm.incomingRequests.compactMap { uname in
            vm.allUsers.first(where: { $0.username == uname })
        }
    }

    private var discoverUsers: [UserModel] {
        vm.allUsers.filter { user in
            user.username != currentUsername &&
            !vm.isFriend(user.username) &&
            !vm.didReceiveRequest(from: user.username) &&  // already received
            !vm.incomingRequests.contains(user.username)   // avoid duplicates
        }
    }

    private var currentFriendContent: [Post] {
        switch selectedFriendSubCategory {
        case .posts:
            return vm.friendPosts.filter { vm.isFriend($0.username) }
        case .users:
            return vm.friends.map { Post(title: "", username: $0, date: "", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), profileImage: "") }
        case .requests:
            return []
        }
    }

    private var currentPosts: [Post] {
        switch categoryIndex {
        case 1: return currentFriendContent
        case 2: return vm.publicPosts
        default: return vm.myPosts
        }
    }

    private var filteredPosts: [Post] {
        if searchText.isEmpty { return currentPosts }
        return currentPosts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredUsers: [UserModel] {
        switch selectedFriendSubCategory {
        case .users:
            let users = vm.friends.compactMap { uname in
                vm.allUsers.first(where: { $0.username == uname })
            }
            return searchText.isEmpty
                ? users
                : users.filter { $0.username.localizedCaseInsensitiveContains(searchText) }

        case .requests:
            let received = searchText.isEmpty
                ? receivedUsers
                : receivedUsers.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
            let discover = searchText.isEmpty
                ? discoverUsers
                : discoverUsers.filter { $0.username.localizedCaseInsensitiveContains(searchText) }

            // Remove any user from discover who is in received
            let uniqueDiscover = discover.filter { user in
                !received.contains(where: { $0.id == user.id })
            }

            return received + uniqueDiscover

        default:
            return []
        }
    }

    private var notVisitedPosts: [Post] { filteredPosts.filter { !$0.visited } }
    private var visitedPosts: [Post] { filteredPosts.filter { $0.visited } }

    private var showVisitedSections: Bool {
        return categoryIndex != 1 || selectedFriendSubCategory == .posts
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        CategoryTab(text: "Mine", selected: categoryIndex == 0) { categoryIndex = 0 }
                        CategoryTab(text: "Friends", selected: categoryIndex == 1) {
                            categoryIndex = 1
                            selectedFriendSubCategory = .posts
                        }
                        CategoryTab(text: "Public", selected: categoryIndex == 2) { categoryIndex = 2 }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                    if categoryIndex == 1 {
                        HStack(spacing: 4) {
                            ForEach(FriendSubCategory.allCases, id: \.self) { subCat in
                                CategoryTab(
                                    text: subCat.title,
                                    selected: selectedFriendSubCategory == subCat,
                                    action: { selectedFriendSubCategory = subCat },
                                    font: .subheadline,
                                    horizontalPadding: 20,
                                    expand: false
                                )
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if showVisitedSections {
                            if !notVisitedPosts.isEmpty {
                                if categoryIndex != 0 {
                                    Text("Not Visited")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.leading)
                                }

                                ForEach(notVisitedPosts) { post in
                                    Button {
                                        selectedPost = post
                                        showViewAll = false
                                    } label: {
                                        PostRow(
                                            post: post,
                                            isUser: categoryIndex == 1 && selectedFriendSubCategory == .users,
                                            isRequest: categoryIndex == 1 && selectedFriendSubCategory == .requests,
                                            onAccept: {
                                                if categoryIndex == 1 && selectedFriendSubCategory == .requests {
                                                    vm.acceptFriendRequest(username: post.username)
                                                }
                                            },
                                            onReject: {
                                                if categoryIndex == 1 && selectedFriendSubCategory == .requests {
                                                    vm.rejectFriendRequest(username: post.username)
                                                }
                                            },
                                            onUnfriend: {
                                                if categoryIndex == 1 && selectedFriendSubCategory == .users {
                                                    vm.unfriend(username: post.username)
                                                }
                                            }
                                        )
                                    }
                                }
                            }

                            if !visitedPosts.isEmpty {
                                Text("Visited")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.leading)

                                ForEach(visitedPosts) { post in
                                    Button {
                                        selectedPost = post
                                        showViewAll = false
                                    } label: {
                                        PostRow(
                                            post: post,
                                            isUser: categoryIndex == 1 && selectedFriendSubCategory == .users,
                                            isRequest: categoryIndex == 1 && selectedFriendSubCategory == .requests,
                                            onAccept: {
                                                if categoryIndex == 1 && selectedFriendSubCategory == .requests {
                                                    vm.acceptFriendRequest(username: post.username)
                                                }
                                            },
                                            onReject: {
                                                if categoryIndex == 1 && selectedFriendSubCategory == .requests {
                                                    vm.rejectFriendRequest(username: post.username)
                                                }
                                            },
                                            onUnfriend: {
                                                if categoryIndex == 1 && selectedFriendSubCategory == .users {
                                                    vm.unfriend(username: post.username)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        } else {
                            if selectedFriendSubCategory == .requests {
                                let visibleReceived = searchText.isEmpty
                                    ? receivedUsers
                                    : receivedUsers.filter { $0.username.localizedCaseInsensitiveContains(searchText) }

                                let visibleDiscover = searchText.isEmpty
                                    ? discoverUsers
                                    : discoverUsers.filter { $0.username.localizedCaseInsensitiveContains(searchText) }

                                Text("Received")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.leading)

                                if visibleReceived.isEmpty {
                                    Text("No received requests")
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal)
                                } else {
                                    ForEach(visibleReceived, id: \.id) { user in
                                        HStack {
                                            HStack(spacing: 10) {
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 40, height: 40)
                                                    .foregroundColor(.white)
                                                Text(user.username)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }

                                            Spacer()

                                            Button(action: { withAnimation { vm.acceptFriendRequest(username: user.username) } }) {
                                                Text("Accept")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.black)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 12)
                                                    .background(Color.white)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            Button(action: { withAnimation { vm.rejectFriendRequest(username: user.username) } }) {
                                                Text("Reject")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 12)
                                                    .background(Color.black)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }

                                Text("Discover")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.leading)

                                if visibleDiscover.isEmpty {
                                    Text("No users found")
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal)
                                } else {
                                    ForEach(visibleDiscover, id: \.id) { user in
                                        HStack {
                                            HStack(spacing: 10) {
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 40, height: 40)
                                                    .foregroundColor(.white)
                                                Text(user.username)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }

                                            Spacer()

                                            if vm.isFriend(user.username) {
                                                Button(action: { withAnimation { vm.unfriend(username: user.username) } }) {
                                                    Text("Unfriend")
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.black)
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.white)
                                                        .clipShape(Capsule())
                                                }
                                            } else {
                                                let isPending = vm.didSendRequest(to: user.username)
                                                Button(action: { withAnimation { vm.toggleSendRequest(username: user.username) } }) {
                                                    Text(isPending ? "Pending" : "Friend")
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.black)
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.white)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                            if selectedFriendSubCategory == .users {
                                ForEach(filteredUsers, id: \.id) { user in
                                    HStack {
                                        HStack(spacing: 10) {
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .foregroundColor(.white)
                                            Text(user.username)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }

                                        Spacer()

                                        if selectedFriendSubCategory == .requests {
                                            if vm.isFriend(user.username) {
                                                Button(action: { withAnimation { vm.unfriend(username: user.username) } }) {
                                                    Text("Unfriend")
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.black)
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.white)
                                                        .clipShape(Capsule())
                                                }
                                            } else {
                                                let isPending = vm.didSendRequest(to: user.username)
                                                Button(action: { withAnimation { vm.toggleSendRequest(username: user.username) } }) {
                                                    Text(isPending ? "Pending" : "Friend")
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.black)
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.white)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        } else if selectedFriendSubCategory == .users {
                                            Button(action: { withAnimation { vm.unfriend(username: user.username) } }) {
                                                Text("Unfriend")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.black)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 12)
                                                    .background(Color.white)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    TextField("Search for artifacts or users...", text: $searchText)
                        .foregroundColor(.white)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .placeholder(when: searchText.isEmpty) {
                            Text("Search for artifacts or users...")
                                .foregroundColor(.white.opacity(0.5))
                        }
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .padding(.horizontal)
                .padding(.bottom, 16)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { showViewAll = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 26))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .onChange(of: categoryIndex) { _ in
            searchText = ""
        }
        .onChange(of: selectedFriendSubCategory) { _ in
            searchText = ""
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow { placeholder() }
            self
        }
    }
}

private struct CategoryTab: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    var font: Font = .headline
    var horizontalPadding: CGFloat = 16
    var expand: Bool = true

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
                .foregroundColor(selected ? .white : .white.opacity(0.6))
                .padding(.horizontal, horizontalPadding)
        }
        .frame(maxWidth: expand ? .infinity : nil)
    }
}

private struct PostRow: View {
    let post: Post
    var isUser: Bool = false
    var isRequest: Bool = false
    var onAccept: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil
    var onUnfriend: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                if post.title.isEmpty {
                    Text(post.username)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(post.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        Text(post.username)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(post.date)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            Spacer()

            if isRequest {
                HStack(spacing: 8) {
                    Button(action: { onAccept?() }) {
                        Text("Accept")
                            .font(.subheadline.bold())
                            .foregroundColor(.black)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: { onReject?() }) {
                        Text("Reject")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                }
            } else if isUser {
                Button(action: { onUnfriend?() }) {
                    Text("Unfriend")
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

//#Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(
            showProfile: .constant(true),
        )
        .environmentObject(SessionManager())
    }
}

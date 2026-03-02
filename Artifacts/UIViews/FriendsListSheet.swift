//
//  FriendsListSheet.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import SwiftUI
import FirebaseFirestore

struct FriendsListSheet: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var friendsService: FriendsService

    @Binding var friends: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var search = ""

    struct RequestRow: Identifiable, Hashable {
        let id: String
        let requesterUid: String
        let username: String
        let profilePictureURL: String?
    }

    @State private var incoming: [RequestRow] = []
    @State private var friendRows: [FriendUser] = []
    @State private var suggestions: [FriendUser] = []
    @State private var pendingUIDs: Set<String> = []

    @State private var listenerFriends: ListenerRegistration?
    @State private var listenerIncoming: ListenerRegistration?
    @State private var listenerAllLinks: ListenerRegistration?

    @State private var searchTask: Task<Void, Never>?

    @State private var selectedChatFriend: FriendUser?

    private var myUid: String? { session.user?.uid }

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearch.isEmpty
    }

    private var filteredFriends: [FriendUser] {
        let base = friendRows.sorted { $0.username.lowercased() < $1.username.lowercased() }
        guard isSearching else { return base }
        let q = trimmedSearch.lowercased()
        return base.filter { $0.username.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FriendsSheetBackground()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        topBar

                        FriendsSearchField(text: $search)
                            .padding(.horizontal, 16)

                        if !incoming.isEmpty {
                            sectionCard(title: "Friend requests", badge: incoming.count) {
                                VStack(spacing: 10) {
                                    ForEach(incoming) { r in
                                        FriendRow(
                                            title: r.username,
                                            subtitle: nil,
                                            leadingImageURL: r.profilePictureURL,
                                            leadingSystemImage: "person.fill",
                                            primaryTitle: "Confirm",
                                            secondaryTitle: "Delete",
                                            primaryStyle: .primary,
                                            secondaryStyle: .danger,
                                            isPrimaryDisabled: false,
                                            onPrimary: { accept(requesterUid: r.requesterUid) },
                                            onSecondary: { decline(requesterUid: r.requesterUid) }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if !isSearching {
                            sectionCard(title: "Friends", badge: max(friendRows.count, friends.count)) {
                                let rows = resolvedFriendsForDefaultView()
                                if rows.isEmpty {
                                    EmptyStateRow(
                                        systemImage: "person.2",
                                        title: "No friends yet",
                                        message: "Search a username to send a request."
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(rows) { u in
                                            FriendRow(
                                                title: u.username,
                                                subtitle: nil,
                                                leadingImageURL: u.profilePictureURL,
                                                leadingSystemImage: "person.fill",
                                                primaryTitle: "Message",
                                                secondaryTitle: "Remove",
                                                primaryStyle: .primary,
                                                secondaryStyle: .secondary,
                                                isPrimaryDisabled: false,
                                                onPrimary: { selectedChatFriend = u },
                                                onSecondary: { removeFriend(friendUid: u.id) }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            sectionCard(title: "Friends", badge: filteredFriends.count) {
                                if filteredFriends.isEmpty {
                                    EmptyStateRow(
                                        systemImage: "magnifyingglass",
                                        title: "No matches",
                                        message: "Try a different search."
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(filteredFriends) { u in
                                            FriendRow(
                                                title: u.username,
                                                subtitle: nil,
                                                leadingImageURL: u.profilePictureURL,
                                                leadingSystemImage: "person.fill",
                                                primaryTitle: "Message",
                                                secondaryTitle: "Remove",
                                                primaryStyle: .primary,
                                                secondaryStyle: .secondary,
                                                isPrimaryDisabled: false,
                                                onPrimary: { selectedChatFriend = u },
                                                onSecondary: { removeFriend(friendUid: u.id) }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            sectionCard(title: "People", badge: suggestions.count) {
                                if suggestions.isEmpty {
                                    EmptyStateRow(
                                        systemImage: "person.crop.circle.badge.questionmark",
                                        title: "No people found",
                                        message: "Search by exact prefix."
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(suggestions) { u in
                                            let isPending = pendingUIDs.contains(u.id)

                                            FriendRow(
                                                title: u.username,
                                                subtitle: isPending ? "Request sent" : nil,
                                                leadingImageURL: u.profilePictureURL,
                                                leadingSystemImage: "person.fill",
                                                primaryTitle: isPending ? "Sent" : "Add",
                                                secondaryTitle: isPending ? "Unsend" : "Hide",
                                                primaryStyle: isPending ? .secondary : .primary,
                                                secondaryStyle: .secondary,
                                                isPrimaryDisabled: isPending,
                                                onPrimary: {
                                                    if !isPending { add(username: u.username) }
                                                },
                                                onSecondary: {
                                                    if isPending {
                                                        unsend(userId: u.id)
                                                    } else {
                                                        withAnimation(.easeInOut(duration: 0.20)) {
                                                            suggestions.removeAll { $0.id == u.id }
                                                        }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationBackground(.black)
        .onAppear(perform: startListening)
        .onDisappear {
            listenerFriends?.remove()
            listenerIncoming?.remove()
            listenerAllLinks?.remove()
            searchTask?.cancel()
        }
        .onChange(of: search) { _, _ in
            debounceSearch()
        }
        .sheet(item: $selectedChatFriend) { friend in
            ChatView(friend: friend)
                .environmentObject(session)
                .presentationDetents([.large])
                .presentationBackground(.black)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Friends")
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
        badge: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundColor(Color.white.opacity(0.90))

                CountBadge(value: badge)

                Spacer()
            }

            content()
        }
        .padding(14)
        .background(FriendsCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.50), radius: 18, x: 0, y: 12)
    }

    private func resolvedFriendsForDefaultView() -> [FriendUser] {
        if !friendRows.isEmpty {
            return friendRows.sorted { $0.username.lowercased() < $1.username.lowercased() }
        }

        return friends
            .map { FriendUser(id: $0, username: $0, profilePictureURL: nil) }
            .sorted { $0.username.lowercased() < $1.username.lowercased() }
    }

    private func startAllLinksListener() {
        do {
            listenerAllLinks = try friendsService.listenAllLinkPartners { _, pending, _ in
                Task { @MainActor in
                    self.pendingUIDs = pending
                }
            }
        } catch {
            print("listenAllLinkPartners failed:", error)
        }
    }

    private func startListening() {
        Task {
            do {
                let uids = try await friendsService.fetchAcceptedFriendUIDsOnce()
                let users = try await friendsService.fetchUsernames(for: uids)
                let sorted = users.sorted { $0.username.lowercased() < $1.username.lowercased() }
                await MainActor.run {
                    self.friendRows = sorted
                    self.friends = sorted.map { $0.username }
                }
            } catch {
                print("fetchAcceptedFriendUIDsOnce error:", error)
            }
        }

        do {
            listenerFriends = try friendsService.listenFriendUIDs { uids in
                Task {
                    let users = try? await friendsService.fetchUsernames(for: uids)
                    let sorted = (users ?? []).sorted { $0.username.lowercased() < $1.username.lowercased() }
                    await MainActor.run {
                        self.friendRows = sorted
                        self.friends = sorted.map { $0.username }
                    }
                }
            }
        } catch {
            print("listenFriendUIDs failed:", error)
        }

        do {
            listenerIncoming = try friendsService.listenIncomingRequests { rows in
                Task {
                    let requesters = rows.map { $0.requesterUid }
                    let users = try? await friendsService.fetchUsernames(for: requesters)
                    let map = Dictionary(uniqueKeysWithValues: (users ?? []).map { ($0.id, ($0.username, $0.profilePictureURL)) })
                    let display = rows.map {
                        let tuple = map[$0.requesterUid]
                        return RequestRow(
                            id: $0.id,
                            requesterUid: $0.requesterUid,
                            username: tuple?.0 ?? "user",
                            profilePictureURL: tuple?.1
                        )
                    }
                    .sorted { $0.username.lowercased() < $1.username.lowercased() }

                    await MainActor.run { self.incoming = display }
                }
            }
        } catch {
            print("listenIncomingRequests failed:", error)
        }

        startAllLinksListener()
    }

    private func debounceSearch() {
        searchTask?.cancel()

        let q = trimmedSearch
        guard !q.isEmpty else {
            suggestions = []
            return
        }

        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            await runSearch(prefix: q)
        }
    }

    @MainActor
    private func runSearch(prefix: String) async {
        guard let me = myUid else { return }

        let existing = Set(friendRows.map { $0.id })
            .union(incoming.map { $0.requesterUid })

        let results = (try? await friendsService.searchUsernames(prefix: prefix, limit: 25)) ?? []

        let filtered = results
            .filter { $0.id != me && !existing.contains($0.id) }
            .sorted { $0.username.lowercased() < $1.username.lowercased() }

        self.suggestions = filtered
    }

    private func add(username: String) {
        Task {
            do { try await friendsService.sendRequest(toUsername: username) }
            catch { print("sendRequest error:", error) }
        }
    }

    private func accept(requesterUid: String) {
        Task {
            do { try await friendsService.acceptRequest(from: requesterUid) }
            catch { print("accept error:", error) }
        }
    }

    private func decline(requesterUid: String) {
        Task {
            do { try await friendsService.declineRequest(from: requesterUid) }
            catch { print("decline error:", error) }
        }
    }

    private func unsend(userId: String) {
        Task {
            do { try await friendsService.removeLink(with: userId) }
            catch { print("unsend error:", error) }
        }
    }

    private func removeFriend(friendUid: String) {
        Task {
            do { try await friendsService.removeLink(with: friendUid) }
            catch { print("removeFriend error:", error) }
        }
    }
}

private struct FriendsSheetBackground: View {
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

private struct FriendsCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.46))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
    }
}

private struct CountBadge: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.custom("Poppins-SemiBold", size: 12))
            .foregroundColor(Color.black.opacity(0.90))
            .frame(height: 20)
            .padding(.horizontal, 8)
            .background(Color("MintGreen"))
            .clipShape(Capsule())
    }
}

private struct FriendsSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color("MintGreen").opacity(0.85))

            ZStack(alignment: .leading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Search usernames")
                        .font(.custom("Poppins-Regular", size: 15))
                        .foregroundColor(Color.white.opacity(0.38))
                }

                TextField("", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundColor(Color.white.opacity(0.92))
                    .tint(Color("MintGreen"))
            }

            if !text.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("MintGreen").opacity(0.14), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

private struct EmptyStateRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("MintGreen").opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("MintGreen").opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundColor(Color.white.opacity(0.90))

                Text(message)
                    .font(.custom("Poppins-Regular", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct FriendRow: View {
    enum ActionStyle {
        case primary
        case secondary
        case danger
    }

    let title: String
    let subtitle: String?
    let leadingImageURL: String?
    let leadingSystemImage: String

    let primaryTitle: String
    let secondaryTitle: String

    let primaryStyle: ActionStyle
    let secondaryStyle: ActionStyle

    let isPrimaryDisabled: Bool

    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle().stroke(Color("MintGreen").opacity(0.18), lineWidth: 1)
                    )

                if let urlString = leadingImageURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: leadingSystemImage)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color("MintGreen").opacity(0.92))
                        }
                    }
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                } else {
                    Image(systemName: leadingSystemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("MintGreen").opacity(0.92))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(title)")
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .layoutPriority(10)

            Spacer(minLength: 8)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ActionCapsuleButton(
                        title: secondaryTitle,
                        style: secondaryStyle,
                        isDisabled: false,
                        onTap: onSecondary
                    )

                    ActionCapsuleButton(
                        title: primaryTitle,
                        style: primaryStyle,
                        isDisabled: isPrimaryDisabled,
                        onTap: onPrimary
                    )
                }

                VStack(spacing: 8) {
                    ActionCapsuleButton(
                        title: primaryTitle,
                        style: primaryStyle,
                        isDisabled: isPrimaryDisabled,
                        onTap: onPrimary
                    )

                    ActionCapsuleButton(
                        title: secondaryTitle,
                        style: secondaryStyle,
                        isDisabled: false,
                        onTap: onSecondary
                    )
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

private struct ActionCapsuleButton: View {
    let title: String
    let style: FriendRow.ActionStyle
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(.custom("Poppins-SemiBold", size: 13))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 92)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .foregroundColor(foreground)
                .background(background)
                .overlay(
                    Capsule().stroke(stroke, lineWidth: 1)
                )
                .clipShape(Capsule())
                .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foreground: Color {
        switch style {
        case .primary: return Color.black.opacity(0.92)
        case .secondary: return Color.white.opacity(0.90)
        case .danger: return Color.white.opacity(0.90)
        }
    }

    private var background: Color {
        switch style {
        case .primary: return Color("MintGreen")
        case .secondary: return Color.white.opacity(0.06)
        case .danger: return Color.red.opacity(0.22)
        }
    }

    private var stroke: Color {
        switch style {
        case .primary: return Color("MintGreen").opacity(0.20)
        case .secondary: return Color.white.opacity(0.10)
        case .danger: return Color.red.opacity(0.30)
        }
    }
}

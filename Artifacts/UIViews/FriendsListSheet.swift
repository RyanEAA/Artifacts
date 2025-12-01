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

    // Search
    @State private var search = ""

    // Incoming requests (display model)
    struct RequestRow: Identifiable, Hashable {
        let id: String            // friendLinks doc id
        let requesterUid: String
        let username: String
        let avatarURL: URL? = nil  // hook up later if you add profilePictureURL
    }
    @State private var incoming: [RequestRow] = []

    // Friends/suggestions
    @State private var friendRows: [FriendUser] = []
    @State private var suggestions: [FriendUser] = []

    // Link state (from listenAllLinkPartners)
    @State private var pendingUIDs: Set<String> = []

    // Listeners
    @State private var listenerFriends: ListenerRegistration?
    @State private var listenerIncoming: ListenerRegistration?
    @State private var listenerAllLinks: ListenerRegistration?   // <— add this

    private var myUid: String? { session.user?.uid }

    var body: some View {
        NavigationStack {
            List {
                // 1) Search bar
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search friends & users…", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                }

                // 2) Friend requests (if any)
                if !incoming.isEmpty {
                    Section {
                        headerRow(
                            title: "Friend requests",
                            badge: incoming.count
                        ) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        ForEach(incoming) { r in
                            facebookRow(
                                title: r.username,
                                subtitle: nil,
                                avatarURL: r.avatarURL,
                                primaryTitle: "Confirm",
                                secondaryTitle: "Delete",
                                onPrimary: { accept(requesterUid: r.requesterUid) },
                                onSecondary: { decline(requesterUid: r.requesterUid) }
                            )
                        }
                    }
                }

                // 3) Friends + People, depending on search
                let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
                let filteredFriends = filteredFriendsList()

                if q.isEmpty {
                    // === DEFAULT: show ALL friends A–Z ===
                    Section {
                        let rowsToShow: [FriendUser] =
                            !friendRows.isEmpty
                            ? filteredFriends
                            : friends
                              .map { FriendUser(id: $0, username: $0) } // fallback until Firestore resolves
                              .sorted { $0.username.lowercased() < $1.username.lowercased() }

                        if rowsToShow.isEmpty {
                            Text("You have no friends yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(rowsToShow) { u in
                                facebookRow(
                                    title: u.username,
                                    subtitle: nil,
                                    avatarURL: nil, // hook up profilePictureURL later if you want
                                    primaryTitle: "Message",
                                    secondaryTitle: "Remove",
                                    onPrimary: {},
                                    onSecondary: {}
                                )
                            }
                        }
                    } header: {
                        headerRow(
                            title: "Your friends",
                            badge: max(friendRows.count, friends.count)
                        ) { EmptyView() }
                    }

                } else {
                    // === SEARCH MODE ===

                    // 3a) Friends that match
                    Section {
                        if filteredFriends.isEmpty {
                            Text("No friends match “\(q)”.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(filteredFriends) { u in
                                facebookRow(
                                    title: u.username,
                                    subtitle: nil,
                                    avatarURL: nil,
                                    primaryTitle: "Message",
                                    secondaryTitle: "Remove",
                                    onPrimary: {},
                                    onSecondary: {}
                                )
                            }
                        }
                    } header: {
                        headerRow(
                            title: "Friends",
                            badge: filteredFriends.count
                        ) { EmptyView() }
                    }

                    // 3b) People (non-friends & not pending) — uses `suggestions` filled by runSearch(prefix:)
                    Section {
                        if suggestions.isEmpty {
                            Text("No people found.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(suggestions) { u in
                                let isPending = pendingUIDs.contains(u.id)

                                facebookRow(
                                    title: u.username,
                                    subtitle: nil,
                                    avatarURL: nil,
                                    primaryTitle: isPending ? "Sent" : "Add",
                                    secondaryTitle: isPending ? "Unsend" : "Hide",
                                    onPrimary: {
                                        if !isPending {
                                            add(username: u.username)
                                        }
                                    },
                                    onSecondary: {
                                        if isPending {
                                            unsend(userId: u.id)
                                        } else {
                                            // Optional: hide from local suggestions
                                            // suggestions.removeAll { $0.id == u.id }
                                        }
                                    }
                                )
                            }
                        }
                    } header: {
                        headerRow(
                            title: "People",
                            badge: suggestions.count
                        ) { EmptyView() }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }

        .onAppear(perform: startListening)
        .onDisappear {
            listenerFriends?.remove()
            listenerIncoming?.remove()
            listenerAllLinks?.remove()
        }
        .onChange(of: search) { _, _ in debounceSearch() }
    }

    // MARK: - Header + Facebook row components

    @ViewBuilder
    private func headerRow<Trailing: View>(
        title: String,
        badge: Int,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            HStack(spacing: 6) {
                Text(title).font(.headline.weight(.semibold))
                Text("\(badge)").font(.headline.weight(.semibold)).foregroundStyle(.red)
            }
            Spacer()
            trailing()
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }

    @ViewBuilder
    private func facebookRow(
        title: String,
        subtitle: String?,
        avatarURL: URL?,
        primaryTitle: String,
        secondaryTitle: String,
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar
            ZStack {
                Circle().fill(Color.gray.opacity(0.15))
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48)

            // Name + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }

            Spacer()

            // Buttons like Facebook
            HStack(spacing: 8) {
                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                }
            }
        }
    }
    private func startAllLinksListener() {
        do {
            listenerAllLinks = try friendsService.listenAllLinkPartners { partners, pending, accepted in
                // We only need pending UIDs for "Sent/Unsend"
                Task { @MainActor in
                    self.pendingUIDs = pending
                }
            }
        } catch {
            print("⚠️ listenAllLinkPartners failed:", error)
        }
    }


    // MARK: - Data
    private func startListening() {
        // First: one-shot fetch so the list is not empty when opening the sheet
        Task {
            do {
                let uids = try await friendsService.fetchAcceptedFriendUIDsOnce()
                let users = try await friendsService.fetchUsernames(for: uids)
                let sorted = users.sorted { $0.username.lowercased() < $1.username.lowercased() }
                await MainActor.run {
                    self.friendRows = sorted
                    self.friends = sorted.map { $0.username }  // keep external binding in sync
                }
            } catch {
                print("🔥 fetchAcceptedFriendUIDsOnce error:", error)
            }
        }

        // Then: the live listener to keep it updated
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
            print("🔥 listenFriendUIDs failed to start:", error)
        }

        // Incoming requests listener (recipient == me)
        do {
            listenerIncoming = try friendsService.listenIncomingRequests { rows in
                Task {
                    let requesters = rows.map { $0.requesterUid }
                    let users = try? await friendsService.fetchUsernames(for: requesters)
                    let map = Dictionary(uniqueKeysWithValues: (users ?? []).map { ($0.id, $0.username) })
                    let display = rows.map { RequestRow(id: $0.id, requesterUid: $0.requesterUid, username: map[$0.requesterUid] ?? "user") }
                        .sorted { $0.username.lowercased() < $1.username.lowercased() }
                    await MainActor.run { self.incoming = display }
                }
            }
        } catch {
            print("🔥 listenIncomingRequests failed to start:", error)
        }
        
        startAllLinksListener()
    }

    private func filteredFriendsList() -> [FriendUser] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = friendRows.sorted { $0.username.lowercased() < $1.username.lowercased() }
        guard !q.isEmpty else { return base }
        return base.filter { $0.username.lowercased().contains(q) }
    }

    // Debounced global search (People)
    @State private var searchTask: Task<Void, Never>?
    private func debounceSearch() {
        searchTask?.cancel()
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { suggestions = []; return }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            await runSearch(prefix: q)
        }
    }

    @MainActor
    private func runSearch(prefix: String) async {
        guard let me = myUid else { return }
        let existing = Set(friendRows.map { $0.id }).union(incoming.map { $0.requesterUid })
        let results = (try? await friendsService.searchUsernames(prefix: prefix, limit: 25)) ?? []
        let filtered = results
            .filter { $0.id != me && !existing.contains($0.id) }
            .sorted { $0.username.lowercased() < $1.username.lowercased() }
        self.suggestions = filtered
    }

    // MARK: - Actions

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
            do {
                try await friendsService.removeLink(with: userId)
            } catch {
                print("unsend error:", error)
            }
        }
    }
}

#Preview {
    FriendsListSheet(friends: .constant(["sarah_creates","devon_art","luna_doodles"]))
        .environmentObject(SessionManager())
        .environmentObject(FriendsService())
}

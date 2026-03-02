//
//  FriendsService.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Minimal display model for a user row.
public struct FriendUser: Identifiable, Hashable {
    public let id: String      // uid
    public let username: String
    public let profilePictureURL: String?
}

@MainActor
final class FriendsService: ObservableObject {

    // MARK: - Firestore

    let db = Firestore.firestore()

    /// Current user UID (throws if missing to prevent silent rule errors).
    private var uid: String {
        get throws {
            if let u = Auth.auth().currentUser?.uid { return u }
            throw FriendsError.notSignedIn
        }
    }

    enum FriendsError: Error {
        case notSignedIn
        case userNotFound
        case cannotFriendYourself
    }

    // MARK: - Link helpers

    /// Stable pair id: "minUid_maxUid"
    private func pairId(_ a: String, _ b: String) -> String {
        a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    // MARK: - LISTENERS

    /// Listen to *all* links where I'm a participant (any status).
    /// Useful for excluding already-linked users from search suggestions.
    /// - Returns: Firestore listener to retain.
    func listenAllLinkPartners(
        _ onChange: @escaping (_ partnerUIDs: Set<String>, _ pendingUIDs: Set<String>, _ acceptedUIDs: Set<String>) -> Void
    ) throws -> ListenerRegistration {
        let me = try uid
        return db.collection("friendLinks")
            .whereField("participants", arrayContains: me)
            .addSnapshotListener { snap, _ in
                var partners = Set<String>()
                var pending  = Set<String>()
                var accepted = Set<String>()
                for doc in snap?.documents ?? [] {
                    let ps = doc.get("participants") as? [String] ?? []
                    guard let other = ps.first(where: { $0 != me }) else { continue }
                    partners.insert(other)
                    let status = (doc.get("status") as? String) ?? ""
                    if status == "pending" { pending.insert(other) }
                    if status == "accepted" { accepted.insert(other) }
                }
                onChange(partners, pending, accepted)
            }
    }

    /// Listen to *accepted* friends (UIDs only).
    func listenFriendUIDs(_ onChange: @escaping ([String]) -> Void) throws -> ListenerRegistration {
        let me = try uid
        return db.collection("friendLinks")
            .whereField("participants", arrayContains: me)
            .whereField("status", isEqualTo: "accepted")
            .addSnapshotListener { snap, error in
                if let error = error {
                    print("🔥 listenFriendUIDs error:", error)
                    onChange([])
                    return
                }
                let uids = (snap?.documents ?? []).compactMap { doc -> String? in
                    let ps = doc.get("participants") as? [String] ?? []
                    return ps.first(where: { $0 != me })
                }
                onChange(Array(Set(uids)))
            }
    }

    // MARK: - FETCH / SEARCH

    /// One-shot fetch of accepted friend UIDs.
    func fetchAcceptedFriendUIDsOnce() async throws -> [String] {
        let me = try uid
        let snap = try await db.collection("friendLinks")
            .whereField("participants", arrayContains: me)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments()

        let uids = snap.documents.compactMap { doc -> String? in
            let ps = doc.get("participants") as? [String] ?? []
            return ps.first(where: { $0 != me })
        }
        return Array(Set(uids))
    }

    /// Resolve usernames for a list of UIDs (chunks of 10 for Firestore `in`).
    func fetchUsernames(for uids: [String]) async throws -> [FriendUser] {
        guard !uids.isEmpty else { return [] }
        var result: [FriendUser] = []
        for chunk in uids.chunked(into: 10) {
            let snap = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            result += snap.documents.map {
                FriendUser(
                    id: $0.documentID,
                    username: ($0.get("username") as? String) ?? $0.documentID,
                    profilePictureURL: ($0.get("profilePictureURL") as? String)
                )
            }
        }
        return result
    }

    /// Case-insensitive prefix search by using **lowercase-only usernames**.
    /// Assumes all saved usernames are already lowercase.
    func searchUsernames(prefix: String, limit: Int = 25) async throws -> [FriendUser] {
        let q = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        let start = q
        let end   = q + "\u{f8ff}" // high unicode sentinel for prefix range

        let snap = try await db.collection("users")
            .order(by: "username")
            .start(at: [start])
            .end(at: [end])
            .limit(to: limit)
            .getDocuments()

        return snap.documents.map {
            FriendUser(
                id: $0.documentID,
                username: ($0.get("username") as? String) ?? $0.documentID,
                profilePictureURL: ($0.get("profilePictureURL") as? String)
            )
        }
    }

    // MARK: - ACTIONS

    /// Send a friend request to a username.
    /// - Note: Enforces lowercase before query; prevents friending yourself.
    func sendRequest(toUsername rawUsername: String) async throws {
        guard let me = Auth.auth().currentUser?.uid else { throw FriendsError.notSignedIn }

        let uname = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !uname.isEmpty else { return }

        // 1) Resolve username -> uid
        let userSnap = try await db.collection("users")
            .whereField("username", isEqualTo: uname)
            .limit(to: 1)
            .getDocuments()

        guard let doc = userSnap.documents.first else { throw FriendsError.userNotFound }
        let other = doc.documentID
        guard other != me else { throw FriendsError.cannotFriendYourself }

        // 2) Stable doc id OR random; both work with your rules
        let pairId = me < other ? "\(me)_\(other)" : "\(other)_\(me)"

        // 3) Write ALL required fields in one create
        let data: [String: Any] = [
            "participants": [me, other],            // UIDs, not usernames
            "requesterUid": me,
            "recipientUid": other,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        print("me:", me)
        print("data:", data)

        // Use setData (create/overwrite), NOT updateData (which fails on first write)
        try await db.collection("friendLinks").document(pairId).setData(data)
    }

    /// Accept a pending request from `otherUid`. (Recipient must call.)
    func acceptRequest(from otherUid: String) async throws {
        let me = try uid

        let snap = try await db.collection("friendLinks")
            .whereField("participants", arrayContains: me)
            .whereField("status", isEqualTo: "pending")
            .whereField("recipientUid", isEqualTo: me)
            .whereField("requesterUid", isEqualTo: otherUid)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snap.documents.first else {
            throw NSError(domain: "FriendsService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No pending request from this user."])
        }

        try await doc.reference.updateData([
            "status": "accepted",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Decline a pending request from `otherUid`. (Recipient must call.)
    func declineRequest(from otherUid: String) async throws {
        let me = try uid

        let snap = try await db.collection("friendLinks")
            .whereField("participants", arrayContains: me)
            .whereField("status", isEqualTo: "pending")
            .whereField("recipientUid", isEqualTo: me)
            .whereField("requesterUid", isEqualTo: otherUid)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snap.documents.first else {
            throw NSError(domain: "FriendsService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No pending request from this user."])
        }

        try await doc.reference.updateData([
            "status": "declined",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Cancel a sent request or unfriend (delete the link).
    func removeLink(with otherUid: String) async throws {
        let me = try uid
        let id = pairId(me, otherUid)
        try await db.collection("friendLinks").document(id).delete()
    }

    // MARK: - Incoming requests listener (recipient == me)

    struct IncomingRequest: Identifiable, Hashable {
        let id: String            // friendLinks doc id
        let requesterUid: String
    }

    func listenIncomingRequests(
        _ onChange: @escaping ([IncomingRequest]) -> Void
    ) throws -> ListenerRegistration {
        let me = try uid
        return db.collection("friendLinks")
            .whereField("participants", arrayContains: me)
            .whereField("recipientUid", isEqualTo: me)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snap, error in
                if let error = error {
                    print("🔥 listenIncomingRequests error:", error)
                    onChange([])
                    return
                }
                let rows = (snap?.documents ?? []).map {
                    IncomingRequest(
                        id: $0.documentID,
                        requesterUid: ($0.get("requesterUid") as? String) ?? ""
                    )
                }
                onChange(rows)
            }
    }
}

// MARK: - Small util

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        var i = 0
        while i < count {
            let j = Swift.min(i + size, count)
            chunks.append(Array(self[i..<j]))
            i = j
        }
        return chunks
    }
}

//
//  FriendsService.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 11/4/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class FriendsService: ObservableObject {
    private let db = Firestore.firestore()
    private var uid: String { Auth.auth().currentUser!.uid }

    // Build stable pair id
    private func pairId(_ a: String, _ b: String) -> String {
        a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    // Resolve username -> uid (assuming you store username on users/{uid})
    func uidForUsername(_ username: String) async throws -> String? {
        let snap = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        return snap.documents.first?.documentID
    }

    // Send request
    func sendRequest(toUsername username: String) async throws {
        guard let other = try await uidForUsername(username), other != uid else { return }
        let id = pairId(uid, other)
        let ref = db.collection("friendLinks").document(id)
        try await ref.setData([
            "participants": [uid, other],
            "requesterUid": uid,
            "recipientUid": other,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // Accept / Decline
    func setRequestStatus(pairId id: String, to newStatus: String) async throws {
        try await db.collection("friendLinks").document(id).updateData([
            "status": newStatus,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // Cancel a pending you sent OR unfriend (delete the link)
    func removeLink(with otherUid: String) async throws {
        let id = pairId(uid, otherUid)
        try await db.collection("friendLinks").document(id).delete()
    }

    // Live listeners
    func listenIncomingPending(_ cb: @escaping ([QueryDocumentSnapshot]) -> Void) -> ListenerRegistration {
        db.collection("friendLinks")
            .whereField("recipientUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snap, _ in cb(snap?.documents ?? []) }
    }

    func listenSentPending(_ cb: @escaping ([QueryDocumentSnapshot]) -> Void) -> ListenerRegistration {
        db.collection("friendLinks")
            .whereField("requesterUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snap, _ in cb(snap?.documents ?? []) }
    }

    func listenFriends(_ cb: @escaping ([QueryDocumentSnapshot]) -> Void) -> ListenerRegistration {
        db.collection("friendLinks")
            .whereField("participants", arrayContains: uid)
            .whereField("status", isEqualTo: "accepted")
            .addSnapshotListener { snap, _ in cb(snap?.documents ?? []) }
    }
}

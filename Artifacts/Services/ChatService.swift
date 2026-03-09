//
//  ChatService.swift
//  Artifacts
//
//  Created by Swapnil Puri on 2/24/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let senderUid: String
    let text: String
    let createdAt: Date
}

final class ChatService {
    private let db = Firestore.firestore()

    static func threadId(uidA: String, uidB: String) -> String {
        let a = uidA.lowercased()
        let b = uidB.lowercased()
        return a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    func listenMessages(threadId: String, completion: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        db.collection("chats")
            .document(threadId)
            .collection("messages")
            .order(by: "clientCreatedAt", descending: false)
            .addSnapshotListener(includeMetadataChanges: true) { snap, err in
                if let err {
                    print("⚠️ listenMessages error:", err.localizedDescription)
                    completion([])
                    return
                }

                let docs = snap?.documents ?? []
                let msgs: [ChatMessage] = docs.compactMap { doc in
                    let data = doc.data()
                    let senderUid = data["senderUid"] as? String ?? ""
                    let text = data["text"] as? String ?? ""

                    // Prefer server createdAt when available, otherwise fall back to clientCreatedAt.
                    let serverDate = (data["createdAt"] as? Timestamp)?.dateValue()
                    let clientDate = (data["clientCreatedAt"] as? Timestamp)?.dateValue()
                    let createdAt = serverDate ?? clientDate ?? Date(timeIntervalSince1970: 0)

                    return ChatMessage(
                        id: doc.documentID,
                        senderUid: senderUid,
                        text: text,
                        createdAt: createdAt
                    )
                }

                completion(msgs)
            }
    }

    func ensureThread(threadId: String, participants: [String]) async throws {
        let ref = db.collection("chats").document(threadId)
        let snap = try await ref.getDocument()
        if snap.exists { return }

        try await ref.setData([
            "participants": participants,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func sendMessage(threadId: String, to recipientUid: String, text: String) async throws {
        guard let myUid = Auth.auth().currentUser?.uid else { return }

        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let threadRef = db.collection("chats").document(threadId)
        let msgRef = threadRef.collection("messages").document()

        // Ensure thread exists and participants are set.
        try await threadRef.setData([
            "participants": [myUid, recipientUid],
            "lastMessageSenderUid": myUid,
            "lastMessageText": clean,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        // Write both a local timestamp (immediate UI ordering) and a server timestamp (canonical).
        try await msgRef.setData([
            "senderUid": myUid,
            "recipientUid": recipientUid,
            "text": clean,
            "clientCreatedAt": Timestamp(date: Date()),
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}

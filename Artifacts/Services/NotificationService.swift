//
//  NotificationService.swift
//  Artifacts
//

import Foundation
import FirebaseFirestore
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let db = Firestore.firestore()
    private var uid: String?

    private var friendLinksListener: ListenerRegistration?
    private var chatsListener: ListenerRegistration?
    private var messageListenersByThread: [String: ListenerRegistration] = [:]
    private var sceneListeners: [ListenerRegistration] = []

    private var primedMessageThreads: Set<String> = []
    private var areScenesPrimedByChunk: [Int: Bool] = [:]
    private var seenMessageEventKeys: Set<String> = []
    private var seenSceneEventKeys: Set<String> = []
    private var usernameCache: [String: String] = [:]

    private init() {}

    func start(for uid: String) {
        guard !uid.isEmpty else { return }
        stop()
        self.uid = uid
        requestAuthorizationIfNeeded()
        attachChatsListener(for: uid)
        attachFriendLinksListener(for: uid)
    }

    func stop() {
        friendLinksListener?.remove()
        friendLinksListener = nil
        chatsListener?.remove()
        chatsListener = nil
        messageListenersByThread.values.forEach { $0.remove() }
        messageListenersByThread.removeAll()
        sceneListeners.forEach { $0.remove() }
        sceneListeners.removeAll()
        areScenesPrimedByChunk.removeAll()
        primedMessageThreads.removeAll()
        seenMessageEventKeys.removeAll()
        seenSceneEventKeys.removeAll()
        uid = nil
    }

    private func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func attachChatsListener(for uid: String) {
        chatsListener = db.collection("chats")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    print("⚠️ chats notification listener error:", err.localizedDescription)
                    return
                }
                guard let snap else { return }

                let activeThreadIds = Set(snap.documents.map { $0.documentID })

                for threadId in activeThreadIds where self.messageListenersByThread[threadId] == nil {
                    self.attachMessageListener(threadId: threadId, for: uid)
                }

                let removedThreadIds = Set(self.messageListenersByThread.keys).subtracting(activeThreadIds)
                for threadId in removedThreadIds {
                    self.messageListenersByThread[threadId]?.remove()
                    self.messageListenersByThread.removeValue(forKey: threadId)
                    self.primedMessageThreads.remove(threadId)
                }
            }
    }

    private func attachMessageListener(threadId: String, for uid: String) {
        let listener = db.collection("chats")
            .document(threadId)
            .collection("messages")
            .whereField("recipientUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    print("⚠️ message notification listener error (\(threadId)):", err.localizedDescription)
                    return
                }
                guard let snap else { return }

                let isInitial = !self.primedMessageThreads.contains(threadId)
                if isInitial { self.primedMessageThreads.insert(threadId) }

                for change in snap.documentChanges where change.type == .added {
                    let data = change.document.data()
                    let senderUid = data["senderUid"] as? String ?? ""
                    if senderUid.isEmpty || senderUid == uid { continue }

                    let text = data["text"] as? String ?? "New message"
                    let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                        ?? (data["clientCreatedAt"] as? Timestamp)?.dateValue()
                        ?? Date()
                    let eventKey = "msg:\(threadId):\(change.document.documentID):\(Int(ts.timeIntervalSince1970))"

                    if self.seenMessageEventKeys.contains(eventKey) { continue }
                    self.seenMessageEventKeys.insert(eventKey)
                    if isInitial { continue }

                    Task {
                        let senderUsername = await self.fetchUsername(uid: senderUid) ?? "friend"
                        self.postLocalNotification(
                            id: eventKey,
                            title: "@\(senderUsername)",
                            body: text
                        )
                    }
                }
            }

        messageListenersByThread[threadId] = listener
    }

    private func attachFriendLinksListener(for uid: String) {
        friendLinksListener = db.collection("friendLinks")
            .whereField("participants", arrayContains: uid)
            .whereField("status", isEqualTo: "accepted")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                guard err == nil else { return }

                let friendUIDs: [String] = (snap?.documents ?? []).compactMap { doc in
                    let participants = doc.data()["participants"] as? [String] ?? []
                    return participants.first(where: { $0 != uid })
                }

                self.attachSceneListeners(for: Array(Set(friendUIDs)).sorted())
            }
    }

    private func attachSceneListeners(for friendUIDs: [String]) {
        sceneListeners.forEach { $0.remove() }
        sceneListeners.removeAll()
        areScenesPrimedByChunk.removeAll()
        guard !friendUIDs.isEmpty else { return }

        let chunks = stride(from: 0, to: friendUIDs.count, by: 10).map {
            Array(friendUIDs[$0..<min($0 + 10, friendUIDs.count)])
        }

        for (chunkIndex, chunk) in chunks.enumerated() {
            let reg = db.collection("scenes")
                .whereField("ownerUid", in: chunk)
                .addSnapshotListener { [weak self] snap, err in
                    guard let self else { return }
                    guard err == nil, let snap else { return }

                    let isInitial = !(self.areScenesPrimedByChunk[chunkIndex] ?? false)
                    if isInitial { self.areScenesPrimedByChunk[chunkIndex] = true }

                    for change in snap.documentChanges where change.type != .removed {
                        let data = change.document.data()
                        let ownerUid = data["ownerUid"] as? String ?? ""
                        guard !ownerUid.isEmpty else { continue }
                        guard let savedTs = (data["savedAt"] as? Timestamp)?.dateValue() else { continue }

                        let ts = savedTs
                        let eventKey = "scene:\(change.document.documentID):\(Int(ts.timeIntervalSince1970))"

                        if self.seenSceneEventKeys.contains(eventKey) { continue }
                        self.seenSceneEventKeys.insert(eventKey)
                        if isInitial { continue }

                        Task {
                            let ownerUsername = await self.fetchUsername(uid: ownerUid) ?? "friend"
                            self.postLocalNotification(
                                id: eventKey,
                                title: "@\(ownerUsername)",
                                body: "saved a scene."
                            )
                        }
                    }
                }
            sceneListeners.append(reg)
        }
    }

    private func fetchUsername(uid: String) async -> String? {
        if let cached = usernameCache[uid] { return cached }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let username = doc.data()?["username"] as? String
            if let username, !username.isEmpty {
                usernameCache[uid] = username
                return username
            }
            return nil
        } catch {
            return nil
        }
    }

    private func postLocalNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

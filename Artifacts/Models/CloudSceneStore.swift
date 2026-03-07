//
//  CloudSceneStore.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/28/25.
//

import Foundation
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

enum CloudSceneError: Error { case noUser, uploadFailed(String), downloadFailed(String) }

final class CloudSceneStore {
    static let storage = Storage.storage()
    static let db = Firestore.firestore()

    private static func ref(uid: String, sceneId: String) -> StorageReference {
        storage.reference(withPath: "users/\(uid)/scenes/\(sceneId).worldmap")
    }

    static func save(
        data: Data,
        sceneId: String = UUID().uuidString,
        name: String = "My Scene",
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Ensure a user exists (required for security rules)
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No Firebase user signed in.")
            return completion(.failure(CloudSceneError.noUser))
        }

        // Reference in Storage
        let ref = self.ref(uid: uid, sceneId: sceneId)
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"

        print("📤 Uploading scene \(sceneId) to Firebase Storage...")

        // Upload data
        ref.putData(data, metadata: metadata) { _, uploadError in
            if let uploadError = uploadError {
                print("❌ Upload failed:", uploadError.localizedDescription)
                return completion(.failure(CloudSceneError.uploadFailed(uploadError.localizedDescription)))
            }

            print("✅ Upload complete. Writing Firestore metadata...")

            // Metadata for Firestore
            let doc: [String: Any] = [
                "ownerUid": uid,
                "name": name,
                "storagePath": ref.fullPath,
                "updatedAt": Timestamp(date: Date()),
                "bytes": data.count
            ]

            // Write to Firestore
            self.db.collection("scenes").document(sceneId).setData(doc, merge: true) { error in
                if let error = error {
                    print("❌ Firestore write failed:", error.localizedDescription)
                    completion(.failure(error))
                } else {
                    print("✅ Firestore entry created for scene:", sceneId)
                    completion(.success(sceneId))
                }
            }
        }
    }

    static func resolveWritableSceneId(
        preferredSceneId: String?,
        completion: @escaping (Result<(sceneId: String, remappedFromSceneId: String?), Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(CloudSceneError.noUser))
            return
        }

        guard let preferred = preferredSceneId, !preferred.isEmpty else {
            completion(.success((sceneId: UUID().uuidString, remappedFromSceneId: nil)))
            return
        }

        db.collection("scenes").document(preferred).getDocument { doc, err in
            if let err = err {
                completion(.failure(err))
                return
            }

            // If scene metadata doesn't exist yet, preferred id is safe.
            guard let data = doc?.data() else {
                completion(.success((sceneId: preferred, remappedFromSceneId: nil)))
                return
            }

            let ownerUid = data["ownerUid"] as? String ?? ""
            if ownerUid == uid {
                completion(.success((sceneId: preferred, remappedFromSceneId: nil)))
            } else {
                // Friend-owned scene: fork to a new scene id for writable metadata.
                completion(.success((sceneId: UUID().uuidString, remappedFromSceneId: preferred)))
            }
        }
    }



    static func load(sceneId: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(.failure(CloudSceneError.noUser)) }

        db.collection("scenes").document(sceneId).getDocument { doc, err in
            if let err = err {
                completion(.failure(CloudSceneError.downloadFailed(err.localizedDescription)))
                return
            }

            if
                let data = doc?.data(),
                let storagePath = data["storagePath"] as? String,
                !storagePath.isEmpty
            {
                load(storagePath: storagePath, completion: completion)
                return
            }

            // Backward compatibility for older scene records that may not have storagePath.
            ref(uid: uid, sceneId: sceneId).getData(maxSize: 20 * 1024 * 1024) { data, err in
                if let err = err {
                    completion(.failure(CloudSceneError.downloadFailed(err.localizedDescription)))
                } else if let data = data {
                    completion(.success(data))
                } else {
                    completion(.failure(CloudSceneError.downloadFailed("No data found for scene.")))
                }
            }
        }
    }
}

struct CloudSceneMeta {
    let id: String
    let name: String
    let storagePath: String
    let updatedAt: Date
    let bytes: Int
    let ownerUid: String
}

extension CloudSceneStore {
    private static func fetchAcceptedFriendUIDs(
        for uid: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        db.collection("friendLinks")
            .whereField("participants", arrayContains: uid)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments { snap, err in
                if let err = err {
                    completion(.failure(err))
                    return
                }
                let ids: [String] = (snap?.documents ?? []).compactMap { doc in
                    let participants = doc.data()["participants"] as? [String] ?? []
                    return participants.first(where: { $0 != uid })
                }
                completion(.success(Array(Set(ids))))
            }
    }

    private static func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [items] }
        var chunks: [[T]] = []
        var index = 0
        while index < items.count {
            let end = Swift.min(index + size, items.count)
            chunks.append(Array(items[index..<end]))
            index = end
        }
        return chunks
    }

    private static func decodeSceneMeta(_ doc: QueryDocumentSnapshot) -> CloudSceneMeta {
        let data = doc.data()
        let name = data["name"] as? String ?? "Untitled"
        let storagePath = data["storagePath"] as? String ?? ""
        let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let bytes = data["bytes"] as? Int ?? 0
        let ownerUid = data["ownerUid"] as? String ?? ""
        return CloudSceneMeta(
            id: doc.documentID,
            name: name,
            storagePath: storagePath,
            updatedAt: ts,
            bytes: bytes,
            ownerUid: ownerUid
        )
    }

    private static func decodeSceneMeta(_ doc: DocumentSnapshot) -> CloudSceneMeta? {
        guard let data = doc.data() else { return nil }
        let name = data["name"] as? String ?? "Untitled"
        let storagePath = data["storagePath"] as? String ?? ""
        let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let bytes = data["bytes"] as? Int ?? 0
        let ownerUid = data["ownerUid"] as? String ?? ""
        return CloudSceneMeta(
            id: doc.documentID,
            name: name,
            storagePath: storagePath,
            updatedAt: ts,
            bytes: bytes,
            ownerUid: ownerUid
        )
    }

    private static func fetchMostRecentAccessibleSceneMetaFromArtifacts(
        ownerUIDs: [String],
        completion: @escaping (Result<CloudSceneMeta?, Error>) -> Void
    ) {
        let ownerChunks = chunked(ownerUIDs, size: 10)
        guard !ownerChunks.isEmpty else {
            completion(.success(nil))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?
        var candidates: [(sceneId: String, updatedAt: Date)] = []

        for chunk in ownerChunks {
            group.enter()
            db.collection("artifacts")
                .whereField("ownerUid", in: chunk)
                .whereField("published", isEqualTo: true)
                .order(by: "updatedAt", descending: true)
                .limit(to: 1)
                .getDocuments { snap, err in
                    defer { group.leave() }
                    lock.lock()
                    defer { lock.unlock() }

                    if let err = err {
                        if firstError == nil { firstError = err }
                        return
                    }

                    guard let doc = snap?.documents.first else { return }
                    let data = doc.data()
                    guard let sceneId = data["sceneId"] as? String, !sceneId.isEmpty else { return }
                    let ts = (data["updatedAt"] as? Timestamp)?.dateValue()
                        ?? (data["createdAt"] as? Timestamp)?.dateValue()
                        ?? Date.distantPast
                    candidates.append((sceneId: sceneId, updatedAt: ts))
                }
        }

        group.notify(queue: .main) {
            if let best = candidates.max(by: { $0.updatedAt < $1.updatedAt }) {
                db.collection("scenes").document(best.sceneId).getDocument { doc, err in
                    if let err = err {
                        completion(.failure(err))
                        return
                    }
                    guard let doc = doc, let meta = decodeSceneMeta(doc) else {
                        completion(.success(nil))
                        return
                    }
                    completion(.success(meta))
                }
                return
            }

            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(nil))
            }
        }
    }

    static func load(storagePath: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard !storagePath.isEmpty else {
            completion(.failure(CloudSceneError.downloadFailed("Missing scene storage path.")))
            return
        }
        storage.reference(withPath: storagePath).getData(maxSize: 20 * 1024 * 1024) { data, err in
            if let err = err {
                completion(.failure(CloudSceneError.downloadFailed(err.localizedDescription)))
            } else if let data = data {
                completion(.success(data))
            } else {
                completion(.failure(CloudSceneError.downloadFailed("No data found for scene.")))
            }
        }
    }

    /// Firestore query: most recent scene owned by current user
    static func fetchMostRecentSceneMeta(completion: @escaping (Result<CloudSceneMeta?, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.success(nil)) // not signed in yet; treat as "no scene"
        }

        db.collection("scenes")
            .whereField("ownerUid", isEqualTo: uid)
            .order(by: "updatedAt", descending: true)
            .limit(to: 1)
            .getDocuments { snap, err in
                if let err = err { return completion(.failure(err)) }
                guard let doc = snap?.documents.first else { return completion(.success(nil)) }
                completion(.success(decodeSceneMeta(doc)))
            }
    }

    /// Firestore query: most recent scene visible to current user (self + friends).
    static func fetchMostRecentAccessibleSceneMeta(completion: @escaping (Result<CloudSceneMeta?, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.success(nil))
        }

        fetchAcceptedFriendUIDs(for: uid) { friendResult in
            switch friendResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let friendUIDs):
                let ownerUIDs = Array(Set(friendUIDs + [uid])).sorted()
                let ownerChunks = chunked(ownerUIDs, size: 10)
                guard !ownerChunks.isEmpty else {
                    completion(.success(nil))
                    return
                }

                let group = DispatchGroup()
                let lock = NSLock()
                var firstError: Error?
                var candidates: [CloudSceneMeta] = []

                for chunk in ownerChunks {
                    group.enter()
                    db.collection("scenes")
                        .whereField("ownerUid", in: chunk)
                        .order(by: "updatedAt", descending: true)
                        .limit(to: 1)
                        .getDocuments { snap, err in
                            defer { group.leave() }
                            lock.lock()
                            defer { lock.unlock() }

                            if let err = err {
                                if firstError == nil { firstError = err }
                                return
                            }
                            if let doc = snap?.documents.first {
                                candidates.append(decodeSceneMeta(doc))
                            }
                        }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        // Fallback path: derive candidate scene IDs from visible artifacts.
                        fetchMostRecentAccessibleSceneMetaFromArtifacts(ownerUIDs: ownerUIDs) { fallbackResult in
                            switch fallbackResult {
                            case .success(let fallbackMeta):
                                completion(.success(fallbackMeta))
                            case .failure:
                                completion(.failure(firstError))
                            }
                        }
                        return
                    }
                    guard let latest = candidates.max(by: { $0.updatedAt < $1.updatedAt }) else {
                        fetchMostRecentAccessibleSceneMetaFromArtifacts(ownerUIDs: ownerUIDs, completion: completion)
                        return
                    }
                    completion(.success(latest))
                }
            }
        }
    }

    /// Convenience: download bytes for the newest scene
    static func loadMostRecentSceneData(completion: @escaping (Result<(id: String, data: Data), Error>) -> Void) {
        fetchMostRecentSceneMeta { metaResult in
            switch metaResult {
            case .failure(let e):
                completion(.failure(e))
            case .success(let meta):
                guard let meta else {
                    completion(.failure(CloudSceneError.downloadFailed("No scenes found for this user.")))
                    return
                }
                if !meta.storagePath.isEmpty {
                    load(storagePath: meta.storagePath) { dataResult in
                        switch dataResult {
                        case .success(let data):
                            completion(.success((id: meta.id, data: data)))
                        case .failure(let e):
                            completion(.failure(e))
                        }
                    }
                    return
                }

                load(sceneId: meta.id) { dataResult in
                    switch dataResult {
                    case .success(let data):
                        completion(.success((id: meta.id, data: data)))
                    case .failure(let e):
                        completion(.failure(e))
                    }
                }
            }
        }
    }

    /// Convenience: download bytes for the newest scene visible to current user.
    static func loadMostRecentAccessibleSceneData(
        completion: @escaping (Result<(id: String, storagePath: String, data: Data), Error>) -> Void
    ) {
        fetchMostRecentAccessibleSceneMeta { metaResult in
            switch metaResult {
            case .failure(let e):
                completion(.failure(e))
            case .success(let meta):
                guard let meta else {
                    completion(.failure(CloudSceneError.downloadFailed("No scenes found.")))
                    return
                }
                load(storagePath: meta.storagePath) { dataResult in
                    switch dataResult {
                    case .success(let data):
                        completion(.success((id: meta.id, storagePath: meta.storagePath, data: data)))
                    case .failure(let e):
                        completion(.failure(e))
                    }
                }
            }
        }
    }
}

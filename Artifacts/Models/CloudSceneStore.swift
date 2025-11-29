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
    


    static func load(sceneId: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return completion(.failure(CloudSceneError.noUser)) }
        ref(uid: uid, sceneId: sceneId).getData(maxSize: 20 * 1024 * 1024) { data, err in
            if let err = err { completion(.failure(CloudSceneError.downloadFailed(err.localizedDescription))) }
            else if let data = data { completion(.success(data)) }
        }
    }
}

struct CloudSceneMeta {
    let id: String
    let name: String
    let storagePath: String
    let updatedAt: Date
    let bytes: Int
}

extension CloudSceneStore {
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

                let data = doc.data()
                let name = data["name"] as? String ?? "Untitled"
                let storagePath = data["storagePath"] as? String ?? ""
                let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                let bytes = data["bytes"] as? Int ?? 0

                completion(.success(CloudSceneMeta(id: doc.documentID,
                                                   name: name,
                                                   storagePath: storagePath,
                                                   updatedAt: ts,
                                                   bytes: bytes)))
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
                // now download by id using existing load(:)
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

    /// Fetch all scenes for the current user, sorted by updatedAt desc (bounded by `limit`)
    static func fetchAllSceneMeta(limit: Int = 10, completion: @escaping (Result<[CloudSceneMeta], Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.success([]))
        }

        db.collection("scenes")
            .whereField("ownerUid", isEqualTo: uid)
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)
            .getDocuments { snap, err in
                if let err = err { return completion(.failure(err)) }

                let metas: [CloudSceneMeta] = snap?.documents.compactMap { doc in
                    let data = doc.data()
                    let name = data["name"] as? String ?? "Untitled"
                    let storagePath = data["storagePath"] as? String ?? ""
                    let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    let bytes = data["bytes"] as? Int ?? 0

                    return CloudSceneMeta(id: doc.documentID,
                                          name: name,
                                          storagePath: storagePath,
                                          updatedAt: ts,
                                          bytes: bytes)
                } ?? []

                completion(.success(metas))
            }
    }
}

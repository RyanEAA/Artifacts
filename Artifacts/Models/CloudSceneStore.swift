// //
// //  CloudSceneStore.swift
// //  ARTutorial
// //
// //  Created by Ryan Aparicio on 10/28/25.
// //

// import Foundation
// import Firebase
// import FirebaseStorage
// import FirebaseFirestore
// import FirebaseAuth

// enum CloudSceneError: Error { case noUser, uploadFailed(String), downloadFailed(String) }

// final class CloudSceneStore {
//     static let storage = Storage.storage()
//     static let db = Firestore.firestore()

//     private static func ref(uid: String, sceneId: String) -> StorageReference {
//         storage.reference(withPath: "users/\(uid)/scenes/\(sceneId).worldmap")
//     }

//     static func save(
//         data: Data,
//         sceneId: String = UUID().uuidString,
//         name: String = "My Scene",
//         completion: @escaping (Result<String, Error>) -> Void
//     ) {
//         // Ensure a user exists (required for security rules)
//         guard let uid = Auth.auth().currentUser?.uid else {
//             print("❌ No Firebase user signed in.")
//             return completion(.failure(CloudSceneError.noUser))
//         }

//         // Reference in Storage
//         let ref = self.ref(uid: uid, sceneId: sceneId)
//         let metadata = StorageMetadata()
//         metadata.contentType = "application/octet-stream"

//         print("📤 Uploading scene \(sceneId) to Firebase Storage...")

//         // Upload data
//         ref.putData(data, metadata: metadata) { _, uploadError in
//             if let uploadError = uploadError {
//                 print("❌ Upload failed:", uploadError.localizedDescription)
//                 return completion(.failure(CloudSceneError.uploadFailed(uploadError.localizedDescription)))
//             }

//             print("✅ Upload complete. Writing Firestore metadata...")

//             // Metadata for Firestore
//             let doc: [String: Any] = [
//                 "ownerUid": uid,
//                 "name": name,
//                 "storagePath": ref.fullPath,
//                 "updatedAt": Timestamp(date: Date()),
//                 "bytes": data.count
//             ]

//             // Write to Firestore
//             self.db.collection("scenes").document(sceneId).setData(doc, merge: true) { error in
//                 if let error = error {
//                     print("❌ Firestore write failed:", error.localizedDescription)
//                     completion(.failure(error))
//                 } else {
//                     print("✅ Firestore entry created for scene:", sceneId)
//                     completion(.success(sceneId))
//                 }
//             }
//         }
//     }
    


//     static func load(sceneId: String, completion: @escaping (Result<Data, Error>) -> Void) {
//         guard let uid = Auth.auth().currentUser?.uid else { return completion(.failure(CloudSceneError.noUser)) }
//         ref(uid: uid, sceneId: sceneId).getData(maxSize: 20 * 1024 * 1024) { data, err in
//             if let err = err { completion(.failure(CloudSceneError.downloadFailed(err.localizedDescription))) }
//             else if let data = data { completion(.success(data)) }
//         }
//     }
// }

// struct CloudSceneMeta {
//     let id: String
//     let name: String
//     let storagePath: String
//     let updatedAt: Date
//     let bytes: Int
// }

// extension CloudSceneStore {
//     /// Firestore query: most recent scene owned by current user
//     static func fetchMostRecentSceneMeta(completion: @escaping (Result<CloudSceneMeta?, Error>) -> Void) {
//         guard let uid = Auth.auth().currentUser?.uid else {
//             return completion(.success(nil)) // not signed in yet; treat as "no scene"
//         }

//         db.collection("scenes")
//             .whereField("ownerUid", isEqualTo: uid)
//             .order(by: "updatedAt", descending: true)
//             .limit(to: 1)
//             .getDocuments { snap, err in
//                 if let err = err { return completion(.failure(err)) }
//                 guard let doc = snap?.documents.first else { return completion(.success(nil)) }

//                 let data = doc.data()
//                 let name = data["name"] as? String ?? "Untitled"
//                 let storagePath = data["storagePath"] as? String ?? ""
//                 let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
//                 let bytes = data["bytes"] as? Int ?? 0

//                 completion(.success(CloudSceneMeta(id: doc.documentID,
//                                                    name: name,
//                                                    storagePath: storagePath,
//                                                    updatedAt: ts,
//                                                    bytes: bytes)))
//             }
//     }

//     /// Convenience: download bytes for the newest scene
//     static func loadMostRecentSceneData(completion: @escaping (Result<(id: String, data: Data), Error>) -> Void) {
//         fetchMostRecentSceneMeta { metaResult in
//             switch metaResult {
//             case .failure(let e):
//                 completion(.failure(e))
//             case .success(let meta):
//                 guard let meta else {
//                     completion(.failure(CloudSceneError.downloadFailed("No scenes found for this user.")))
//                     return
//                 }
//                 // now download by id using existing load(:)
//                 load(sceneId: meta.id) { dataResult in
//                     switch dataResult {
//                     case .success(let data):
//                         completion(.success((id: meta.id, data: data)))
//                     case .failure(let e):
//                         completion(.failure(e))
//                     }
//                 }
//             }
//         }
//     }
// }





//
//  CloudSceneStore.swift
//  ARTutorial
//

import Foundation
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import simd

enum CloudSceneError: Error {
    case noUser
    case uploadFailed(String)
    case downloadFailed(String)
}

// MARK: - Artifact Model

struct CloudArtifact {
    let id: String
    let type: String
    let modelName: String?
    let annotationText: String?
    let transform: float4x4
}

// MARK: - Scene Meta

struct CloudSceneMeta {
    let id: String
    let name: String
    let storagePath: String
    let updatedAt: Date
    let bytes: Int
}

// MARK: - CloudSceneStore

final class CloudSceneStore {
    
    static let storage = Storage.storage()
    static let db = Firestore.firestore()
    
    // MARK: - Storage Reference
    
    private static func ref(uid: String, sceneId: String) -> StorageReference {
        storage.reference(withPath: "users/\(uid)/scenes/\(sceneId).worldmap")
    }
    
    // MARK: - Save Scene (WorldMap Only)
    
    static func save(
        data: Data,
        sceneId: String = UUID().uuidString,
        name: String = "My Scene",
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.failure(CloudSceneError.noUser))
        }
        
        let ref = self.ref(uid: uid, sceneId: sceneId)
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        
        ref.putData(data, metadata: metadata) { _, uploadError in
            if let uploadError = uploadError {
                return completion(.failure(
                    CloudSceneError.uploadFailed(uploadError.localizedDescription)
                ))
            }
            
            let doc: [String: Any] = [
                "ownerUid": uid,
                "name": name,
                "storagePath": ref.fullPath,
                "updatedAt": Timestamp(date: Date()),
                "bytes": data.count
            ]
            
            db.collection("scenes").document(sceneId).setData(doc, merge: true) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(sceneId))
                }
            }
        }
    }
    
    // MARK: - Load WorldMap
    
    static func load(sceneId: String,
                     completion: @escaping (Result<Data, Error>) -> Void) {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.failure(CloudSceneError.noUser))
        }
        
        ref(uid: uid, sceneId: sceneId)
            .getData(maxSize: 20 * 1024 * 1024) { data, err in
                
                if let err = err {
                    completion(.failure(
                        CloudSceneError.downloadFailed(err.localizedDescription)
                    ))
                } else if let data = data {
                    completion(.success(data))
                }
            }
    }
    
    // MARK: - Fetch Artifacts (One-Time)
    
    static func fetchArtifacts(
        sceneId: String,
        completion: @escaping (Result<[CloudArtifact], Error>) -> Void
    ) {
        db.collection("Artifacts")
            .whereField("sceneId", isEqualTo: sceneId)
            .getDocuments { snapshot, error in
                
                if let error = error {
                    return completion(.failure(error))
                }
                
                guard let documents = snapshot?.documents else {
                    return completion(.success([]))
                }
                
                let artifacts = documents.compactMap { doc -> CloudArtifact? in
                    let data = doc.data()
                    
                    let type = data["type"] as? String ?? ""
                    let modelName = data["modelName"] as? String
                    let annotationText = data["annotationText"] as? String
                    let transformArray = data["transform"] as? [Float] ?? []
                    
                    guard let matrix = float4x4(from: transformArray) else {
                        return nil
                    }
                    
                    return CloudArtifact(
                        id: doc.documentID,
                        type: type,
                        modelName: modelName,
                        annotationText: annotationText,
                        transform: matrix
                    )
                }
                
                completion(.success(artifacts))
            }
    }
    
    // MARK: - Live Artifact Listener (Admin Updates Reflect Instantly)
    
    static func listenToArtifacts(
        sceneId: String,
        onUpdate: @escaping ([CloudArtifact]) -> Void
    ) -> ListenerRegistration {
        
        return db.collection("Artifacts")
            .whereField("sceneId", isEqualTo: sceneId)
            .addSnapshotListener { snapshot, error in
                
                guard let documents = snapshot?.documents else {
                    onUpdate([])
                    return
                }
                
                let artifacts = documents.compactMap { doc -> CloudArtifact? in
                    let data = doc.data()
                    
                    let type = data["type"] as? String ?? ""
                    let modelName = data["modelName"] as? String
                    let annotationText = data["annotationText"] as? String
                    let transformArray = data["transform"] as? [Float] ?? []
                    
                    guard let matrix = float4x4(from: transformArray) else {
                        return nil
                    }
                    
                    return CloudArtifact(
                        id: doc.documentID,
                        type: type,
                        modelName: modelName,
                        annotationText: annotationText,
                        transform: matrix
                    )
                }
                
                onUpdate(artifacts)
            }
    }
    
    // MARK: - Load Scene + Artifacts Together
    
    static func loadSceneWithArtifacts(
        sceneId: String,
        completion: @escaping (Result<(Data, [CloudArtifact]), Error>) -> Void
    ) {
        load(sceneId: sceneId) { worldMapResult in
            
            switch worldMapResult {
            case .failure(let error):
                completion(.failure(error))
                
            case .success(let worldMapData):
                
                fetchArtifacts(sceneId: sceneId) { artifactsResult in
                    switch artifactsResult {
                    case .failure(let error):
                        completion(.failure(error))
                        
                    case .success(let artifacts):
                        completion(.success((worldMapData, artifacts)))
                    }
                }
            }
        }
    }
}

// MARK: - Matrix Conversion Helpers

extension float4x4 {
    
    init?(from array: [Float]) {
        guard array.count == 16 else { return nil }
        
        self.init(columns: (
            SIMD4(array[0], array[1], array[2], array[3]),
            SIMD4(array[4], array[5], array[6], array[7]),
            SIMD4(array[8], array[9], array[10], array[11]),
            SIMD4(array[12], array[13], array[14], array[15])
        ))
    }
    
    func toArray() -> [Float] {
        return [
            columns.0.x, columns.0.y, columns.0.z, columns.0.w,
            columns.1.x, columns.1.y, columns.1.z, columns.1.w,
            columns.2.x, columns.2.y, columns.2.z, columns.2.w,
            columns.3.x, columns.3.y, columns.3.z, columns.3.w
        ]
    }
}

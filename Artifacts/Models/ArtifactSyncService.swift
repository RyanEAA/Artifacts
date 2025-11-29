//
//  ArtifactSyncService.swift
//  Artifacts
//
//  Created for automatic artifact syncing with Firebase
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import ARKit
import simd

enum ArtifactType: String, Codable {
    case model
    case annotation
}

struct ArtifactData: Codable {
    let id: String
    let type: ArtifactType
    let sceneId: String
    let ownerUid: String
    let createdAt: Date
    var updatedAt: Date
    
    // Model-specific fields
    var modelName: String?
    var transform: [Float]? // 16-element array representing simd_float4x4
    
    // Annotation-specific fields
    var annotationText: String?
    
    // Common position (for easier querying)
    var position: [Float]? // [x, y, z]
}

extension ArtifactData {
    // Convert simd_float4x4 to array
    static func transformToArray(_ transform: simd_float4x4) -> [Float] {
        return [
            transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
            transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
            transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
        ]
    }
    
    // Convert array to simd_float4x4
    static func arrayToTransform(_ array: [Float]) -> simd_float4x4? {
        guard array.count == 16 else { return nil }
        return simd_float4x4(
            SIMD4<Float>(array[0], array[1], array[2], array[3]),
            SIMD4<Float>(array[4], array[5], array[6], array[7]),
            SIMD4<Float>(array[8], array[9], array[10], array[11]),
            SIMD4<Float>(array[12], array[13], array[14], array[15])
        )
    }
}

class ArtifactSyncService {
    static let shared = ArtifactSyncService()
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    private init() {}
    
    // MARK: - Save Artifact
    
    func saveArtifact(
        id: String,
        type: ArtifactType,
        sceneId: String,
        transform: simd_float4x4,
        modelName: String? = nil,
        annotationText: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.failure(NSError(domain: "ArtifactSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])))
        }
        
        let position = [transform.columns.3.x, transform.columns.3.y, transform.columns.3.z]
        let transformArray = ArtifactData.transformToArray(transform)
        
        let artifact = ArtifactData(
            id: id,
            type: type,
            sceneId: sceneId,
            ownerUid: uid,
            createdAt: Date(),
            updatedAt: Date(),
            modelName: modelName,
            transform: transformArray,
            annotationText: annotationText,
            position: position
        )
        
        do {
            let data = try Firestore.Encoder().encode(artifact)
            db.collection("artifacts").document(id).setData(data, merge: true) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    print("✅ Artifact saved: \(id) in scene: \(sceneId)")
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Update Artifact
    
    func updateArtifact(
        id: String,
        transform: simd_float4x4? = nil,
        annotationText: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.failure(NSError(domain: "ArtifactSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])))
        }
        
        var updateData: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let transform = transform {
            updateData["transform"] = ArtifactData.transformToArray(transform)
            updateData["position"] = [transform.columns.3.x, transform.columns.3.y, transform.columns.3.z]
        }
        
        if let text = annotationText {
            updateData["annotationText"] = text
        }
        
        db.collection("artifacts").document(id).updateData(updateData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Artifact updated: \(id)")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Delete Artifact
    
    func deleteArtifact(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("artifacts").document(id).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Artifact deleted: \(id)")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToScene(sceneId: String, onUpdate: @escaping ([ArtifactData]) -> Void, onError: @escaping (Error) -> Void) {
        // Remove existing listener for this scene
        stopListeningToScene(sceneId: sceneId)
        
        let listener = db.collection("artifacts")
            .whereField("sceneId", isEqualTo: sceneId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onError(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    onUpdate([])
                    return
                }
                
                let artifacts = documents.compactMap { doc -> ArtifactData? in
                    do {
                        return try Firestore.Decoder().decode(ArtifactData.self, from: doc.data())
                    } catch {
                        print("❌ Error decoding artifact \(doc.documentID): \(error)")
                        return nil
                    }
                }
                
                onUpdate(artifacts)
            }
        
        listeners[sceneId] = listener
        print("👂 Started listening to scene: \(sceneId)")
    }
    
    func stopListeningToScene(sceneId: String) {
        listeners[sceneId]?.remove()
        listeners.removeValue(forKey: sceneId)
        print("🔇 Stopped listening to scene: \(sceneId)")
    }
    
    func stopAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Load Scene Artifacts (one-time fetch)
    
    func loadSceneArtifacts(sceneId: String, completion: @escaping (Result<[ArtifactData], Error>) -> Void) {
        db.collection("artifacts")
            .whereField("sceneId", isEqualTo: sceneId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let artifacts = documents.compactMap { doc -> ArtifactData? in
                    do {
                        return try Firestore.Decoder().decode(ArtifactData.self, from: doc.data())
                    } catch {
                        print("❌ Error decoding artifact \(doc.documentID): \(error)")
                        return nil
                    }
                }
                
                completion(.success(artifacts))
            }
    }
}



//
//  ArtifactsService.swift
//  Artifacts
//
//  Created by Swapnil Puri on 2/18/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import simd

struct ArtifactMapItem: Identifiable, Equatable {
    let id: String
    let title: String
    let ownerUid: String
    let sceneId: String
    let coordinate: CLLocationCoordinate2D
    let createdAt: Date

    static func == (lhs: ArtifactMapItem, rhs: ArtifactMapItem) -> Bool {
        lhs.id == rhs.id
    }
}

final class ArtifactsService {

    static let shared = ArtifactsService()

    private let db = Firestore.firestore()

    private init() {}

    func listenMyArtifacts(completion: @escaping ([ArtifactMapItem]) -> Void) throws -> ListenerRegistration {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return db.collection("artifacts").addSnapshotListener { _, _ in }
        }

        return db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("⚠️ listenMyArtifacts error:", error.localizedDescription)
                    completion([])
                    return
                }

                let docs = snapshot?.documents ?? []
                let items: [ArtifactMapItem] = docs.compactMap { doc in
                    Self.decodeArtifact(docId: doc.documentID, data: doc.data())
                }
                .sorted { $0.createdAt > $1.createdAt }

                completion(items)
            }
    }

    // MARK: Create

    func createAnnotationArtifact(
        artifactId: String,
        annotationText: String,
        sceneId: String,
        transform: simd_float4x4
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }

        let position = Self.positionArray(from: transform)
        let transformArray = Self.transformArray(from: transform)

        let doc: [String: Any] = [
            "id": artifactId,
            "ownerUid": uid,
            "sceneId": sceneId,
            "type": "annotation",
            "annotationText": annotationText,
            "position": position,
            "transform": transformArray,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("artifacts").document(artifactId).setData(doc, merge: true)
    }

    func updateAnnotationText(
        artifactId: String,
        annotationText: String
    ) async throws {
        let patch: [String: Any] = [
            "annotationText": annotationText,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("artifacts").document(artifactId).setData(patch, merge: true)
    }

    func createModelArtifact(
        artifactId: String,
        modelName: String,
        sceneId: String,
        transform: simd_float4x4
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }

        let position = Self.positionArray(from: transform)
        let transformArray = Self.transformArray(from: transform)

        let doc: [String: Any] = [
            "id": artifactId,
            "ownerUid": uid,
            "sceneId": sceneId,
            "type": "model",
            "modelName": modelName,
            "position": position,
            "transform": transformArray,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("artifacts").document(artifactId).setData(doc, merge: true)
    }

    // MARK: Helpers

    private static func positionArray(from transform: simd_float4x4) -> [Double] {
        [
            Double(transform.columns.3.x),
            Double(transform.columns.3.y),
            Double(transform.columns.3.z)
        ]
    }

    private static func transformArray(from transform: simd_float4x4) -> [Double] {
        [
            Double(transform.columns.0.x), Double(transform.columns.0.y), Double(transform.columns.0.z), Double(transform.columns.0.w),
            Double(transform.columns.1.x), Double(transform.columns.1.y), Double(transform.columns.1.z), Double(transform.columns.1.w),
            Double(transform.columns.2.x), Double(transform.columns.2.y), Double(transform.columns.2.z), Double(transform.columns.2.w),
            Double(transform.columns.3.x), Double(transform.columns.3.y), Double(transform.columns.3.z), Double(transform.columns.3.w)
        ]
    }

    private static func decodeArtifact(docId: String, data: [String: Any]) -> ArtifactMapItem? {
        let ownerUid = data["ownerUid"] as? String ?? ""
        let sceneId = data["sceneId"] as? String ?? ""
        let title = data["title"] as? String
            ?? data["name"] as? String
            ?? data["label"] as? String
            ?? data["modelName"] as? String
            ?? "Artifact"

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            ?? (data["updatedAt"] as? Timestamp)?.dateValue()
            ?? Date.distantPast

        if let gp = data["location"] as? GeoPoint {
            return ArtifactMapItem(
                id: docId,
                title: title,
                ownerUid: ownerUid,
                sceneId: sceneId,
                coordinate: CLLocationCoordinate2D(latitude: gp.latitude, longitude: gp.longitude),
                createdAt: createdAt
            )
        }

        if let gp = data["coordinate"] as? GeoPoint {
            return ArtifactMapItem(
                id: docId,
                title: title,
                ownerUid: ownerUid,
                sceneId: sceneId,
                coordinate: CLLocationCoordinate2D(latitude: gp.latitude, longitude: gp.longitude),
                createdAt: createdAt
            )
        }

        if let lat = data["latitude"] as? CLLocationDegrees,
           let lon = data["longitude"] as? CLLocationDegrees {
            return ArtifactMapItem(
                id: docId,
                title: title,
                ownerUid: ownerUid,
                sceneId: sceneId,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                createdAt: createdAt
            )
        }

        if let lat = data["lat"] as? CLLocationDegrees,
           let lon = data["lng"] as? CLLocationDegrees {
            return ArtifactMapItem(
                id: docId,
                title: title,
                ownerUid: ownerUid,
                sceneId: sceneId,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                createdAt: createdAt
            )
        }

        return nil
    }
}

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
    private let db = Firestore.firestore()

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

    private static func decodeArtifact(docId: String, data: [String: Any]) -> ArtifactMapItem? {
        let ownerUid = data["ownerUid"] as? String ?? ""
        let sceneId = data["sceneId"] as? String ?? ""
        let title = data["title"] as? String
            ?? data["name"] as? String
            ?? data["label"] as? String
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

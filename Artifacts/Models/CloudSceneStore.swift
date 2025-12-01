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
import CoreLocation

enum CloudSceneError: Error { case noUser, uploadFailed(String), downloadFailed(String) }

struct SceneLocationMeta {
    let coordinate: CLLocationCoordinate2D
    let altitude: Double?
    let horizontalAccuracy: Double?
    let heading: Double?
}

final class CloudSceneStore {
    static let storage = Storage.storage()
    static let db = Firestore.firestore()

    private static func ref(uid: String, sceneId: String) -> StorageReference {
        storage.reference(withPath: "users/\(uid)/scenes/\(sceneId).worldmap")
    }

    private static func ref(storagePath: String) -> StorageReference {
        storage.reference(withPath: storagePath)
    }

    /// Ensure a scene document exists for a given ID so that artifact writes pass security rules.
    static func ensureSceneDocument(
        sceneId: String,
        name: String = "Scene",
        location: SceneLocationMeta? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.failure(CloudSceneError.noUser))
        }

        var doc: [String: Any] = [
            "ownerUid": uid,
            "name": name,
            "updatedAt": Timestamp(date: Date())
        ]

        if let loc = location {
            doc["lat"] = loc.coordinate.latitude
            doc["lon"] = loc.coordinate.longitude
            doc["alt"] = loc.altitude
            doc["hAcc"] = loc.horizontalAccuracy
            doc["heading"] = loc.heading
        }

        db.collection("scenes").document(sceneId).setData(doc, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    static func save(
        data: Data,
        sceneId: String = UUID().uuidString,
        name: String = "My Scene",
        location: SceneLocationMeta? = nil,
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
        var mutableDoc = doc
        if let loc = location {
            mutableDoc["lat"] = loc.coordinate.latitude
            mutableDoc["lon"] = loc.coordinate.longitude
            mutableDoc["alt"] = loc.altitude
            mutableDoc["hAcc"] = loc.horizontalAccuracy
            mutableDoc["heading"] = loc.heading
        }

        // Write to Firestore
        self.db.collection("scenes").document(sceneId).setData(mutableDoc, merge: true) { error in
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
        db.collection("scenes").document(sceneId).getDocument { snapshot, err in
            if let err = err {
                return completion(.failure(CloudSceneError.downloadFailed(err.localizedDescription)))
            }
            guard let data = snapshot?.data(),
                  let storagePath = data["storagePath"] as? String else {
                return completion(.failure(CloudSceneError.downloadFailed("Scene metadata missing or invalid.")))
            }

            ref(storagePath: storagePath).getData(maxSize: 20 * 1024 * 1024) { data, downloadError in
                if let downloadError = downloadError {
                    completion(.failure(CloudSceneError.downloadFailed(downloadError.localizedDescription)))
                } else if let data = data {
                    completion(.success(data))
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
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let horizontalAccuracy: Double?
    let heading: Double?
    var distanceFromQueryMeters: Double?
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
                let lat = data["lat"] as? Double
                let lon = data["lon"] as? Double
                let alt = data["alt"] as? Double
                let hAcc = data["hAcc"] as? Double
                let heading = data["heading"] as? Double

                completion(.success(CloudSceneMeta(id: doc.documentID,
                                                   name: name,
                                                   storagePath: storagePath,
                                                   updatedAt: ts,
                                                   bytes: bytes,
                                                   latitude: lat,
                                                   longitude: lon,
                                                   altitude: alt,
                                                   horizontalAccuracy: hAcc,
                                                   heading: heading,
                                                   distanceFromQueryMeters: nil)))
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

    /// Fetch scenes for the current user inside a lat/lon bounding box (client will refine by distance).
    static func fetchNearbySceneMeta(
        center: CLLocationCoordinate2D,
        radiusMeters: Double = 150,
        limit: Int = 10,
        completion: @escaping (Result<[CloudSceneMeta], Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(.success([]))
        }

        let bounds = boundingBox(for: center, radiusMeters: radiusMeters)

        var query: Query = db.collection("scenes")
            .whereField("ownerUid", isEqualTo: uid)
            .whereField("lat", isGreaterThan: bounds.minLat)
            .whereField("lat", isLessThan: bounds.maxLat)
            .whereField("lon", isGreaterThan: bounds.minLon)
            .whereField("lon", isLessThan: bounds.maxLon)
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)

        query.getDocuments { snap, err in
            if let err = err { return completion(.failure(err)) }

            let metas: [CloudSceneMeta] = snap?.documents.compactMap { doc in
                let data = doc.data()
                guard let lat = data["lat"] as? Double,
                      let lon = data["lon"] as? Double else {
                    return nil // skip scenes without coordinates in a geo-filtered query
                }
                let name = data["name"] as? String ?? "Untitled"
                let storagePath = data["storagePath"] as? String ?? ""
                let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                let bytes = data["bytes"] as? Int ?? 0
                let alt = data["alt"] as? Double
                let hAcc = data["hAcc"] as? Double
                let heading = data["heading"] as? Double
                let distance = Self.haversineDistanceMeters(from: center, to: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                return CloudSceneMeta(id: doc.documentID,
                                      name: name,
                                      storagePath: storagePath,
                                      updatedAt: ts,
                                      bytes: bytes,
                                      latitude: lat,
                                      longitude: lon,
                                      altitude: alt,
                                      horizontalAccuracy: hAcc,
                                      heading: heading,
                                      distanceFromQueryMeters: distance)
            } ?? []

            // Sort by distance first, then recency
            let sorted = metas.sorted { lhs, rhs in
                if let dl = lhs.distanceFromQueryMeters, let dr = rhs.distanceFromQueryMeters {
                    if abs(dl - dr) > 1 {
                        return dl < dr
                    }
                }
                return lhs.updatedAt > rhs.updatedAt
            }

            completion(.success(sorted))
        }
    }

    private static func boundingBox(for center: CLLocationCoordinate2D, radiusMeters: Double) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let earthRadius = 6_371_000.0
        let deltaLat = (radiusMeters / earthRadius) * (180.0 / .pi)
        let deltaLon = (radiusMeters / (earthRadius * cos(center.latitude * .pi / 180.0))) * (180.0 / .pi)
        return (center.latitude - deltaLat, center.latitude + deltaLat, center.longitude - deltaLon, center.longitude + deltaLon)
    }

    private static func haversineDistanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    /// Fetch all scenes with an optional owner filter (used as a fallback when no location).
    static func fetchAllSceneMeta(limit: Int = 10, onlyCurrentUser: Bool = false, completion: @escaping (Result<[CloudSceneMeta], Error>) -> Void) {
        var query: Query = db.collection("scenes")
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)

        if onlyCurrentUser, let uid = Auth.auth().currentUser?.uid {
            query = query.whereField("ownerUid", isEqualTo: uid)
        }

        query.getDocuments { snap, err in
            if let err = err { return completion(.failure(err)) }

            let metas: [CloudSceneMeta] = snap?.documents.compactMap { doc in
                let data = doc.data()
                let name = data["name"] as? String ?? "Untitled"
                let storagePath = data["storagePath"] as? String ?? ""
                let ts = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                let bytes = data["bytes"] as? Int ?? 0
                let lat = data["lat"] as? Double
                let lon = data["lon"] as? Double
                let alt = data["alt"] as? Double
                let hAcc = data["hAcc"] as? Double
                let heading = data["heading"] as? Double

                return CloudSceneMeta(id: doc.documentID,
                                      name: name,
                                      storagePath: storagePath,
                                      updatedAt: ts,
                                      bytes: bytes,
                                      latitude: lat,
                                      longitude: lon,
                                      altitude: alt,
                                      horizontalAccuracy: hAcc,
                                      heading: heading,
                                      distanceFromQueryMeters: nil)
            } ?? []

            completion(.success(metas))
        }
    }
}

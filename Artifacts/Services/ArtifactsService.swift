//
//  ArtifactsService.swift
//  Artifacts
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

struct DrawingArtifactRecord {
    let artifactId: String
    let points: [SIMD3<Float>]
    let colorRGBA: SIMD4<Float>
    let brushSize: Float
}

struct ModelArtifactRecord {
    let artifactId: String
    let modelName: String
    let transform: simd_float4x4
}

struct AnnotationArtifactRecord {
    let artifactId: String
    let annotationText: String
    let transform: simd_float4x4
}

final class ArtifactsService {

    static let shared = ArtifactsService()

    private let db = Firestore.firestore()

    private init() {}

    private final class CompositeListener: NSObject, ListenerRegistration {
        private var registrations: [ListenerRegistration]
        private let lock = NSLock()

        init(_ registrations: [ListenerRegistration]) {
            self.registrations = registrations
        }

        func remove() {
            lock.lock()
            let current = registrations
            registrations.removeAll()
            lock.unlock()
            current.forEach { $0.remove() }
        }

        func replace(with next: [ListenerRegistration]) {
            lock.lock()
            let current = registrations
            registrations = next
            lock.unlock()
            current.forEach { $0.remove() }
        }
    }

    // MARK: - Profile Queries

    func listenMyPublishedArtifacts(completion: @escaping ([ArtifactMapItem]) -> Void) throws -> ListenerRegistration {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return db.collection("artifacts").addSnapshotListener { _, _ in }
        }

        return db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("⚠️ listenMyPublishedArtifacts error:", error.localizedDescription)
                    completion([])
                    return
                }

                let docs = snapshot?.documents ?? []
                let items: [ArtifactMapItem] = docs
                    .filter { doc in
                        let published = doc.data()["published"] as? Bool
                        return published != false
                    }
                    .compactMap { doc in
                        Self.decodeArtifact(docId: doc.documentID, data: doc.data())
                    }
                    .sorted { $0.createdAt > $1.createdAt }

                completion(items)
            }
    }

    func listenPublishedArtifacts(
        forOwnerUIDs ownerUIDs: [String],
        completion: @escaping ([ArtifactMapItem]) -> Void
    ) -> ListenerRegistration {
        let normalized = Array(Set(ownerUIDs.filter { !$0.isEmpty })).sorted()
        guard !normalized.isEmpty else {
            completion([])
            return db.collection("artifacts").addSnapshotListener { _, _ in }
        }

        let chunks = Self.chunked(normalized, size: 10)
        var byChunk: [[String: ArtifactMapItem]] = Array(repeating: [:], count: chunks.count)
        let syncQueue = DispatchQueue(label: "ArtifactsService.listenPublishedArtifacts.sync")

        let regs: [ListenerRegistration] = chunks.enumerated().map { index, chunk in
            db.collection("artifacts")
                .whereField("ownerUid", in: chunk)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("⚠️ listenPublishedArtifacts error:", error.localizedDescription)
                        syncQueue.sync {
                            byChunk[index] = [:]
                            completion(Self.mergeAndSort(byChunk))
                        }
                        return
                    }

                    let docs = snapshot?.documents ?? []
                    let mapped: [String: ArtifactMapItem] = Dictionary(
                        uniqueKeysWithValues: docs.compactMap { doc -> (String, ArtifactMapItem)? in
                            let data = doc.data()
                            let published = data["published"] as? Bool
                            guard published != false else { return nil }
                            guard let item = Self.decodeArtifact(docId: doc.documentID, data: data) else { return nil }
                            return (item.id, item)
                        }
                    )

                    syncQueue.sync {
                        byChunk[index] = mapped
                        completion(Self.mergeAndSort(byChunk))
                    }
                }
        }

        return CompositeListener(regs)
    }

    /// Loads current user's published artifacts independently, then merges friend artifacts.
    /// This avoids security-rule failures on friend queries from suppressing the user's own map data.
    func listenMyAndFriendsPublishedArtifacts(
        friendUIDs: [String],
        completion: @escaping ([ArtifactMapItem]) -> Void
    ) -> ListenerRegistration {
        guard let myUID = Auth.auth().currentUser?.uid else {
            completion([])
            return db.collection("artifacts").addSnapshotListener { _, _ in }
        }

        let normalizedFriends = Array(
            Set(
                friendUIDs
                    .filter { !$0.isEmpty }
                    .filter { $0 != myUID }
            )
        ).sorted()

        var myItemsById: [String: ArtifactMapItem] = [:]
        var friendItemsByUID: [String: [String: ArtifactMapItem]] = [:]
        let syncQueue = DispatchQueue(label: "ArtifactsService.listenMyAndFriendsPublishedArtifacts.sync")

        func emitMerged() {
            let friendBuckets = Array(friendItemsByUID.values)
            completion(Self.mergeAndSort([myItemsById] + friendBuckets))
        }

        let myReg = db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: myUID)
            .addSnapshotListener { snapshot, error in
                syncQueue.sync {
                    if let error {
                        print("⚠️ listenMyAndFriendsPublishedArtifacts (mine) error:", error.localizedDescription)
                        myItemsById = [:]
                        emitMerged()
                        return
                    }

                    let docs = snapshot?.documents ?? []
                    myItemsById = Dictionary(
                        uniqueKeysWithValues: docs.compactMap { doc -> (String, ArtifactMapItem)? in
                            let data = doc.data()
                            let published = data["published"] as? Bool
                            guard published != false else { return nil }
                            guard let item = Self.decodeArtifact(docId: doc.documentID, data: data) else { return nil }
                            return (item.id, item)
                        }
                    )
                    emitMerged()
                }
            }

        var regs: [ListenerRegistration] = [myReg]

        if !normalizedFriends.isEmpty {
            let friendRegs: [ListenerRegistration] = normalizedFriends.map { friendUID in
                db.collection("artifacts")
                    .whereField("ownerUid", isEqualTo: friendUID)
                    .addSnapshotListener { snapshot, error in
                        syncQueue.sync {
                            if let error {
                                // One failing friend query should not hide all friend markers.
                                print("⚠️ listenMyAndFriendsPublishedArtifacts (friend \(friendUID)) error:", error.localizedDescription)
                                friendItemsByUID[friendUID] = [:]
                                emitMerged()
                                return
                            }

                            let docs = snapshot?.documents ?? []
                            let mapped: [String: ArtifactMapItem] = Dictionary(
                                uniqueKeysWithValues: docs.compactMap { doc -> (String, ArtifactMapItem)? in
                                    let data = doc.data()
                                    let published = data["published"] as? Bool
                                    guard published != false else { return nil }
                                    guard let item = Self.decodeArtifact(docId: doc.documentID, data: data) else { return nil }
                                    return (item.id, item)
                                }
                            )
                            friendItemsByUID[friendUID] = mapped
                            emitMerged()
                        }
                    }
            }
            regs.append(contentsOf: friendRegs)
        }

        return CompositeListener(regs)
    }

    func publishDraftArtifacts(sceneId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return }

        let query = db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("published", isEqualTo: false)

        let snap = try await query.getDocuments()
        guard !snap.documents.isEmpty else { return }

        let batch = db.batch()
        let now = FieldValue.serverTimestamp()
        for doc in snap.documents {
            batch.updateData([
                "published": true,
                "publishedAt": now,
                "updatedAt": now
            ], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    func remapMyDraftArtifacts(fromSceneId: String, toSceneId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !fromSceneId.isEmpty, !toSceneId.isEmpty, fromSceneId != toSceneId else { return }

        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .whereField("sceneId", isEqualTo: fromSceneId)
            .whereField("published", isEqualTo: false)
            .getDocuments()

        guard !snap.documents.isEmpty else { return }

        let batch = db.batch()
        for doc in snap.documents {
            batch.updateData([
                "sceneId": toSceneId,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Annotation Text Overrides For Reload

    /// Fetch latest annotation text for the current user and scene from Firestore.
    /// This is used on scene reload to override any stale or empty anchor payload text.
    func fetchMyAnnotationTextOverrides(sceneId: String) async throws -> [String: String] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return [:] }

        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "annotation")
            .getDocuments()

        var out: [String: String] = [:]
        for doc in snap.documents {
            let text = (doc.data()["annotationText"] as? String) ?? ""
            out[doc.documentID] = text
        }
        return out
    }

    /// Fetch latest annotation text for any visible artifact in a scene (self + friends).
    func fetchVisibleAnnotationTextOverrides(sceneId: String) async throws -> [String: String] {
        guard let me = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return [:] }

        let ownerUid = try await sceneOwnerUid(for: sceneId) ?? me
        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "annotation")
            .getDocuments()

        var out: [String: String] = [:]
        for doc in snap.documents {
            let text = (doc.data()["annotationText"] as? String) ?? ""
            out[doc.documentID] = text
        }
        return out
    }

    /// Real-time listener for annotation text by scene.
    /// Returns a Firestore listener that must be retained and removed by caller.
    func listenMyAnnotationTextOverrides(
        sceneId: String,
        completion: @escaping ([String: String]) -> Void
    ) -> ListenerRegistration {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([:])
            return db.collection("artifacts").addSnapshotListener { _, _ in }
        }
        guard !sceneId.isEmpty else { return db.collection("artifacts").addSnapshotListener { _, _ in } }
        return db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "annotation")
            .addSnapshotListener(includeMetadataChanges: true) { snap, err in
                if let err {
                    print("⚠️ listenMyAnnotationTextOverrides error:", err.localizedDescription)
                    completion([:])
                    return
                }

                var out: [String: String] = [:]
                for doc in snap?.documents ?? [] {
                    let text = (doc.data()["annotationText"] as? String) ?? ""
                    out[doc.documentID] = text
                }
                completion(out)
            }
    }

    /// Real-time annotation text listener for any visible artifact in a scene (self + friends).
    func listenVisibleAnnotationTextOverrides(
        sceneId: String,
        completion: @escaping ([String: String]) -> Void
    ) -> ListenerRegistration {
        guard let me = Auth.auth().currentUser?.uid else {
            completion([:])
            return db.collection("artifacts").addSnapshotListener { _, _ in }
        }
        guard !sceneId.isEmpty else { return db.collection("artifacts").addSnapshotListener { _, _ in } }
        let holder = CompositeListener([])
        Task {
            do {
                let ownerUid = try await self.sceneOwnerUid(for: sceneId) ?? me
                let reg = self.db.collection("artifacts")
                    .whereField("ownerUid", isEqualTo: ownerUid)
                    .whereField("sceneId", isEqualTo: sceneId)
                    .whereField("type", isEqualTo: "annotation")
                    .addSnapshotListener(includeMetadataChanges: true) { snap, err in
                        if let err {
                            // Keep current UI state on transient/rules failure instead of wiping.
                            print("⚠️ listenVisibleAnnotationTextOverrides error:", err.localizedDescription)
                            return
                        }

                        var out: [String: String] = [:]
                        for doc in snap?.documents ?? [] {
                            let text = (doc.data()["annotationText"] as? String) ?? ""
                            out[doc.documentID] = text
                        }
                        completion(out)
                    }
                holder.replace(with: [reg])
            } catch {
                print("⚠️ listenVisibleAnnotationTextOverrides setup error:", error.localizedDescription)
            }
        }
        return holder
    }

    // MARK: - Create

    func createAnnotationArtifact(
        artifactId: String,
        annotationText: String,
        sceneId: String,
        transform: simd_float4x4,
        coordinate: CLLocationCoordinate2D? = nil
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }

        let position = Self.positionArray(from: transform)
        let transformArray = Self.transformArray(from: transform)

        var doc: [String: Any] = [
            "id": artifactId,
            "ownerUid": uid,
            "sceneId": sceneId,
            "type": "annotation",
            "annotationText": annotationText,
            "published": false,
            "position": position,
            "transform": transformArray,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let coordinate {
            doc["location"] = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            doc["latitude"] = coordinate.latitude
            doc["longitude"] = coordinate.longitude
        }

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
        transform: simd_float4x4,
        coordinate: CLLocationCoordinate2D? = nil
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }

        let position = Self.positionArray(from: transform)
        let transformArray = Self.transformArray(from: transform)

        var doc: [String: Any] = [
            "id": artifactId,
            "ownerUid": uid,
            "sceneId": sceneId,
            "type": "model",
            "modelName": modelName,
            "published": false,
            "position": position,
            "transform": transformArray,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let coordinate {
            doc["location"] = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            doc["latitude"] = coordinate.latitude
            doc["longitude"] = coordinate.longitude
        }

        try await db.collection("artifacts").document(artifactId).setData(doc, merge: true)
    }

    func createDrawingArtifact(
        artifactId: String,
        sceneId: String,
        points: [SIMD3<Float>],
        colorRGBA: SIMD4<Float>,
        brushSize: Float,
        coordinate: CLLocationCoordinate2D? = nil
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !points.isEmpty else { return }

        let pointMaps: [[String: Double]] = points.map { point in
            [
                "x": Double(point.x),
                "y": Double(point.y),
                "z": Double(point.z)
            ]
        }
        let colorArray = [
            Double(colorRGBA.x),
            Double(colorRGBA.y),
            Double(colorRGBA.z),
            Double(colorRGBA.w)
        ]

        var doc: [String: Any] = [
            "id": artifactId,
            "ownerUid": uid,
            "sceneId": sceneId,
            "type": "drawing",
            "drawingPoints": pointMaps,
            "drawingColorRGBA": colorArray,
            "drawingBrushSize": Double(brushSize),
            "published": false,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let coordinate {
            doc["location"] = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            doc["latitude"] = coordinate.latitude
            doc["longitude"] = coordinate.longitude
        }

        try await db.collection("artifacts").document(artifactId).setData(doc, merge: true)
    }

    func fetchMyDrawingArtifacts(sceneId: String) async throws -> [DrawingArtifactRecord] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return [] }

        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: uid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "drawing")
            .getDocuments()

        let records: [DrawingArtifactRecord] = snap.documents.compactMap { doc in
            let data = doc.data()
            let pointMaps = data["drawingPoints"] as? [[String: Double]] ?? []
            let points: [SIMD3<Float>] = pointMaps.compactMap { p in
                guard let x = p["x"], let y = p["y"], let z = p["z"] else { return nil }
                return SIMD3<Float>(Float(x), Float(y), Float(z))
            }
            guard !points.isEmpty else { return nil }

            let colorArray = data["drawingColorRGBA"] as? [Double] ?? [1, 1, 1, 1]
            let color = SIMD4<Float>(
                Float(colorArray.indices.contains(0) ? colorArray[0] : 1),
                Float(colorArray.indices.contains(1) ? colorArray[1] : 1),
                Float(colorArray.indices.contains(2) ? colorArray[2] : 1),
                Float(colorArray.indices.contains(3) ? colorArray[3] : 1)
            )
            let brush = Float(data["drawingBrushSize"] as? Double ?? 0.004)

            return DrawingArtifactRecord(
                artifactId: doc.documentID,
                points: points,
                colorRGBA: color,
                brushSize: brush
            )
        }

        return records
    }

    func fetchVisibleDrawingArtifacts(sceneId: String) async throws -> [DrawingArtifactRecord] {
        guard let me = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return [] }

        let ownerUid = try await sceneOwnerUid(for: sceneId) ?? me
        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "drawing")
            .getDocuments()

        let records: [DrawingArtifactRecord] = snap.documents.compactMap { doc in
            let data = doc.data()
            let pointMaps = data["drawingPoints"] as? [[String: Double]] ?? []
            let points: [SIMD3<Float>] = pointMaps.compactMap { p in
                guard let x = p["x"], let y = p["y"], let z = p["z"] else { return nil }
                return SIMD3<Float>(Float(x), Float(y), Float(z))
            }
            guard !points.isEmpty else { return nil }

            let colorArray = data["drawingColorRGBA"] as? [Double] ?? [1, 1, 1, 1]
            let color = SIMD4<Float>(
                Float(colorArray.indices.contains(0) ? colorArray[0] : 1),
                Float(colorArray.indices.contains(1) ? colorArray[1] : 1),
                Float(colorArray.indices.contains(2) ? colorArray[2] : 1),
                Float(colorArray.indices.contains(3) ? colorArray[3] : 1)
            )
            let brush = Float(data["drawingBrushSize"] as? Double ?? 0.004)

            return DrawingArtifactRecord(
                artifactId: doc.documentID,
                points: points,
                colorRGBA: color,
                brushSize: brush
            )
        }

        return records
    }

    func fetchVisibleModelArtifacts(sceneId: String) async throws -> [ModelArtifactRecord] {
        guard let me = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return [] }

        let ownerUid = try await sceneOwnerUid(for: sceneId) ?? me
        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "model")
            .getDocuments()

        return snap.documents.compactMap { doc in
            let data = doc.data()
            guard let modelName = data["modelName"] as? String, !modelName.isEmpty else { return nil }
            guard let transform = Self.transformMatrix(from: data["transform"]) else { return nil }
            return ModelArtifactRecord(
                artifactId: doc.documentID,
                modelName: modelName,
                transform: transform
            )
        }
    }

    func fetchVisibleAnnotationArtifacts(sceneId: String) async throws -> [AnnotationArtifactRecord] {
        guard let me = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ArtifactsService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User is not authenticated"
            ])
        }
        guard !sceneId.isEmpty else { return [] }

        let ownerUid = try await sceneOwnerUid(for: sceneId) ?? me
        let snap = try await db.collection("artifacts")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .whereField("sceneId", isEqualTo: sceneId)
            .whereField("type", isEqualTo: "annotation")
            .getDocuments()

        return snap.documents.compactMap { doc in
            let data = doc.data()
            let text = (data["annotationText"] as? String) ?? ""
            guard let transform = Self.transformMatrix(from: data["transform"]) else { return nil }
            return AnnotationArtifactRecord(
                artifactId: doc.documentID,
                annotationText: text,
                transform: transform
            )
        }
    }

    // MARK: - Helpers

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

    private static func mergeAndSort(_ byChunk: [[String: ArtifactMapItem]]) -> [ArtifactMapItem] {
        var merged: [String: ArtifactMapItem] = [:]
        for chunk in byChunk {
            for (id, item) in chunk {
                if let existing = merged[id] {
                    if item.createdAt > existing.createdAt {
                        merged[id] = item
                    }
                } else {
                    merged[id] = item
                }
            }
        }
        return merged.values.sorted { $0.createdAt > $1.createdAt }
    }

    private static func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [items] }
        var chunks: [[T]] = []
        var i = 0
        while i < items.count {
            let j = Swift.min(i + size, items.count)
            chunks.append(Array(items[i..<j]))
            i = j
        }
        return chunks
    }

    private static func transformMatrix(from raw: Any?) -> simd_float4x4? {
        guard let arr = raw as? [Double], arr.count == 16 else { return nil }
        return simd_float4x4(
            SIMD4<Float>(Float(arr[0]), Float(arr[1]), Float(arr[2]), Float(arr[3])),
            SIMD4<Float>(Float(arr[4]), Float(arr[5]), Float(arr[6]), Float(arr[7])),
            SIMD4<Float>(Float(arr[8]), Float(arr[9]), Float(arr[10]), Float(arr[11])),
            SIMD4<Float>(Float(arr[12]), Float(arr[13]), Float(arr[14]), Float(arr[15]))
        )
    }

    private func sceneOwnerUid(for sceneId: String) async throws -> String? {
        guard !sceneId.isEmpty else { return nil }
        let doc = try await db.collection("scenes").document(sceneId).getDocument()
        return doc.data()?["ownerUid"] as? String
    }
}

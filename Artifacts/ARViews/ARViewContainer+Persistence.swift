//
//  ARViewContainer+Persistence.swift
//  ARTutorial
//

import RealityKit
import ARKit
import Foundation
import FirebaseAuth

extension ARViewContainer {

    private func modelNamesInScene(from scenePersistenceData: Data) -> [String] {
        guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: ARWorldMap.self,
            from: scenePersistenceData
        ) else {
            return []
        }

        return worldMap.anchors.compactMap { anchor in
            guard let name = anchor.name, name.hasPrefix(anchorNamePrefix) else { return nil }
            return String(name.dropFirst(anchorNamePrefix.count))
        }
    }

    private func preloadModelEntities(named modelNames: [String]) {
        guard !modelNames.isEmpty else { return }
        let wanted = Set(modelNames)
        for model in self.modelsViewModel.models where wanted.contains(model.name) {
            guard model.modelEntity == nil else { continue }
            model.asyncLoadModelEntity { _, _ in }
        }
    }

    private func expectedArtifactCounts(from scenePersistenceData: Data) -> (models: Int, annotations: Int) {
        guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: ARWorldMap.self,
            from: scenePersistenceData
        ) else {
            return (0, 0)
        }

        var models = 0
        var annotations = 0

        for anchor in worldMap.anchors {
            guard let name = anchor.name else { continue }
            if name.hasPrefix(anchorNamePrefix) {
                models += 1
            } else if name.hasPrefix(annotationNamePrefix) {
                annotations += 1
            }
        }

        return (models, annotations)
    }

    func updatePersistenceAvailability(for arView: ARView) {
        guard let currentFrame = arView.session.currentFrame else {
            print("ARFrame not available")
            return
        }

        let hasPlacedModels = !self.sceneManager.anchorEntities.isEmpty
        let hasPlacedAnnotations = !self.sceneManager.annotationAnchors.isEmpty
        let hasDrawing = !(self.sceneManager.drawAnchorEntity?.children.isEmpty ?? true)
        let hasPersistableContent = hasPlacedModels || hasPlacedAnnotations || hasDrawing

        switch currentFrame.worldMappingStatus {
        case .mapped, .extending:
            self.sceneManager.isPersistenceAvailable = hasPersistableContent
        default:
            self.sceneManager.isPersistenceAvailable = false
        }
    }

    func handlePersistence(for arView: CustomARView) {
        if self.sceneManager.shouldSaveSceneToCloud {
            saveToCloud(arView: arView)
            return
        }
        if self.sceneManager.shouldLoadSceneFromCloud {
            loadFromCloud(arView: arView)
        }
    }

    private func saveToCloud(arView: CustomARView) {
        self.sceneManager.shouldSaveSceneToCloud = false
        self.sceneManager.beginPersistenceProgress("Saving scene...")

        CloudSceneStore.resolveWritableSceneId(preferredSceneId: self.sceneManager.selectedCloudSceneId) { result in
            switch result {
            case .failure(let error):
                print("Failed to resolve writable scene id:", error.localizedDescription)
                self.sceneManager.endPersistenceProgress()
                self.sceneManager.postPersistenceNotice(
                    "Cloud save failed. Please try again.",
                    style: .error
                )
            case .success(let resolution):
                let targetSceneId = resolution.sceneId
                let remappedFromSceneId = resolution.remappedFromSceneId
                self.sceneManager.selectedCloudSceneId = targetSceneId
                self.sceneManager.selectedCloudSceneStoragePath = nil

                arView.session.getCurrentWorldMap { map, err in
                    guard let map = map else {
                        print("No world map:", err?.localizedDescription ?? "unknown error")
                        self.sceneManager.endPersistenceProgress()
                        self.sceneManager.postPersistenceNotice(
                            "Could not save scene map. Try scanning more of the area and try again.",
                            style: .error
                        )
                        return
                    }
                    do {
                        let data = try NSKeyedArchiver.archivedData(
                            withRootObject: map,
                            requiringSecureCoding: true
                        )
                        CloudSceneStore.save(data: data, sceneId: targetSceneId) { saveResult in
                            switch saveResult {
                            case .failure(let error):
                                print("Cloud save failed:", error)
                                self.sceneManager.endPersistenceProgress()
                                self.sceneManager.postPersistenceNotice(
                                    "Cloud save failed. Please try again.",
                                    style: .error
                                )
                            case .success(let savedId):
                                Task {
                                    do {
                                        if let oldSceneId = remappedFromSceneId, oldSceneId != savedId {
                                            try await ArtifactsService.shared.remapMyDraftArtifacts(
                                                fromSceneId: oldSceneId,
                                                toSceneId: savedId
                                            )
                                        }
                                        try await ArtifactsService.shared.publishDraftArtifacts(sceneId: savedId)
                                        print("✅ Published draft artifacts for scene:", savedId)
                                        self.sceneManager.endPersistenceProgress()
                                        self.sceneManager.postPersistenceNotice(
                                            "Scene saved successfully.",
                                            style: .success
                                        )
                                    } catch {
                                        print("⚠️ publish/remap error:", error.localizedDescription)
                                        self.sceneManager.endPersistenceProgress()
                                        self.sceneManager.postPersistenceNotice(
                                            "Scene saved, but publishing artifacts failed.",
                                            style: .info
                                        )
                                    }
                                }
                            }
                        }
                    } catch {
                        print("Archive error:", error)
                        self.sceneManager.endPersistenceProgress()
                        self.sceneManager.postPersistenceNotice(
                            "Failed to package scene for saving.",
                            style: .error
                        )
                    }
                }
            }
        }
    }

    private func loadFromCloud(arView: CustomARView) {
        self.sceneManager.shouldLoadSceneFromCloud = false
        self.sceneManager.beginPersistenceProgress("Loading scene...")
        self.sceneManager.stopAnnotationTextListener()
        self.sceneManager.selectedSceneOwnerUid = nil
        self.sceneManager.anchorEntities.removeAll(keepingCapacity: true)
        self.clearAllDrawings(in: arView)
        self.sceneManager.fallbackArtifactAnchorEntity?.removeFromParent()
        self.sceneManager.fallbackArtifactAnchorEntity = nil
        self.sceneManager.fallbackRestoredModelArtifactIds.removeAll(keepingCapacity: true)
        self.sceneManager.fallbackRestoredAnnotationArtifactIds.removeAll(keepingCapacity: true)
        for (_, badge) in self.sceneManager.artifactOwnerBadgeViews { badge.removeFromSuperview() }
        self.sceneManager.artifactOwnerBadgeViews.removeAll(keepingCapacity: true)
        self.sceneManager.artifactOwnerBadgeWorldPositions.removeAll(keepingCapacity: true)
        self.sceneManager.artifactOwnerBadgeOffsetsY.removeAll(keepingCapacity: true)

        for (_, view) in self.sceneManager.annotationViews { view.removeFromSuperview() }
        for (_, btn) in self.sceneManager.deleteButtons { btn.removeFromSuperview() }

        self.sceneManager.annotationViews.removeAll(keepingCapacity: true)
        self.sceneManager.deleteButtons.removeAll(keepingCapacity: true)
        self.sceneManager.annotationAnchors.removeAll(keepingCapacity: true)
        self.sceneManager.isEditing.removeAll(keepingCapacity: true)
        self.sceneManager.hasBeenTapped.removeAll(keepingCapacity: true)

        // Clear old overrides, then prefetch new overrides for the scene that will be loaded.
        self.sceneManager.annotationTextOverrides = [:]

        let targetSceneId: String? = self.sceneManager.selectedCloudSceneId

        if let id = targetSceneId {
            Task {
                let ownerUid = try? await ArtifactsService.shared.fetchSceneOwnerUid(sceneId: id)
                await MainActor.run {
                    self.sceneManager.selectedSceneOwnerUid = ownerUid ?? Auth.auth().currentUser?.uid
                }
            }
            startRealtimeAnnotationSyncIfNeeded(on: arView)
            Task {
                do {
                    let overrides = try await ArtifactsService.shared.fetchVisibleAnnotationTextOverrides(sceneId: id)
                    await MainActor.run {
                        self.sceneManager.annotationTextOverrides = overrides
                    }
                } catch {
                    print("⚠️ fetchVisibleAnnotationTextOverrides error:", error.localizedDescription)
                }
            }

            let load: (@escaping (Result<Data, Error>) -> Void) -> Void
            if let storagePath = self.sceneManager.selectedCloudSceneStoragePath, !storagePath.isEmpty {
                load = { completion in CloudSceneStore.load(storagePath: storagePath, completion: completion) }
            } else {
                load = { completion in CloudSceneStore.load(sceneId: id, completion: completion) }
            }

            load { result in
                switch result {
                case .success(let data):
                    let expected = self.expectedArtifactCounts(from: data)
                    let modelNames = self.modelNamesInScene(from: data)
                    self.preloadModelEntities(named: modelNames)
                    ScenePersistenceHelper.loadScene(for: arView, with: data)
                    self.restoreDrawingsAfterRelocalization(sceneId: id, in: arView)
                    self.sceneManager.beginAwaitingVisibleArtifactsAfterLoad(
                        expectedModels: expected.models,
                        expectedAnnotations: expected.annotations
                    )
                    self.sceneManager.startLoadVisibilityTimeout()
                case .failure(let error):
                    print("Cloud load failed:", error)
                    DispatchQueue.main.async {
                        self.sceneManager.isAwaitingVisibleArtifactsAfterLoad = false
                    }
                    self.sceneManager.endPersistenceProgress()
                    self.sceneManager.postPersistenceNotice(
                        "Cloud load failed. Please try again.",
                        style: .error
                    )
                }
            }
        } else {
            let handleLoad: (String, String?, Data) -> Void = { sceneId, storagePath, data in
                let expected = self.expectedArtifactCounts(from: data)
                let modelNames = self.modelNamesInScene(from: data)
                self.preloadModelEntities(named: modelNames)
                self.sceneManager.selectedCloudSceneId = sceneId
                self.sceneManager.selectedCloudSceneStoragePath = storagePath
                Task {
                    let ownerUid = try? await ArtifactsService.shared.fetchSceneOwnerUid(sceneId: sceneId)
                    await MainActor.run {
                        self.sceneManager.selectedSceneOwnerUid = ownerUid ?? Auth.auth().currentUser?.uid
                    }
                }
                self.startRealtimeAnnotationSyncIfNeeded(on: arView)

                Task {
                    do {
                        let overrides = try await ArtifactsService.shared.fetchVisibleAnnotationTextOverrides(sceneId: sceneId)
                        await MainActor.run {
                            self.sceneManager.annotationTextOverrides = overrides
                        }
                    } catch {
                        print("⚠️ fetchVisibleAnnotationTextOverrides error:", error.localizedDescription)
                    }
                }

                ScenePersistenceHelper.loadScene(for: arView, with: data)
                self.restoreDrawingsAfterRelocalization(sceneId: sceneId, in: arView)
                self.sceneManager.beginAwaitingVisibleArtifactsAfterLoad(
                    expectedModels: expected.models,
                    expectedAnnotations: expected.annotations
                )
                self.sceneManager.startLoadVisibilityTimeout()
            }

            CloudSceneStore.loadMostRecentSceneData { ownResult in
                switch ownResult {
                case .success(let payload):
                    handleLoad(payload.id, nil, payload.data)
                case .failure:
                    CloudSceneStore.loadMostRecentAccessibleSceneData { friendResult in
                        switch friendResult {
                        case .success(let payload):
                            handleLoad(payload.id, payload.storagePath, payload.data)
                        case .failure(let error):
                            print("Cloud load (latest) failed:", error)
                            DispatchQueue.main.async {
                                self.sceneManager.isAwaitingVisibleArtifactsAfterLoad = false
                            }
                            self.sceneManager.endPersistenceProgress()
                            self.sceneManager.postPersistenceNotice(
                                "No scene could be loaded.",
                                style: .error
                            )
                        }
                    }
                }
            }
        }
    }

    private func ensureFallbackArtifactRoot(in arView: ARView) -> AnchorEntity {
        if let existing = self.sceneManager.fallbackArtifactAnchorEntity {
            return existing
        }
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        self.sceneManager.fallbackArtifactAnchorEntity = anchor
        return anchor
    }

    private func placeFallbackModel(
        _ record: ModelArtifactRecord,
        in arView: ARView
    ) {
        guard !self.sceneManager.fallbackRestoredModelArtifactIds.contains(record.artifactId) else { return }
        guard let model = self.modelsViewModel.models.first(where: { $0.name == record.modelName }) else { return }

        let place: () -> Void = {
            guard let prototype = model.modelEntity else { return }
            let root = self.ensureFallbackArtifactRoot(in: arView)
            let entity = prototype.clone(recursive: true)
            entity.generateCollisionShapes(recursive: true)
            entity.transform.matrix = record.transform
            root.addChild(entity)
            self.sceneManager.fallbackRestoredModelArtifactIds.insert(record.artifactId)
            let pos = SIMD3<Float>(
                record.transform.columns.3.x,
                record.transform.columns.3.y,
                record.transform.columns.3.z
            )
            let hasAnchorBackedModelBadge = self.sceneManager.artifactOwnerBadgeViews.keys.contains {
                $0.hasPrefix("model-anchor-")
            }
            if !hasAnchorBackedModelBadge {
                self.upsertArtifactOwnerBadge(
                    artifactId: record.artifactId,
                    ownerUid: record.ownerUid,
                    worldPosition: pos,
                    yOffset: -40,
                    on: arView
                )
            }
            self.sceneManager.markRestoredModelIfAwaiting()
        }

        if model.modelEntity == nil {
            model.asyncLoadModelEntity { completed, _ in
                guard completed else { return }
                DispatchQueue.main.async {
                    place()
                }
            }
        } else {
            place()
        }
    }

    func restoreVisibleModelsAndAnnotationsFromCloud(sceneId: String, in arView: ARView) {
        guard !sceneId.isEmpty else { return }

        Task {
            do {
                async let modelsTask = ArtifactsService.shared.fetchVisibleModelArtifacts(sceneId: sceneId)
                async let annotationsTask = ArtifactsService.shared.fetchVisibleAnnotationArtifacts(sceneId: sceneId)
                let (modelRecords, annotationRecords) = try await (modelsTask, annotationsTask)

                await MainActor.run {
                    for record in modelRecords {
                        self.placeFallbackModel(record, in: arView)
                    }

                    for record in annotationRecords {
                        guard !self.sceneManager.fallbackRestoredAnnotationArtifactIds.contains(record.artifactId) else { continue }
                        guard let id = UUID(uuidString: record.artifactId) else { continue }
                        guard self.sceneManager.annotationViews[id] == nil else { continue }

                        let payload = AnnotationData(id: id, text: record.annotationText)
                        let name = annotationNamePrefix + self.encodeAnnotation(payload)
                        let anchor = ARAnchor(name: name, transform: record.transform)
                        self.attachAnnotationView(for: anchor, data: payload, on: arView)
                        let pos = SIMD3<Float>(
                            record.transform.columns.3.x,
                            record.transform.columns.3.y,
                            record.transform.columns.3.z
                        )
                        self.upsertArtifactOwnerBadge(
                            artifactId: record.artifactId,
                            ownerUid: record.ownerUid,
                            worldPosition: pos,
                            yOffset: -84,
                            on: arView
                        )
                        self.sceneManager.fallbackRestoredAnnotationArtifactIds.insert(record.artifactId)
                    }
                }
            } catch {
                print("⚠️ restoreVisibleModelsAndAnnotationsFromCloud error:", error.localizedDescription)
            }
        }
    }
}

//
//  ARViewContainer+Persistence.swift
//  ARTutorial
//

import RealityKit
import ARKit
import Foundation

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

        let sceneId: String
        if let id = self.sceneManager.selectedCloudSceneId, !id.isEmpty {
            sceneId = id
        } else {
            let newId = UUID().uuidString
            self.sceneManager.selectedCloudSceneId = newId
            sceneId = newId
        }

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
                CloudSceneStore.save(data: data, sceneId: sceneId) { result in
                    switch result {
                    case .failure(let e):
                        print("Cloud save failed:", e)
                        self.sceneManager.endPersistenceProgress()
                        self.sceneManager.postPersistenceNotice(
                            "Cloud save failed. Please try again.",
                            style: .error
                        )
                    case .success(let savedId):
                        self.sceneManager.endPersistenceProgress()
                        self.sceneManager.postPersistenceNotice(
                            "Scene saved successfully.",
                            style: .success
                        )
                        Task {
                            do {
                                try await ArtifactsService.shared.publishDraftArtifacts(sceneId: savedId)
                                print("✅ Published draft artifacts for scene:", savedId)
                            } catch {
                                print("⚠️ publishDraftArtifacts error:", error.localizedDescription)
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

    private func loadFromCloud(arView: CustomARView) {
        self.sceneManager.shouldLoadSceneFromCloud = false
        self.sceneManager.beginPersistenceProgress("Loading scene...")
        self.sceneManager.stopAnnotationTextListener()
        self.sceneManager.anchorEntities.removeAll(keepingCapacity: true)
        self.clearAllDrawings(in: arView)

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
            startRealtimeAnnotationSyncIfNeeded(on: arView)
            Task {
                do {
                    let overrides = try await ArtifactsService.shared.fetchMyAnnotationTextOverrides(sceneId: id)
                    await MainActor.run {
                        self.sceneManager.annotationTextOverrides = overrides
                    }
                } catch {
                    print("⚠️ fetchMyAnnotationTextOverrides error:", error.localizedDescription)
                }
            }

            CloudSceneStore.load(sceneId: id) { result in
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
            CloudSceneStore.loadMostRecentSceneData { result in
                switch result {
                case .success(let payload):
                    let expected = self.expectedArtifactCounts(from: payload.data)
                    let modelNames = self.modelNamesInScene(from: payload.data)
                    self.preloadModelEntities(named: modelNames)
                    self.sceneManager.selectedCloudSceneId = payload.id
                    self.startRealtimeAnnotationSyncIfNeeded(on: arView)

                    Task {
                        do {
                            let overrides = try await ArtifactsService.shared.fetchMyAnnotationTextOverrides(sceneId: payload.id)
                            await MainActor.run {
                                self.sceneManager.annotationTextOverrides = overrides
                            }
                        } catch {
                            print("⚠️ fetchMyAnnotationTextOverrides error:", error.localizedDescription)
                        }
                    }

                    ScenePersistenceHelper.loadScene(for: arView, with: payload.data)
                    self.restoreDrawingsAfterRelocalization(sceneId: payload.id, in: arView)
                    self.sceneManager.beginAwaitingVisibleArtifactsAfterLoad(
                        expectedModels: expected.models,
                        expectedAnnotations: expected.annotations
                    )
                    self.sceneManager.startLoadVisibilityTimeout()
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

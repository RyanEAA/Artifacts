//
//  ARViewContainer+Persistence.swift
//  ARTutorial
//

import RealityKit
import ARKit
import Foundation

extension ARViewContainer {

    func updatePersistenceAvailability(for arView: ARView) {
        guard let currentFrame = arView.session.currentFrame else {
            print("ARFrame not available")
            return
        }
        switch currentFrame.worldMappingStatus {
        case .mapped, .extending:
            self.sceneManager.isPersistenceAvailable = !self.sceneManager.anchorEntities.isEmpty
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
                    case .success(let savedId):
                        Task {
                            do {
                                try await ArtifactsService.shared.publishDraftArtifacts(sceneId: savedId)
                                print("✅ Published draft artifacts for scene:", savedId)
                            } catch {
                                print("⚠️ publishDraftArtifacts error:", error.localizedDescription)
                            }
                        }
                    }
                }
            } catch {
                print("Archive error:", error)
            }
        }
    }

    private func loadFromCloud(arView: CustomARView) {
        self.sceneManager.shouldLoadSceneFromCloud = false
        self.modelsViewModel.clearModelEntityFromMemory()
        self.sceneManager.anchorEntities.removeAll(keepingCapacity: true)

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
                    ScenePersistenceHelper.loadScene(for: arView, with: data)
                case .failure(let error):
                    print("Cloud load failed:", error)
                }
            }
        } else {
            CloudSceneStore.loadMostRecentSceneData { result in
                switch result {
                case .success(let payload):
                    self.sceneManager.selectedCloudSceneId = payload.id

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
                case .failure(let error):
                    print("Cloud load (latest) failed:", error)
                }
            }
        }
    }
}

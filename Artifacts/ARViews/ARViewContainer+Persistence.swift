//
//  ARViewContainer+Persistence.swift
//  ARTutorial
//
//  Handles world-map availability checks and save/load from both
//  the local filesystem and CloudSceneStore.
//

import RealityKit
import ARKit

extension ARViewContainer {

    // MARK: - Availability

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

    // MARK: - Save / Load Dispatch

    func handlePersistence(for arView: CustomARView) {
        if self.sceneManager.shouldSaveSceneToCloud {
            saveToCloud(arView: arView)
            return
        }
        if self.sceneManager.shouldLoadSceneFromCloud {
            loadFromCloud(arView: arView)
        }
    }

    // MARK: - Cloud Save

    private func saveToCloud(arView: CustomARView) {
        self.sceneManager.shouldSaveSceneToCloud = false
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
                CloudSceneStore.save(data: data) { result in
                    if case let .failure(e) = result { print("Cloud save failed:", e) }
                }
            } catch {
                print("Archive error:", error)
            }
        }
    }

    // MARK: - Cloud Load

    private func loadFromCloud(arView: CustomARView) {
        self.sceneManager.shouldLoadSceneFromCloud = false
        self.modelsViewModel.clearModelEntityFromMemory()
        self.sceneManager.anchorEntities.removeAll(keepingCapacity: true)

        // Remove all existing 2D annotation views and state
        for (_, view) in self.sceneManager.annotationViews { view.removeFromSuperview() }
        for (_, btn)  in self.sceneManager.deleteButtons   { btn.removeFromSuperview()  }
        self.sceneManager.annotationViews.removeAll(keepingCapacity: true)
        self.sceneManager.deleteButtons.removeAll(keepingCapacity: true)
        self.sceneManager.annotationAnchors.removeAll(keepingCapacity: true)
        self.sceneManager.isEditing.removeAll(keepingCapacity: true)
        self.sceneManager.hasBeenTapped.removeAll(keepingCapacity: true)

        if let id = self.sceneManager.selectedCloudSceneId {
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
                    ScenePersistenceHelper.loadScene(for: arView, with: payload.data)
                case .failure(let error):
                    print("Cloud load (latest) failed:", error)
                }
            }
        }
    }
}

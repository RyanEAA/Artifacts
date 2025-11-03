//
//  ARViewContainer.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/23/25.
//

import Foundation
import RealityKit
import SwiftUI
import ARKit

private let anchorNamePrefix = "model-"

struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var placementSettings: PlacementSettings
    @EnvironmentObject var sessionSettings: SessionSettings
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @EnvironmentObject var modelDeletionManager: ModelDeletionManager
    
    func makeUIView(context: Context) -> CustomARView {
        let arView = CustomARView(frame: .zero, sessionSettings: sessionSettings, modelDeletionManager: modelDeletionManager)
        
        arView.session.delegate = context.coordinator
        
        // subscriber to sceneEvents.Update
        self.placementSettings.sceneObserver = arView.scene.subscribe(to: SceneEvents.Update.self, { (event) in
            
            self.updateScene(for: arView)
            self.updatePersistenceAvailability(for: arView)
            self.handlePersistence(for: arView)
            
        })
        
        return arView
        
    }
    
    func updateUIView(_ uiView: CustomARView, context: Context){
        
    }
    
    private func updateScene(for arView: CustomARView){
        
        // only display focusEntity when the user has selected a model for placement
        arView.focusEntity?.isEnabled = self.placementSettings.selectedModel != nil
        
        // add model to the scene
        if let modelAnchor = self.placementSettings.modelsConfirmedForPlacement.popLast(), let modelEntity = modelAnchor.model.modelEntity {
            if let anchor = modelAnchor.anchor {
                // if anchor exists
                self.place(modelEntity, for: anchor, in: arView)
                
            } else if let transform = getTransformForPlacement(in: arView) {
                // proce w
                let anchorName = anchorNamePrefix + modelAnchor.model.name
                let anchor = ARAnchor(name: anchorName, transform: transform)
                
                self.place(modelEntity, for: anchor, in: arView)
                
                arView.session.add(anchor: anchor)
                
                self.placementSettings.recentlyPlaced.append(modelAnchor.model)
            }
        }
        
    }
    
    private func place(_ modelEntity: ModelEntity, for anchor: ARAnchor, in arView: ARView) {
        // 1) Clone so multiple placements work independently
        let clonedEntity = modelEntity.clone(recursive: true)

        // Generate collisions BEFORE gestures
        clonedEntity.generateCollisionShapes(recursive: true)
        arView.installGestures([.rotation, .translation], for: clonedEntity)

        // 2) Capture the exact, current world transform of the focus reticle (or raycast/camera fallback)
//        let anchorEntity: AnchorEntity
//        if let focus = arView.focusEntity {
//            // Use the full 4x4 transform — avoids stale pose reuse and preserves rotation
//            let worldMatrix = focus.transformMatrix(relativeTo: nil)
//            anchorEntity = AnchorEntity(world: worldMatrix)
//        } else if let ray = arView.raycast(from: arView.center, allowing: .estimatedPlane, alignment: .any).first {
//            anchorEntity = AnchorEntity(raycastResult: ray)
//        } else {
//            // Fallback: half a meter in front of camera with the camera’s rotation
//            var t = arView.cameraTransform
//            let forward = t.matrix.columns.2
//            t.translation -= SIMD3<Float>(forward.x, forward.y, forward.z) * 0.5
//            anchorEntity = AnchorEntity(world: t.matrix)
//        }
        
        let anchorEntity = AnchorEntity(plane: .any)
        anchorEntity.addChild(clonedEntity)
        
        anchorEntity.anchoring = AnchoringComponent(anchor)
        
        arView.scene.addAnchor(anchorEntity)
        
        self.sceneManager.anchorEntities.append(anchorEntity)

//        // 3) Add child, then add anchor
//        anchorEntity.addChild(cloned)
//        arView.scene.addAnchor(anchorEntity)
//
//        // 4) Enable gestures on the placed entity
//        arView.installGestures([.translation, .rotation], for: cloned)
//        
//        self.sceneManager.anchorEntities.append(anchorEntity)
//        
//        // Debug
//        print("Placed at world transform:\n\(anchorEntity.transform.matrix)")
    }
    
    private func getTransformForPlacement(in arView: ARView) -> simd_float4x4? {
        guard let query = arView.makeRaycastQuery(from: arView.center, allowing: .estimatedPlane, alignment: .any) else {
            return nil
        }
        guard let raycastResult = arView.session.raycast(query).first else { return nil }
        
        return raycastResult.worldTransform
    }

    
}

// MARK: - Persistence

class SceneManager: ObservableObject {
    @Published var isPersistenceAvailable: Bool = false
    @Published var anchorEntities: [AnchorEntity] = [] // keeps track of anchored entities
    
    var shouldSaveSceneToFilesystem: Bool = false // flag to trigger save scene to filesystem function
    var shouldLoadSceneToFilesystem: Bool = false // flag to trigger load scene to filesystem function

    // in SceneManager
    var shouldSaveSceneToCloud = false
    var shouldLoadSceneFromCloud = false
    var selectedCloudSceneId: String? // set this before tapping “Load”
    
    lazy var persistenceUrl: URL = {
        do {
            
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("arf.persistence")
        } catch {
            fatalError("Unable to get persistenceURL: \(error.localizedDescription)")
        }
    }()
    
    var scenePersistenceData: Data? {
        return try? Data(contentsOf: persistenceUrl)
    }
}

extension ARViewContainer {
    private func updatePersistenceAvailability(for arView: ARView) {
        guard let currentFrame = arView.session.currentFrame else {
            print("ARFrame not available")
            return
        }
        
        switch currentFrame.worldMappingStatus {
        case .mapped, .extending:
            self.sceneManager.isPersistenceAvailable = !self.sceneManager.anchorEntities.isEmpty
            //print("save scene is available")
        default:
            self.sceneManager.isPersistenceAvailable = false
        }
    }
    
    private func handlePersistence(for arView: CustomARView) {
        // inside ARViewContainer.handlePersistence(...)
        if sceneManager.shouldSaveSceneToCloud {
            sceneManager.shouldSaveSceneToCloud = false
            // get bytes exactly like the local save does, but without writing the file:
            arView.session.getCurrentWorldMap { map, err in
                guard let map = map else { print("No world map:", err?.localizedDescription ?? ""); return }
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    CloudSceneStore.save(data: data) { result in
                        if case let .failure(e) = result { print("Cloud save failed:", e) }
                    }
                } catch { print("Archive error:", error) }
            }
            return
        }

        // --- CLOUD LOAD ---
        // ARViewContainer.swift → inside handlePersistence, cloud SAVE branch
        if sceneManager.shouldLoadSceneFromCloud {
            sceneManager.shouldLoadSceneFromCloud = false

            // Clear current AR content (same routine you already use)
            self.modelsViewModel.clearModelEntityFromMemory()
            self.sceneManager.anchorEntities.removeAll(keepingCapacity: true)

            // Prefer selected id; otherwise fall back to "most recent"
            if let id = sceneManager.selectedCloudSceneId {
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
            return
        }



    }

}

extension ARViewContainer {
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let anchorName = anchor.name, anchorName.hasPrefix(anchorNamePrefix) {
                    let modelName = anchorName.dropFirst(anchorNamePrefix.count)
                    
                    print("ARSession: didAdd anchor for modelName: \(modelName)")
                    
                    guard let model = self.parent.modelsViewModel.models.first(where: { $0.name == modelName }) else {
                        print("Unable to retrieve model from modelsViewModel")
                        return
                    }
                    
                    if model.modelEntity == nil {
                        model.asyncLoadModelEntity { completed, error in
                            if completed {
                                let modelAnchor = ModelAnchor(model: model, anchor: anchor)
                                self.parent.placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
                                
                                print("Adding modelAnchor with name: \(model.name)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

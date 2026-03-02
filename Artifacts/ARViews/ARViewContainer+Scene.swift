//
//  ARViewContainer+Scene.swift
//  ARTutorial
//
//  Scene update loop, model placement, and raycast transform helpers.
//

import RealityKit
import ARKit
import UIKit

extension ARViewContainer {

    // MARK: - Scene Update

    func updateScene(for arView: CustomARView) {
        // Show focusEntity only when a 3D model tool is active
        if case .model = placementSettings.selectedTool {
            arView.focusEntity?.isEnabled = true
        } else {
            arView.focusEntity?.isEnabled = false
        }

        // Place a confirmed model into the scene
        if let modelAnchor = self.placementSettings.modelsConfirmedForPlacement.popLast(),
           let modelEntity = modelAnchor.model.modelEntity {
            if let anchor = modelAnchor.anchor {
                self.place(modelEntity, for: anchor, in: arView)
            } else if let transform = getTransformForPlacement(in: arView) {
                let anchorName = anchorNamePrefix + modelAnchor.model.name
                let anchor = ARAnchor(name: anchorName, transform: transform)
                self.place(modelEntity, for: anchor, in: arView)
                arView.session.add(anchor: anchor)
                self.placementSettings.recentlyPlaced.append(modelAnchor.model)
            }
        }

        // Handle any pending 2D annotation placement requests
        self.placePendingAnnotationIfNeeded(on: arView)
    }

    // MARK: - Model Placement

    func place(_ modelEntity: ModelEntity, for anchor: ARAnchor, in arView: ARView) {
        let clonedEntity = modelEntity.clone(recursive: true)
        clonedEntity.generateCollisionShapes(recursive: true)
        arView.installGestures([.rotation, .translation], for: clonedEntity)
        let anchorEntity = AnchorEntity(plane: .any)
        anchorEntity.addChild(clonedEntity)
        anchorEntity.anchoring = AnchoringComponent(anchor)
        arView.scene.addAnchor(anchorEntity)
        self.sceneManager.anchorEntities.append(anchorEntity)
    }

    // MARK: - Raycast Helpers

    func getTransformForPlacement(in arView: ARView) -> simd_float4x4? {
        guard let query = arView.makeRaycastQuery(
            from: arView.center,
            allowing: .estimatedPlane,
            alignment: .any
        ),
              let result = arView.session.raycast(query).first else { return nil }
        return result.worldTransform
    }

    func getTransformForPlacement(in arView: ARView, at point: CGPoint) -> simd_float4x4? {
        guard let query = arView.makeRaycastQuery(
            from: point,
            allowing: .estimatedPlane,
            alignment: .any
        ),
              let result = arView.session.raycast(query).first else { return nil }
        return result.worldTransform
    }
}

























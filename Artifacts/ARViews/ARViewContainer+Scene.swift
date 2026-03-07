//
//  ARViewContainer+Scene.swift
//  ARTutorial
//

import RealityKit
import ARKit
import UIKit

extension ARViewContainer {

    func currentSceneIdForArtifacts() -> String {
        if let id = self.sceneManager.selectedCloudSceneId, !id.isEmpty {
            return id
        }
        let newId = UUID().uuidString
        self.sceneManager.selectedCloudSceneId = newId
        self.sceneManager.selectedCloudSceneStoragePath = nil
        return newId
    }

    private func saveModelToFirestore(modelName: String, transform: simd_float4x4) {
        let sceneId = currentSceneIdForArtifacts()
        let artifactId = UUID().uuidString

        let coordinate = LocationService.shared.currentCoordinate

        print("🟩 Saving model artifact modelName:", modelName, "sceneId:", sceneId, "artifactId:", artifactId)

        Task {
            do {
                try await ArtifactsService.shared.createModelArtifact(
                    artifactId: artifactId,
                    modelName: modelName,
                    sceneId: sceneId,
                    transform: transform,
                    coordinate: coordinate
                )
                print("✅ Saved model artifact:", artifactId)
            } catch {
                print("❌ createModelArtifact error:", error.localizedDescription)
            }
        }
    }

    func updateScene(for arView: CustomARView) {
        if case .model = placementSettings.selectedTool {
            arView.focusEntity?.isEnabled = true
        } else {
            arView.focusEntity?.isEnabled = false
        }

        if let modelAnchor = self.placementSettings.modelsConfirmedForPlacement.popLast(),
           let modelEntity = modelAnchor.model.modelEntity {

            if let anchor = modelAnchor.anchor {
                self.place(modelEntity, for: anchor, in: arView)
                self.sceneManager.markRestoredModelIfAwaiting()

            } else if let transform = getTransformForPlacement(in: arView) {
                let anchorName = anchorNamePrefix + modelAnchor.model.name
                let anchor = ARAnchor(name: anchorName, transform: transform)
                self.place(modelEntity, for: anchor, in: arView)
                arView.session.add(anchor: anchor)
                self.placementSettings.recentlyPlaced.append(modelAnchor.model)
                saveModelToFirestore(modelName: modelAnchor.model.name, transform: transform)
            }
        }

        self.placePendingAnnotationIfNeeded(on: arView)
    }

    func place(_ modelEntity: ModelEntity, for anchor: ARAnchor, in arView: ARView) {
        let clonedEntity = modelEntity.clone(recursive: true)
        clonedEntity.generateCollisionShapes(recursive: true)
        arView.installGestures([.rotation, .translation], for: clonedEntity)

        // Bind the rendered entity to the exact ARAnchor transform from placement/reload.
        let anchorEntity = AnchorEntity(.anchor(identifier: anchor.identifier))
        anchorEntity.addChild(clonedEntity)
        arView.scene.addAnchor(anchorEntity)

        self.sceneManager.anchorEntities.append(anchorEntity)
    }

    func getTransformForPlacement(in arView: ARView) -> simd_float4x4? {
        return bestPlacementTransform(in: arView, from: arView.center)
    }

    func getTransformForPlacement(in arView: ARView, at point: CGPoint) -> simd_float4x4? {
        return bestPlacementTransform(in: arView, from: point)
            ?? bestPlacementTransform(in: arView, from: arView.center)
    }

    private func bestPlacementTransform(in arView: ARView, from point: CGPoint) -> simd_float4x4? {
        let targets: [ARRaycastQuery.Target] = [
            .existingPlaneGeometry,
            .existingPlaneInfinite,
            .estimatedPlane
        ]
        let alignments: [ARRaycastQuery.TargetAlignment] = [.any, .horizontal, .vertical]

        for target in targets {
            for alignment in alignments {
                guard let query = arView.makeRaycastQuery(
                    from: point,
                    allowing: target,
                    alignment: alignment
                ) else { continue }

                if let result = arView.session.raycast(query).first {
                    return result.worldTransform
                }
            }
        }

        return nil
    }
}

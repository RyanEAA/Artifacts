//
//  ARViewContainer+Scene.swift
//  ARTutorial
//

import RealityKit
import ARKit
import UIKit
import FirebaseAuth

extension ARViewContainer {

    func writableSceneIdForArtifactWrites() async throws -> String {
        let preferred = self.sceneManager.selectedCloudSceneId

        let resolution = try await withCheckedThrowingContinuation { continuation in
            CloudSceneStore.resolveWritableSceneId(preferredSceneId: preferred) { result in
                continuation.resume(with: result)
            }
        }

        self.sceneManager.selectedCloudSceneId = resolution.sceneId
        self.sceneManager.selectedCloudSceneStoragePath = nil

        try await withCheckedThrowingContinuation { continuation in
            CloudSceneStore.ensureSceneDocumentExists(sceneId: resolution.sceneId) { result in
                continuation.resume(with: result)
            }
        }

        return resolution.sceneId
    }

    func currentSceneIdForArtifacts() -> String {
        if let id = self.sceneManager.selectedCloudSceneId, !id.isEmpty {
            return id
        }
        let newId = UUID().uuidString
        self.sceneManager.selectedCloudSceneId = newId
        self.sceneManager.selectedCloudSceneStoragePath = nil
        return newId
    }

    private func saveModelToFirestore(
        artifactId: String,
        modelName: String,
        transform: simd_float4x4,
        in arView: ARView
    ) {
        let coordinate = LocationService.shared.currentCoordinate

        Task {
            do {
                let sceneId = try await writableSceneIdForArtifactWrites()
                print("🟩 Saving model artifact modelName:", modelName, "sceneId:", sceneId, "artifactId:", artifactId)
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
        
        // placing model

        if case .model(let model) = placementSettings.selectedTool {
            arView.focusEntity?.isEnabled = true


            guard let entity = model.modelEntity else { return }

            // Create preview if it doesn't exist
            if placementSettings.previewEntity == nil {

                let preview = entity.clone(recursive: true)
                makePreviewTransparent(preview)
                preview.generateCollisionShapes(recursive: true)

                placementSettings.previewEntity = preview

                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(preview)

                arView.scene.addAnchor(anchor)
            }

            // Update preview position every frame
            if let transform = getTransformForPlacement(in: arView),
               let preview = placementSettings.previewEntity,
               let anchor = preview.anchor {

                anchor.transform.matrix = transform
            }

         } else {
             // Remove preview if user exited placement mode
             placementSettings.previewEntity?.removeFromParent()
             placementSettings.previewEntity = nil
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
                let artifactId = UUID().uuidString
                let ownerUid = Auth.auth().currentUser?.uid ?? ""
                let pos = SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
                self.upsertArtifactOwnerBadge(
                    artifactId: artifactId,
                    ownerUid: ownerUid,
                    worldPosition: pos,
                    yOffset: -40,
                    on: arView
                )
                saveModelToFirestore(
                    artifactId: artifactId,
                    modelName: modelAnchor.model.name,
                    transform: transform,
                    in: arView
                )
            }
        }

        self.placePendingAnnotationIfNeeded(on: arView)
    }
    
    func makePreviewTransparent(_ entity: Entity) {

        if let modelEntity = entity as? ModelEntity {

            var newMaterials: [Material] = []

            for material in modelEntity.model?.materials ?? [] {

                if var pbr = material as? PhysicallyBasedMaterial {

                    pbr.blending = .transparent(opacity: .init(floatLiteral: 0.35))
                    newMaterials.append(pbr)

                } else if var simple = material as? SimpleMaterial {

                    simple.color = .init(
                        tint: simple.color.tint,
                        texture: simple.color.texture
                    )
                    simple.color.tint = simple.color.tint.withAlphaComponent(0.35)
                    newMaterials.append(simple)

                } else {
                    newMaterials.append(material)
                }
            }

            modelEntity.model?.materials = newMaterials
        }

        // Recursively apply to children
        for child in entity.children {
            makePreviewTransparent(child)
        }
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

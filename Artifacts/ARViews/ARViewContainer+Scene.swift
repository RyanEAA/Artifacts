//
//  ARViewContainer+Scene.swift
//  ARTutorial
//

import RealityKit
import ARKit
import UIKit
import FirebaseAuth
import QuartzCore

extension ARViewContainer {

    func modelBadgeWorldPosition(for modelEntity: ModelEntity) -> SIMD3<Float> {
        let bounds = modelEntity.visualBounds(relativeTo: nil)
        return SIMD3<Float>(
            bounds.center.x,
            bounds.center.y + (bounds.extents.y * 0.5) + 0.06,
            bounds.center.z
        )
    }

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

            let shouldRebuildPreview = placementSettings.previewEntity == nil
                || placementSettings.previewModelName != model.name

            if shouldRebuildPreview {
                placementSettings.previewEntity?.removeFromParent()
                let preview = entity.clone(recursive: true)
                makePreviewTransparent(preview)
                preview.generateCollisionShapes(recursive: true)

                placementSettings.previewEntity = preview
                placementSettings.previewModelName = model.name
                placementSettings.lastPreviewTransform = nil
                placementSettings.lastPreviewUpdateTimestamp = 0

                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(preview)

                arView.scene.addAnchor(anchor)
            }

            if let transform = getTransformForPlacement(in: arView) {
                placementSettings.lastPreviewTransform = transform
            }

            if let transform = placementSettings.lastPreviewTransform,
               let preview = placementSettings.previewEntity,
               let anchor = preview.anchor {
                anchor.transform.matrix = transform
            }

         } else {
             placementSettings.previewEntity?.removeFromParent()
             placementSettings.previewEntity = nil
             placementSettings.previewModelName = nil
             placementSettings.lastPreviewTransform = nil
             placementSettings.lastPreviewUpdateTimestamp = 0
             arView.focusEntity?.isEnabled = false
             
         }

        while let modelAnchor = self.placementSettings.modelsConfirmedForPlacement.popLast(),
              let modelEntity = modelAnchor.model.modelEntity {

            if let anchor = modelAnchor.anchor {
                let placed = self.place(modelEntity, for: anchor, in: arView)
                let artifactId = modelAnchor.artifactId ?? "model-anchor-\(anchor.identifier.uuidString)"
                let ownerUid = modelAnchor.ownerUid ?? self.sceneManager.selectedSceneOwnerUid ?? Auth.auth().currentUser?.uid ?? ""
                self.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] = placed.anchorEntity
                if !ownerUid.isEmpty {
                    self.upsertArtifactOwnerBadge(
                        artifactId: artifactId,
                        ownerUid: ownerUid,
                        worldPosition: self.modelBadgeWorldPosition(for: placed.modelEntity),
                        yOffset: -8,
                        on: arView
                    )
                }
                if let artifactId = modelAnchor.artifactId {
                    self.sceneManager.fallbackRestoredModelArtifactIds.insert(artifactId)
                }
                self.sceneManager.markRestoredModelIfAwaiting()

            } else if let transform = getTransformForPlacement(in: arView) {
                let anchorName = anchorNamePrefix + modelAnchor.model.name
                let anchor = ARAnchor(name: anchorName, transform: transform)
                let placed = self.place(modelEntity, for: anchor, in: arView)
                arView.session.add(anchor: anchor)
                self.placementSettings.recentlyPlaced.append(modelAnchor.model)
                let artifactId = modelAnchor.artifactId ?? UUID().uuidString
                let ownerUid = Auth.auth().currentUser?.uid ?? ""
                self.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] = placed.anchorEntity
                if !ownerUid.isEmpty {
                    self.upsertArtifactOwnerBadge(
                        artifactId: artifactId,
                        ownerUid: ownerUid,
                        worldPosition: self.modelBadgeWorldPosition(for: placed.modelEntity),
                        yOffset: -8,
                        on: arView
                    )
                }
                placementSettings.previewEntity?.removeFromParent()
                placementSettings.previewEntity = nil
                placementSettings.previewModelName = nil
                placementSettings.lastPreviewTransform = nil
                placementSettings.lastPreviewUpdateTimestamp = 0
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

                    pbr.blending = .transparent(opacity: .init(floatLiteral: 0.18))
                    newMaterials.append(pbr)

                } else if var simple = material as? SimpleMaterial {

                    simple.color = .init(
                        tint: simple.color.tint,
                        texture: simple.color.texture
                    )
                    simple.color.tint = simple.color.tint.withAlphaComponent(0.18)
                    newMaterials.append(simple)

                } else {
                    var fallback = SimpleMaterial()
                    fallback.color = .init(tint: UIColor.white.withAlphaComponent(0.18), texture: nil)
                    fallback.roughness = .float(1.0)
                    fallback.metallic = .float(0.0)
                    newMaterials.append(fallback)
                }
            }

            modelEntity.model?.materials = newMaterials
        }

        // Recursively apply to children
        for child in entity.children {
            makePreviewTransparent(child)
        }
    }

    @discardableResult
    func place(_ modelEntity: ModelEntity, for anchor: ARAnchor, in arView: ARView) -> (modelEntity: ModelEntity, anchorEntity: AnchorEntity) {

        let clonedEntity = modelEntity.clone(recursive: true)
        clonedEntity.generateCollisionShapes(recursive: true)

        // Save correct scale
        let finalScale = clonedEntity.scale

        // Start hidden
        clonedEntity.scale = .zero

        arView.installGestures([.rotation, .translation], for: clonedEntity)

        let anchorEntity = AnchorEntity(.anchor(identifier: anchor.identifier))
        anchorEntity.addChild(clonedEntity)

        arView.scene.addAnchor(anchorEntity)

        // Animate to correct scale
        clonedEntity.move(
            to: Transform(scale: finalScale),
            relativeTo: clonedEntity.parent,
            duration: 0.2,
            timingFunction: .easeOut
        )

        self.sceneManager.anchorEntities.append(anchorEntity)
        return (clonedEntity, anchorEntity)
    }

    func getTransformForPlacement(in arView: ARView) -> simd_float4x4? {
        if let customARView = arView as? CustomARView,
           let focusEntity = customARView.focusEntity {
            return focusEntity.transformMatrix(relativeTo: nil)
        }
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

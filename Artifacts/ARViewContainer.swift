//
//  ARViewContainer.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {

    // Inputs from SwiftUI
    @Binding var modelName: String
    @Binding var touchLocation: CGPoint?     // where to raycast
    @Binding var placeRequested: Bool        // toggle true to place

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        context.coordinator.arView = arView
        context.coordinator.createReticle()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update reticle on pointer move
        if let p = touchLocation {
            context.coordinator.updateReticle(for: p)
        }

        // Place model when requested
        if placeRequested {
            context.coordinator.placeModel(named: modelName)

            // Reset the flag on the next runloop tick to avoid infinite loop
            DispatchQueue.main.async {
                self.placeRequested = false
            }
        }
    }

    class Coordinator {
        var arView: ARView?
        var reticle: ModelEntity?

        func createReticle() {
            let mesh = MeshResource.generateBox(size: 0.01, cornerRadius: 0.001)
            let mat  = SimpleMaterial(color: .green, isMetallic: false)
            let r = ModelEntity(mesh: mesh, materials: [mat])
            r.isEnabled = false
            self.reticle = r

            if let arView = arView, let reticle = reticle {
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(reticle)
                arView.scene.addAnchor(anchor)
            }
        }

        func updateReticle(for location: CGPoint) {
            guard let arView = arView, let reticle = reticle else { return }

            let results = arView.raycast(from: location,
                                         allowing: .estimatedPlane,
                                         alignment: .horizontal)

            if let hit = results.first {
                // extract translation from the 4x4 matrix
                let t = hit.worldTransform.columns.3
                reticle.position = SIMD3<Float>(t.x, t.y, t.z)
                reticle.isEnabled = true
            } else {
                reticle.isEnabled = false
            }
        }

        func placeModel(named modelName: String) {
            guard let arView = arView,
                  let reticle = reticle,
                  reticle.isEnabled
            else { return }

            // Load the model
            guard let model = try? ModelEntity.loadModel(named: modelName) else { return }

            // Anchor at the current reticle position
            let anchor = AnchorEntity(world: reticle.position)
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)
        }
    }
}

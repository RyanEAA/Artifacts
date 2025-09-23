//
//  ARViewContainer.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

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

        // Add a tap recognizer tied to the coordinator so taps use ARView coordinates reliably
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // keep coordinator aware of the latest model name so tap handler can use it
        context.coordinator.currentModelName = modelName

        if let p = touchLocation, placeRequested {
            context.coordinator.placeModelDirect(at: p, named: modelName)
            DispatchQueue.main.async {
                self.placeRequested = false
            }
        }
    }

    class Coordinator: NSObject {
        var arView: ARView?
        var reticle: ModelEntity?
        // latest model name (kept in sync from updateUIView)
        var currentModelName: String = ""

        // Handle taps coming from the ARView (UIKit recognizer)
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let location = recognizer.location(in: arView)
            // use the current model name
            placeModelDirect(at: location, named: currentModelName)
        }


        func placeModelDirect(at location: CGPoint, named modelName: String){
            guard let arView = arView else {return}

            // raycast from screen point to AR world
            // use .any alignment so vertical signs/models are detected too
            let results = arView.raycast(from: location,
                                         allowing: .estimatedPlane,
                                         alignment: .any)

            guard let hit = results.first else {
                // no plane under the touch
                // can update later for haptic feedback
                print("No surface found at touch location")
                return
            }

            // Load the model
            guard let model = try? ModelEntity.loadModel(named: modelName) else {
                print("Failed to load model named: \(modelName)")
                return
            }

            // enables gesture on the placed model
            model.generateCollisionShapes(recursive: true)
            arView.installGestures([.translation, .rotation,.scale], for: model)

            // anchor model to exact pose returned by ARKit
           if let anchor = try? AnchorEntity(raycastResult: hit){
               anchor.addChild(model)
               arView.scene.addAnchor(anchor)
               return
           }
            // Fallback: position-only (uses worldTransform’s translation)
            let t = hit.worldTransform.columns.3
            let anchor = AnchorEntity(world: SIMD3<Float>(t.x, t.y, t.z))
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)

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

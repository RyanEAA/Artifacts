//
//  ARViewContainer.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI
import RealityKit

// gives us access to tracking real world with device sensors
import ARKit

// creates ARViewContainer and conforms it with UIViewRepresentable protocol

struct ARViewContainer: UIViewRepresentable {
    
    // stores name of 3D model
    @Binding var modelName: String
    
    // resposible for creaing view object
    func makeUIView(context: Context) -> ARView {
        
        // creates arview object to display the rendered 3D model
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()        // this is how we configure what to track
        config.planeDetection = [.horizontal, .vertical]        // allows us to detect flat surfaces
        config.environmentTexturing = .automatic        // gives object realistic lighting
        
        // configures arView instance with config object we created
        arView.session.run(config)
        
        
        return arView
    }
    
    // updates state of specified view
    func updateUIView(_ uiView: ARView, context: Context) {
        
        //  Anchors tell RealityKit how to pin virtual content to real-world objects
        let anchorEntity = AnchorEntity(plane: .any)
        guard let modelEntity = try? Entity.loadModel(named: modelName) else { return }
        
        anchorEntity.addChild(modelEntity)
        uiView.scene.addAnchor(anchorEntity)
    }
    
}

//#Preview {
//    ARViewContainer()
//}

//
//  ARViewContainer.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/23/25.
//
//  Entry point for the AR view. Responsible for creating and configuring
//  the CustomARView and wiring up scene observers.
//

import Foundation
import RealityKit
import SwiftUI
import ARKit
import Combine
import UIKit

// MARK: - Constants (shared across all ARViewContainer files)

let anchorNamePrefix    = "model-"
let annotationNamePrefix = "ann-"
let annotationWidth: CGFloat  = 160
let annotationHeight: CGFloat = 80

// MARK: - ARViewContainer

struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var placementSettings: PlacementSettings
    @EnvironmentObject var sessionSettings: SessionSettings
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @EnvironmentObject var modelDeletionManager: ModelDeletionManager
    @EnvironmentObject var collaborationManager: CollaborationManager

    func makeUIView(context: Context) -> CustomARView {
        let arView = CustomARView(
            frame: .zero,
            sessionSettings: sessionSettings,
            modelDeletionManager: modelDeletionManager
        )
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        // Layout projected 2D annotations every frame
        self.sceneManager.annotationsSceneObserver = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { _ in
            self.layoutAnnotations(on: arView)
        }

        // Global tap recognizer: places/edits annotations when no model is selected
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTapToPlaceAnnotation(_:))
        )
        arView.addGestureRecognizer(tap)

        // Update loop for models + persistence
        self.placementSettings.sceneObserver = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { _ in
            self.updateScene(for: arView)
            self.updatePersistenceAvailability(for: arView)
            self.handlePersistence(for: arView)
        }

        collaborationManager.session = arView.session

        return arView
    }

    func updateUIView(_ uiView: CustomARView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

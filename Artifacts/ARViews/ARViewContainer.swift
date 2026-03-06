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
import Combine
import UIKit

let anchorNamePrefix = "model-"
let annotationNamePrefix = "ann-"
let annotationWidth: CGFloat = 160
let annotationHeight: CGFloat = 80

private extension CustomARView {
    @objc func pauseFromNotification() {
        self.session.pause()
    }

    @objc func resumeFromNotification() {
        self.session.run(self.defaultCofiguration, options: [])
    }
}

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
        
        sceneManager.arView = arView
        
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        startRealtimeAnnotationSyncIfNeeded(on: arView)

        // Layout projected 2D annotations every frame
        self.sceneManager.annotationsSceneObserver = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { _ in
            self.layoutAnnotations(on: arView)
        }

        // Tap recognizer for annotations
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTapToPlaceAnnotation(_:))
        )
        arView.addGestureRecognizer(tap)

        // Drawing: install pan gesture (disabled by default; enabled when tool == .draw)
        installDrawingGesture(on: arView, coordinator: context.coordinator)

        // Drawing: wire undo/clear notifications posted by DrawingToolbarView
        context.coordinator.subscribeToDrawingNotifications(arView: arView)

        // Update loop
        self.placementSettings.sceneObserver = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { _ in
            self.updateScene(for: arView)
            self.updatePersistenceAvailability(for: arView)
            self.handlePersistence(for: arView)
        }

        collaborationManager.session = arView.session

        // Pause/Resume AR when profile sheet shows
        NotificationCenter.default.addObserver(
            arView,
            selector: #selector(CustomARView.pauseFromNotification),
            name: .pauseARSession,
            object: nil
        )
        NotificationCenter.default.addObserver(
            arView,
            selector: #selector(CustomARView.resumeFromNotification),
            name: .resumeARSession,
            object: nil
        )

        return arView
    }

    func updateUIView(_ uiView: CustomARView, context: Context) { 
                // Sync draw gesture enabled/disabled state whenever selectedTool changes
        let isDrawing: Bool
        if case .draw = placementSettings.selectedTool { isDrawing = true } else { isDrawing = false }
        context.coordinator.drawPanGesture?.isEnabled = isDrawing

        // Disable tap recognizer while drawing so finger-drag doesn't fire it
        uiView.gestureRecognizers?
            .compactMap { $0 as? UITapGestureRecognizer }
            .forEach { $0.isEnabled = !isDrawing }
    }

    static func dismantleUIView(_ uiView: CustomARView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.parent.sceneManager.stopAnnotationTextListener()
        NotificationCenter.default.removeObserver(uiView, name: .pauseARSession, object: nil)
        NotificationCenter.default.removeObserver(uiView, name: .resumeARSession, object: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

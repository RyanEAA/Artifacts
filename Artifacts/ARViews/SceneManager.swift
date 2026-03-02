//
//  SceneManager.swift
//  ARTutorial
//
//  Observable state container for the AR scene, including persistence flags,
//  anchor entities, 2D annotation state, and drawing state.
//

import Foundation
import RealityKit
import ARKit
import Combine
import UIKit

// MARK: - SceneManager

class SceneManager: ObservableObject {

    // MARK: Persistence Availability

    @Published var isPersistenceAvailable: Bool = false
    @Published var anchorEntities: [AnchorEntity] = []

    // MARK: Filesystem Persistence Flags

    var shouldSaveSceneToFilesystem: Bool = false
    var shouldLoadSceneToFilesystem: Bool = false

    // MARK: Cloud Persistence Flags

    var shouldSaveSceneToCloud: Bool = false
    var shouldLoadSceneFromCloud: Bool = false
    var selectedCloudSceneId: String?

    // MARK: Local Persistence URL

    lazy var persistenceUrl: URL = {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("arf.persistence")
        } catch {
            fatalError("Unable to get persistenceURL: \(error.localizedDescription)")
        }
    }()

    var scenePersistenceData: Data? {
        try? Data(contentsOf: persistenceUrl)
    }

    // MARK: 2D Annotation State (UITextView-based)

    /// The live UITextView for each annotation, keyed by UUID.
    @Published var annotationViews: [UUID: UITextView] = [:]

    /// The delete button (shown when annotation text is empty), keyed by UUID.
    @Published var deleteButtons: [UUID: UIButton] = [:]

    /// The ARAnchor that positions each annotation in world space.
    var annotationAnchors: [UUID: ARAnchor] = [:]

    /// Tracks which annotation (if any) is currently in edit mode.
    var isEditing: [UUID: Bool] = [:]

    /// Tracks whether the placeholder has been cleared on first tap.
    var hasBeenTapped: [UUID: Bool] = [:]

    /// Text queued for placement at the screen center (from the browse sheet).
    var pendingAnnotationText: String?

    /// Scene-update subscription that drives `layoutAnnotations`.
    var annotationsSceneObserver: Cancellable?

    // MARK: Drawing State

    /// Owns brush color, brush size, stroke history, and undo logic.
    var drawingManager: DrawingManager = DrawingManager()

    /// Single world-space anchor that parents all draw bead entities.
    /// Created lazily on the first bead placed.
    var drawAnchorEntity: AnchorEntity? = nil

    // MARK: Helpers

    func requestAddAnnotation(text: String) {
        pendingAnnotationText = text
    }
}

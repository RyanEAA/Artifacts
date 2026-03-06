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

class SceneManager: ObservableObject {

    @Published var isPersistenceAvailable: Bool = false
    @Published var anchorEntities: [AnchorEntity] = []
    weak var arView: ARView?

    var shouldSaveSceneToFilesystem: Bool = false
    var shouldLoadSceneToFilesystem: Bool = false

    var shouldSaveSceneToCloud: Bool = false
    var shouldLoadSceneFromCloud: Bool = false
    var selectedCloudSceneId: String?

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

    @Published var annotationViews: [UUID: UITextView] = [:]
    @Published var deleteButtons: [UUID: UIButton] = [:]

    var annotationAnchors: [UUID: ARAnchor] = [:]
    var isEditing: [UUID: Bool] = [:]
    var hasBeenTapped: [UUID: Bool] = [:]
    var pendingAnnotationText: String?
    var annotationsSceneObserver: Cancellable?

    // MARK: Drawing State

    /// Owns brush color, brush size, stroke history, and undo logic.
    var drawingManager: DrawingManager = DrawingManager()

    /// Single world-space anchor that parents all draw bead entities.
    /// Created lazily on the first bead placed.
    var drawAnchorEntity: AnchorEntity? = nil

    // Firestore override cache for the currently loading scene.
    // Key is artifactId (UUID string), value is annotationText.
    var annotationTextOverrides: [String: String] = [:]

    func requestAddAnnotation(text: String) {
        pendingAnnotationText = text
    }
}

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
import FirebaseFirestore
import simd

class SceneManager: ObservableObject {

    @Published var isPersistenceAvailable: Bool = false
    @Published var anchorEntities: [AnchorEntity] = []
    weak var arView: ARView?

    var shouldSaveSceneToFilesystem: Bool = false
    var shouldLoadSceneToFilesystem: Bool = false

    var shouldSaveSceneToCloud: Bool = false
    var shouldLoadSceneFromCloud: Bool = false
    var selectedCloudSceneId: String?
    var selectedCloudSceneStoragePath: String?
    var selectedSceneOwnerUid: String?

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
    @Published var artifactOwnerBadgeViews: [String: UILabel] = [:]
    var artifactOwnerBadgeWorldPositions: [String: SIMD3<Float>] = [:]
    var artifactOwnerBadgeOffsetsY: [String: CGFloat] = [:]
    var artifactOwnerBadgeOwnerUids: [String: String] = [:]
    var artifactOwnerUsernames: [String: String] = [:]
    var artifactOwnerUsernameLookupsInFlight: Set<String> = []

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
    var drawingBeadPrototypeCache: [String: ModelEntity] = [:]
    var fallbackArtifactAnchorEntity: AnchorEntity? = nil
    var fallbackRestoredModelArtifactIds: Set<String> = []
    var fallbackRestoredAnnotationArtifactIds: Set<String> = []

    // Firestore override cache for the currently loading scene.
    // Key is artifactId (UUID string), value is annotationText.
    var annotationTextOverrides: [String: String] = [:]
    var annotationTextListener: ListenerRegistration?
    var annotationTextListenerSceneId: String?
    @Published var isPersistenceInProgress: Bool = false
    @Published var persistenceProgressText: String = ""
    @Published var persistenceNotice: PersistenceNotice?
    @Published var isAwaitingVisibleArtifactsAfterLoad: Bool = false
    private var persistenceNoticeWorkItem: DispatchWorkItem?
    private var loadVisibilityTimeoutWorkItem: DispatchWorkItem?
    private var expectedRestoredModelCount: Int = 0
    private var expectedRestoredAnnotationCount: Int = 0
    private var restoredModelCount: Int = 0
    private var restoredAnnotationCount: Int = 0

    func requestAddAnnotation(text: String) {
        pendingAnnotationText = text
    }

    func stopAnnotationTextListener() {
        annotationTextListener?.remove()
        annotationTextListener = nil
        annotationTextListenerSceneId = nil
    }

    func beginPersistenceProgress(_ text: String) {
        DispatchQueue.main.async {
            self.isPersistenceInProgress = true
            self.persistenceProgressText = text
        }
    }

    func updatePersistenceProgress(_ text: String) {
        DispatchQueue.main.async {
            self.persistenceProgressText = text
        }
    }

    func endPersistenceProgress() {
        DispatchQueue.main.async {
            self.isPersistenceInProgress = false
            self.persistenceProgressText = ""
        }
    }

    func postPersistenceNotice(_ message: String, style: PersistenceNoticeStyle) {
        DispatchQueue.main.async {
            self.persistenceNoticeWorkItem?.cancel()
            self.persistenceNotice = PersistenceNotice(message: message, style: style)

            let workItem = DispatchWorkItem { [weak self] in
                self?.persistenceNotice = nil
            }
            self.persistenceNoticeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
        }
    }

    func beginAwaitingVisibleArtifactsAfterLoad(expectedModels: Int, expectedAnnotations: Int) {
        DispatchQueue.main.async {
            self.loadVisibilityTimeoutWorkItem?.cancel()
            self.isAwaitingVisibleArtifactsAfterLoad = true
            self.isPersistenceInProgress = true
            self.persistenceProgressText = "Relocalizing scene..."
            self.expectedRestoredModelCount = max(0, expectedModels)
            self.expectedRestoredAnnotationCount = max(0, expectedAnnotations)
            self.restoredModelCount = 0
            self.restoredAnnotationCount = 0

            if self.expectedRestoredModelCount + self.expectedRestoredAnnotationCount == 0 {
                self.isAwaitingVisibleArtifactsAfterLoad = false
                self.endPersistenceProgress()
                self.postPersistenceNotice("Scene loaded (no artifacts in this map).", style: .info)
            }
        }
    }

    func completeAwaitingVisibleArtifactsAfterLoadIfNeeded() {
        DispatchQueue.main.async {
            guard self.isAwaitingVisibleArtifactsAfterLoad else { return }
            self.loadVisibilityTimeoutWorkItem?.cancel()
            self.loadVisibilityTimeoutWorkItem = nil
            self.isAwaitingVisibleArtifactsAfterLoad = false
            self.endPersistenceProgress()
            self.postPersistenceNotice("Scene loaded and artifacts restored.", style: .success)
        }
    }

    func startLoadVisibilityTimeout(seconds: TimeInterval = 12.0) {
        DispatchQueue.main.async {
            self.loadVisibilityTimeoutWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isAwaitingVisibleArtifactsAfterLoad else { return }
                self.isAwaitingVisibleArtifactsAfterLoad = false
                self.endPersistenceProgress()
                self.postPersistenceNotice(
                    "Scene map loaded. Move your device to relocalize artifacts.",
                    style: .info
                )
            }
            self.loadVisibilityTimeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
        }
    }

    func markRestoredAnnotationIfAwaiting() {
        DispatchQueue.main.async {
            guard self.isAwaitingVisibleArtifactsAfterLoad else { return }
            self.restoredAnnotationCount += 1
            self.evaluateAwaitingLoadCompletion()
        }
    }

    func markRestoredModelIfAwaiting() {
        DispatchQueue.main.async {
            guard self.isAwaitingVisibleArtifactsAfterLoad else { return }
            self.restoredModelCount += 1
            self.evaluateAwaitingLoadCompletion()
        }
    }

    private func evaluateAwaitingLoadCompletion() {
        guard self.isAwaitingVisibleArtifactsAfterLoad else { return }

        let modelsDone = self.restoredModelCount >= self.expectedRestoredModelCount
        let annotationsDone = self.restoredAnnotationCount >= self.expectedRestoredAnnotationCount

        if modelsDone && annotationsDone {
            self.completeAwaitingVisibleArtifactsAfterLoadIfNeeded()
        }
    }
}

enum PersistenceNoticeStyle {
    case info
    case success
    case error
}

struct PersistenceNotice: Identifiable {
    let id = UUID()
    let message: String
    let style: PersistenceNoticeStyle
}

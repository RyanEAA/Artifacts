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
    var pendingArtifactSceneId: String?
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
    var quickDeleteButton: UIButton?
    @Published var selectedArtifactForQuickDelete: String?
    var deletedArtifactIds: Set<String> = []
    var pendingArtifactSaveTasks: [String: Task<Void, Never>] = [:]
    @Published var artifactOwnerBadgeViews: [String: UILabel] = [:]
    var artifactOwnerBadgeWorldPositions: [String: SIMD3<Float>] = [:]
    var artifactOwnerBadgeOffsetsY: [String: CGFloat] = [:]
    var artifactOwnerBadgeOwnerUids: [String: String] = [:]
    var artifactOwnerUsernames: [String: String] = [:]
    var artifactOwnerUsernameLookupsInFlight: Set<String> = []
    var drawingBadgeMembersById: [String: [String]] = [:]

    var annotationAnchors: [UUID: ARAnchor] = [:]
    var locallyPlacedAnnotationIDs: Set<UUID> = []
    var isEditing: [UUID: Bool] = [:]
    var hasBeenTapped: [UUID: Bool] = [:]
    var annotationColors: [UUID: UIColor] = [:]
    @Published var activeAnnotationEditingId: UUID?
    @Published var activeAnnotationColor: UIColor = SceneManager.defaultAnnotationColor
    var pendingAnnotationText: String?
    var annotationsSceneObserver: Cancellable?

    // MARK: Drawing State

    /// Owns brush color, brush size, stroke history, and undo logic.
    var drawingManager: DrawingManager = DrawingManager()

    /// Single world-space anchor that parents all stroke entities.
    /// Created lazily on the first stroke geometry placed.
    var drawAnchorEntity: AnchorEntity? = nil
    var drawingStrokePrototypeCache: [String: ModelEntity] = [:]
    var fallbackArtifactAnchorEntity: AnchorEntity? = nil
    var fallbackRestoredModelArtifactIds: Set<String> = []
    var fallbackRestoredAnnotationArtifactIds: Set<String> = []
    var loadVisibleModelRecords: [ModelArtifactRecord] = []
    var loadVisibleAnnotationArtifactIDs: Set<String> = []
    var loadVisibleAnnotationOwnerUIDs: [String: String] = [:]
    var isLoadArtifactFilterActive: Bool = false
    var modelAnchorEntitiesByArtifactId: [String: AnchorEntity] = [:]
    var modelArtifactNamesById: [String: String] = [:]
    var fallbackModelEntitiesByArtifactId: [String: Entity] = [:]
    var locallyPlacedModelAnchorIDs: Set<UUID> = []

    // Firestore override cache for the currently loading scene.
    // Key is artifactId (UUID string), value is annotationText.
    var annotationTextOverrides: [String: String] = [:]
    var annotationColorOverrides: [String: String] = [:]
    var annotationTextListener: ListenerRegistration?
    var annotationTextListenerSceneId: String?
    @Published var isPersistenceInProgress: Bool = false
    @Published var persistenceProgressText: String = ""
    @Published var persistenceNotice: PersistenceNotice?
    @Published var isAwaitingVisibleArtifactsAfterLoad: Bool = false
    var onVisibleArtifactsReady: (() -> Void)?
    private var persistenceNoticeWorkItem: DispatchWorkItem?
    private var loadVisibilityTimeoutWorkItem: DispatchWorkItem?
    private var loadFilterResetWorkItem: DispatchWorkItem?
    private(set) var visibleArtifactLoadToken: UUID = UUID()
    private var expectedRestoredModelCount: Int = 0
    private var expectedRestoredAnnotationCount: Int = 0
    private var expectedRestoredDrawingCount: Int = 0
    private var restoredModelCount: Int = 0
    private var restoredAnnotationCount: Int = 0
    private var restoredDrawingCount: Int = 0
    private var isLoadRelocalizationSatisfied: Bool = true

    static var defaultAnnotationColor: UIColor {
        UIColor(named: "MintGreen") ?? .systemMint
    }

    func annotationColor(for id: UUID) -> UIColor {
        annotationColors[id] ?? Self.defaultAnnotationColor
    }

    func updateActiveAnnotationColor(_ color: UIColor) {
        activeAnnotationColor = color
        guard let id = activeAnnotationEditingId else { return }
        annotationColors[id] = color
        if let tv = annotationViews[id] {
            applyAnnotationStyle(
                to: tv,
                color: color,
                isEditing: isEditing[id] ?? false
            )
        }
        NotificationCenter.default.post(
            name: .annotationColorChanged,
            object: nil,
            userInfo: [
                "annotationId": id,
                "annotationColor": color
            ]
        )
    }

    func applyAnnotationStyle(to textView: UITextView, color: UIColor, isEditing: Bool) {
        textView.backgroundColor = color.withAlphaComponent(0.92)
        textView.textColor = preferredAnnotationTextColor(for: color)
        textView.layer.cornerRadius = 14
        textView.layer.masksToBounds = true
        textView.layer.borderWidth = isEditing ? 2 : 1
        textView.layer.borderColor = isEditing
            ? UIColor.systemBlue.cgColor
            : color.withAlphaComponent(0.35).cgColor
    }

    func clearActiveAnnotationEditingState() {
        activeAnnotationEditingId = nil
        activeAnnotationColor = Self.defaultAnnotationColor
    }

    private func preferredAnnotationTextColor(for color: UIColor) -> UIColor {
        var r: CGFloat = 1
        var g: CGFloat = 1
        var b: CGFloat = 1
        var a: CGFloat = 1
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return UIColor.black.withAlphaComponent(0.92)
        }
        let luminance = (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
        if luminance < 0.55 {
            return UIColor.white.withAlphaComponent(0.95)
        }
        return UIColor.black.withAlphaComponent(0.92)
    }

    func requestAddAnnotation(text: String) {
        pendingAnnotationText = text
    }

    func stopAnnotationTextListener() {
        annotationTextListener?.remove()
        annotationTextListener = nil
        annotationTextListenerSceneId = nil
    }

    func resetLoadArtifactFilters() {
        loadFilterResetWorkItem?.cancel()
        loadFilterResetWorkItem = nil
        loadVisibleModelRecords = []
        loadVisibleAnnotationArtifactIDs = []
        loadVisibleAnnotationOwnerUIDs = [:]
        annotationColorOverrides = [:]
        isLoadArtifactFilterActive = false
    }

    @discardableResult
    func beginVisibleArtifactLoadCycle() -> UUID {
        let token = UUID()
        visibleArtifactLoadToken = token
        return token
    }

    func invalidateVisibleArtifactLoadCycle() {
        visibleArtifactLoadToken = UUID()
        loadVisibilityTimeoutWorkItem?.cancel()
        loadVisibilityTimeoutWorkItem = nil
        loadFilterResetWorkItem?.cancel()
        loadFilterResetWorkItem = nil
        isAwaitingVisibleArtifactsAfterLoad = false
        onVisibleArtifactsReady = nil
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

    func beginAwaitingVisibleArtifactsAfterLoad(expectedModels: Int, expectedAnnotations: Int, expectedDrawings: Int) {
        DispatchQueue.main.async {
            self.loadVisibilityTimeoutWorkItem?.cancel()
            self.isAwaitingVisibleArtifactsAfterLoad = true
            self.isPersistenceInProgress = true
            self.persistenceProgressText = "Relocalizing scene..."
            self.expectedRestoredModelCount = max(0, expectedModels)
            self.expectedRestoredAnnotationCount = max(0, expectedAnnotations)
            self.expectedRestoredDrawingCount = max(0, expectedDrawings)
            self.restoredModelCount = 0
            self.restoredAnnotationCount = 0
            self.restoredDrawingCount = 0
            self.isLoadRelocalizationSatisfied = false

            if self.expectedRestoredModelCount + self.expectedRestoredAnnotationCount + self.expectedRestoredDrawingCount == 0 {
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
            self.anchorEntities.forEach { $0.isEnabled = true }
            self.drawAnchorEntity?.isEnabled = true
            self.fallbackArtifactAnchorEntity?.isEnabled = true
            self.isAwaitingVisibleArtifactsAfterLoad = false
            self.onVisibleArtifactsReady?()
            self.scheduleLoadFilterReset()
            DispatchQueue.main.async {
                self.endPersistenceProgress()
                self.postPersistenceNotice("Scene loaded and artifacts restored.", style: .success)
            }
        }
    }

    func startLoadVisibilityTimeout(seconds: TimeInterval = 12.0) {
        DispatchQueue.main.async {
            self.loadVisibilityTimeoutWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isAwaitingVisibleArtifactsAfterLoad else { return }
                self.anchorEntities.forEach { $0.isEnabled = true }
                self.drawAnchorEntity?.isEnabled = true
                self.fallbackArtifactAnchorEntity?.isEnabled = true
                self.isAwaitingVisibleArtifactsAfterLoad = false
                self.onVisibleArtifactsReady?()
                self.scheduleLoadFilterReset()
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

    func markRestoredDrawingIfAwaiting() {
        DispatchQueue.main.async {
            guard self.isAwaitingVisibleArtifactsAfterLoad else { return }
            self.restoredDrawingCount += 1
            self.evaluateAwaitingLoadCompletion()
        }
    }

    private func evaluateAwaitingLoadCompletion() {
        guard self.isAwaitingVisibleArtifactsAfterLoad else { return }

        let modelsDone = self.restoredModelCount >= self.expectedRestoredModelCount
        let annotationsDone = self.restoredAnnotationCount >= self.expectedRestoredAnnotationCount
        let drawingsDone = self.restoredDrawingCount >= self.expectedRestoredDrawingCount

        if modelsDone && annotationsDone && drawingsDone && self.isLoadRelocalizationSatisfied {
            self.completeAwaitingVisibleArtifactsAfterLoadIfNeeded()
        }
    }

    func areModelAndAnnotationRestoresSatisfied() -> Bool {
        let modelsDone = self.restoredModelCount >= self.expectedRestoredModelCount
        let annotationsDone = self.restoredAnnotationCount >= self.expectedRestoredAnnotationCount
        return modelsDone && annotationsDone
    }

    func isAwaitingOnlyDrawingsAfterLoad() -> Bool {
        isAwaitingVisibleArtifactsAfterLoad
            && expectedRestoredModelCount == 0
            && expectedRestoredAnnotationCount == 0
            && expectedRestoredDrawingCount > 0
    }

    func updateLoadRelocalizationState(for trackingState: ARCamera.TrackingState) {
        DispatchQueue.main.async {
            guard self.isAwaitingVisibleArtifactsAfterLoad else { return }

            switch trackingState {
            case .normal:
                self.isLoadRelocalizationSatisfied = true
            case .limited(.relocalizing):
                self.isLoadRelocalizationSatisfied = false
            default:
                break
            }

            self.evaluateAwaitingLoadCompletion()
        }
    }

    private func scheduleLoadFilterReset(after seconds: TimeInterval = 2.0) {
        loadFilterResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.resetLoadArtifactFilters()
        }
        loadFilterResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
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

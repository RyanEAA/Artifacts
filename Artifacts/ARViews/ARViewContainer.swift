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

private let anchorNamePrefix = "model-"
private let annotationNamePrefix = "ann-"
private let annotationWidth: CGFloat = 160
private let annotationHeight: CGFloat = 80

struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var placementSettings: PlacementSettings
    @EnvironmentObject var sessionSettings: SessionSettings
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @EnvironmentObject var modelDeletionManager: ModelDeletionManager
    
    func makeUIView(context: Context) -> CustomARView {
        let arView = CustomARView(frame: .zero,
                                  sessionSettings: sessionSettings,
                                  modelDeletionManager: modelDeletionManager)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        
        // Layout projected 2D annotations every frame (repositions UITextViews + Delete buttons)
        self.sceneManager.annotationsSceneObserver = arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
            self.layoutAnnotations(on: arView)
        }

        // Global tap recognizer: places/edits annotations when NO model is selected
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTapToPlaceAnnotation(_:)))
        arView.addGestureRecognizer(tap)

        // Existing update loop for models + persistence
        self.placementSettings.sceneObserver = arView.scene.subscribe(to: SceneEvents.Update.self, { _ in
            self.updateScene(for: arView)
            self.updatePersistenceAvailability(for: arView)
            self.handlePersistence(for: arView)
        })

        // Track which scene should sync artifacts once relocalized
        let sceneId = self.sceneManager.getOrCreateSceneId()
        self.sceneManager.pendingSceneIdForArtifacts = sceneId
        self.sceneManager.hasStartedArtifactSync = false
        self.sceneManager.hasRelocalizedForArtifacts = false
        self.sceneManager.artifactIds.removeAll()
        self.sceneManager.artifactIdToAnchorId.removeAll()
        self.sceneManager.shouldAttemptSceneAutoMatch = true

        // On cold start, automatically load the last cloud scene if one exists
        if self.sceneManager.shouldAutoloadLastScene {
            self.sceneManager.shouldAutoloadLastScene = false
            self.sceneManager.shouldLoadSceneFromCloud = true
        }
        
        // Artifacts will begin syncing once the session relocalizes to the scene
        
        return arView
    }
    
    func updateUIView(_ uiView: CustomARView, context: Context) { }
    
    private func updateScene(for arView: CustomARView){
        // Only display focusEntity when the user has a model selected
        arView.focusEntity?.isEnabled = self.placementSettings.selectedModel != nil
        
        // Add model to the scene
        if let modelAnchor = self.placementSettings.modelsConfirmedForPlacement.popLast(),
           let modelEntity = modelAnchor.model.modelEntity {
            if let anchor = modelAnchor.anchor {
                self.place(modelEntity, for: anchor, in: arView)
            } else if let transform = getTransformForPlacement(in: arView) {
                let anchorName = anchorNamePrefix + modelAnchor.model.name
                let anchor = ARAnchor(name: anchorName, transform: transform)
                self.place(modelEntity, for: anchor, in: arView)
                arView.session.add(anchor: anchor)
                self.placementSettings.recentlyPlaced.append(modelAnchor.model)
            }
        }
        
        // Handle any pending 2D annotation placement requests (from the “2D Annotation” tile)
        self.placePendingAnnotationIfNeeded(on: arView)
    }
    
    // MARK: - 2D Annotation Support (UITextView behavior like AnnotationsView.swift)
    
    struct AnnotationData: Codable {
        let id: UUID
        var text: String
    }

    // Factory to create a styled UITextView like AnnotationsView.swift
    private func makeTextView(id: UUID, text: String) -> UITextView {
        let tv = UITextView(frame: .zero)
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        tv.text = isEmpty ? "Tap to Edit" : text
        // Typography
        tv.font = .systemFont(ofSize: 16, weight: .medium)
        // Layout & shape
        tv.textAlignment = .center
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        // Color to match AnnotationsView
        tv.backgroundColor = UIColor.mintGreen.withAlphaComponent(0.9)
        // Slightly more rectangular than pill
        tv.layer.cornerRadius = 8
        tv.layer.masksToBounds = true
        // Interaction
        tv.isScrollEnabled = false
        tv.isEditable = false
        tv.isUserInteractionEnabled = false // only while editing
        // Fixed size for annotations
        tv.bounds.size = CGSize(width: annotationWidth, height: annotationHeight)
        return tv
    }

    // Create and attach the UITextView for an ARAnchor
    private func attachAnnotationView(for anchor: ARAnchor, data: AnnotationData, on arView: ARView) {
        if self.sceneManager.annotationViews[data.id] != nil { return }
        let tv = makeTextView(id: data.id, text: data.text)
        // Ensure live editing updates (e.g., show delete when text becomes empty)
        if let coord = (arView.session.delegate as? Coordinator) {
            tv.delegate = coord
        }
        arView.addSubview(tv)
        self.sceneManager.annotationViews[data.id] = tv
        self.sceneManager.annotationAnchors[data.id] = anchor
        self.sceneManager.isEditing[data.id] = false
        // If text is empty at creation, it hasn't been tapped yet (will clear placeholder on first edit)
        let hasText = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.sceneManager.hasBeenTapped[data.id] = hasText
        animatePopIn(tv)
    }

    // Project world positions and layout text views + delete buttons
    private func layoutAnnotations(on arView: ARView) {
        guard let frame = arView.session.currentFrame else { return }
        for (id, anchor) in self.sceneManager.annotationAnchors {
            let pos = SIMD3<Float>(anchor.transform.columns.3.x,
                                   anchor.transform.columns.3.y,
                                   anchor.transform.columns.3.z)
            if let p = arView.project(pos) {
                if let tv = self.sceneManager.annotationViews[id] {
                    let camZ = simd_mul(frame.camera.transform, SIMD4<Float>(pos.x, pos.y, pos.z, 1)).z
                    tv.isHidden = camZ > 0
                    tv.bounds.size = CGSize(width: annotationWidth, height: annotationHeight)
                    tv.center = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y) - 20)
                    if let btn = self.sceneManager.deleteButtons[id], !btn.isHidden {
                        let f = tv.frame
                        btn.bounds.size = CGSize(width: 80, height: 32)
                        btn.center = CGPoint(x: f.midX, y: f.maxY + 8 + btn.bounds.height/2)
                    }
                }
            } else {
                self.sceneManager.annotationViews[id]?.isHidden = true
                self.sceneManager.deleteButtons[id]?.isHidden = true
            }
        }
    }

    // Encode/Decode payload into ARAnchor.name for Cloud persistence
    private func encodeAnnotation(_ data: AnnotationData) -> String {
        let enc = JSONEncoder()
        if let d = try? enc.encode(data) {
            return Data(d).base64EncodedString()
        }
        return ""
    }

    private func decodeAnnotation(from base64: String) -> AnnotationData? {
        guard let d = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(AnnotationData.self, from: d)
    }

    // Pop-in animation used when opening or creating annotations
    private func animatePopIn(_ view: UIView) {
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        view.alpha = 0
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: [.curveEaseOut],
                       animations: {
            view.transform = .identity
            view.alpha = 1
        }, completion: nil)
    }

    // Pop-out animation for removing annotation views/buttons
    private func animatePopOut(_ view: UIView, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.20, delay: 0, options: [.curveEaseIn], animations: {
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            view.alpha = 0
        }, completion: { _ in
            completion?()
        })
    }

    private func showDeleteButton(for id: UUID, on arView: ARView) {
        guard let tv = self.sceneManager.annotationViews[id] else { return }
        let button: UIButton
        if let existing = self.sceneManager.deleteButtons[id] {
            button = existing
        } else {
            let btn = UIButton(type: .system)
            btn.setTitle("Delete", for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
            btn.layer.cornerRadius = 6
            btn.layer.masksToBounds = true
            // We route target/action via Coordinator
            (arView.session.delegate as? Coordinator)?.registerDeleteButton(btn, for: id)
            self.sceneManager.deleteButtons[id] = btn
            arView.addSubview(btn)
            button = btn
        }
        button.isHidden = false
        // Position will be finalized in layoutAnnotations (called every frame)
        let f = tv.frame
        button.bounds.size = CGSize(width: 80, height: 32)
        button.center = CGPoint(x: f.midX, y: f.maxY + 8 + button.bounds.height/2)
    }

    private func hideDeleteButton(for id: UUID) {
        self.sceneManager.deleteButtons[id]?.isHidden = true
    }

    // Place pending (centered) request from browse sheet
    fileprivate func placePendingAnnotationIfNeeded(on arView: ARView) {
        guard let text = self.sceneManager.pendingAnnotationText else { return }
        guard let transform = getTransformForPlacement(in: arView) else { return }
        let id = UUID()
        let payload = AnnotationData(id: id, text: text)
        let name = annotationNamePrefix + encodeAnnotation(payload)
        let anchor = ARAnchor(name: name, transform: transform)
        arView.session.add(anchor: anchor)
        attachAnnotationView(for: anchor, data: payload, on: arView)
        self.sceneManager.hasBeenTapped[id] = false
        self.sceneManager.pendingAnnotationText = nil
    }
    
    // Place at an arbitrary tap point
    fileprivate func placeAnnotation(at point: CGPoint, on arView: ARView) {
        let text = (self.sceneManager.pendingAnnotationText?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Tap to Edit"
        guard let transform = getTransformForPlacement(in: arView, at: point) else { return }
        let id = UUID()
        let payload = AnnotationData(id: id, text: text == "Tap to Edit" ? "" : text)
        let name = annotationNamePrefix + encodeAnnotation(payload)
        let anchor = ARAnchor(name: name, transform: transform)
        arView.session.add(anchor: anchor)
        attachAnnotationView(for: anchor, data: payload, on: arView)
        self.sceneManager.hasBeenTapped[id] = (text != "Tap to Edit")
        self.sceneManager.pendingAnnotationText = nil
    }
    
    private func place(_ modelEntity: ModelEntity, for anchor: ARAnchor, in arView: ARView) {
        let clonedEntity = modelEntity.clone(recursive: true)
        clonedEntity.generateCollisionShapes(recursive: true)
        
        // Install gestures and track changes for automatic saving
        arView.installGestures([.rotation, .translation], for: clonedEntity)
        self.setupGestureTracking(for: clonedEntity, anchor: anchor, in: arView)
        
        let anchorEntity = AnchorEntity(plane: .any)
        anchorEntity.addChild(clonedEntity)
        anchorEntity.anchoring = AnchoringComponent(anchor)
        arView.scene.addAnchor(anchorEntity)
        self.sceneManager.anchorEntities.append(anchorEntity)
        
        // Automatically save to Firebase using the entity's world transform (anchors don't move with gestures)
        let worldTransform = clonedEntity.transformMatrix(relativeTo: nil)
        self.saveModelArtifact(anchor: anchor, modelName: anchor.name?.replacingOccurrences(of: anchorNamePrefix, with: "") ?? "unknown", transform: worldTransform)
    }
    
    // MARK: - Firebase Auto-Save Methods
    
    private func saveModelArtifact(anchor: ARAnchor, modelName: String, transform: simd_float4x4) {
        let sceneId = sceneManager.getOrCreateSceneId()
        let artifactId = UUID().uuidString
        
        // Track the artifact ID
        sceneManager.artifactIds[anchor.identifier] = artifactId
        sceneManager.artifactIdToAnchorId[artifactId] = anchor.identifier
        
        ArtifactSyncService.shared.saveArtifact(
            id: artifactId,
            type: .model,
            sceneId: sceneId,
            transform: transform,
            modelName: modelName
        ) { result in
            switch result {
            case .success:
                print("✅ Auto-saved model artifact: \(artifactId)")
            case .failure(let error):
                print("❌ Failed to auto-save model artifact: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveAnnotationArtifact(anchor: ARAnchor, annotationId: UUID, text: String, transform: simd_float4x4) {
        let sceneId = sceneManager.getOrCreateSceneId()
        let artifactId = UUID().uuidString
        
        // Track the artifact ID
        sceneManager.artifactIds[anchor.identifier] = artifactId
        sceneManager.artifactIdToAnchorId[artifactId] = anchor.identifier
        
        ArtifactSyncService.shared.saveArtifact(
            id: artifactId,
            type: .annotation,
            sceneId: sceneId,
            transform: transform,
            annotationText: text
        ) { result in
            switch result {
            case .success:
                print("✅ Auto-saved annotation artifact: \(artifactId)")
            case .failure(let error):
                print("❌ Failed to auto-save annotation artifact: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateArtifact(anchor: ARAnchor, transform: simd_float4x4? = nil, annotationText: String? = nil) {
        guard let artifactId = sceneManager.artifactIds[anchor.identifier] else {
            print("⚠️ No artifact ID found for anchor: \(anchor.identifier)")
            return
        }
        
        ArtifactSyncService.shared.updateArtifact(
            id: artifactId,
            transform: transform,
            annotationText: annotationText
        ) { result in
            switch result {
            case .success:
                print("✅ Auto-updated artifact: \(artifactId)")
            case .failure(let error):
                print("❌ Failed to auto-update artifact: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteArtifact(anchor: ARAnchor) {
        guard let artifactId = sceneManager.artifactIds[anchor.identifier] else {
            print("⚠️ No artifact ID found for anchor: \(anchor.identifier)")
            return
        }
        
        ArtifactSyncService.shared.deleteArtifact(id: artifactId) { result in
            switch result {
            case .success:
                print("✅ Auto-deleted artifact: \(artifactId)")
                // Clean up tracking
                self.sceneManager.artifactIds.removeValue(forKey: anchor.identifier)
                self.sceneManager.artifactIdToAnchorId.removeValue(forKey: artifactId)
            case .failure(let error):
                print("❌ Failed to auto-delete artifact: \(error.localizedDescription)")
            }
        }
    }
    
    // Track gesture changes for automatic saving
    private func setupGestureTracking(for entity: ModelEntity, anchor: ARAnchor, in arView: ARView) {
        // Use a debounced approach to track transform changes, based on the entity's world transform
        var lastSavedTransform = entity.transformMatrix(relativeTo: nil)
        var updateTimer: Timer?
        
        // Capture sceneManager for use in closures (structs don't need weak references)
        let manager = sceneManager
        
        // Subscribe to scene updates to check for transform changes
        _ = arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
            // Check current world transform from the entity (gestures apply to the entity, not the anchor)
            let currentTransform = entity.transformMatrix(relativeTo: nil)
            
            // Check if transform changed significantly (more than 1cm)
            let positionDiff = simd_length(currentTransform.columns.3 - lastSavedTransform.columns.3)
            
            if positionDiff > 0.01 { // 1cm threshold
                // Cancel previous timer
                updateTimer?.invalidate()
                
                // Debounce: wait 0.5 seconds after last change before saving
                updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    let finalTransform = entity.transformMatrix(relativeTo: nil)
                    // Update artifact using captured sceneManager
                    if let artifactId = manager.artifactIds[anchor.identifier] {
                        ArtifactSyncService.shared.updateArtifact(
                            id: artifactId,
                            transform: finalTransform,
                            annotationText: nil
                        ) { result in
                            switch result {
                            case .success:
                                print("✅ Auto-updated artifact: \(artifactId)")
                            case .failure(let error):
                                print("❌ Failed to auto-update artifact: \(error.localizedDescription)")
                            }
                        }
                    }
                    lastSavedTransform = finalTransform
                }
            }
        }
        
        // For now, the timer will be cleaned up when the entity is removed
    }
    
    // MARK: - Real-time Firebase Syncing
    
    private func setupFirebaseListener(sceneId: String, arView: ARView) {
        ArtifactSyncService.shared.startListeningToScene(sceneId: sceneId,
            onUpdate: { artifacts in
                DispatchQueue.main.async {
                    self.handleFirebaseArtifactUpdates(artifacts: artifacts, in: arView)
                }
            },
            onError: { error in
                print("❌ Firebase listener error: \(error.localizedDescription)")
            }
        )
    }
    
    private func handleFirebaseArtifactUpdates(artifacts: [ArtifactData], in arView: ARView) {
        // Avoid applying remote artifacts until we're relocalized to the scene
        guard sceneManager.hasStartedArtifactSync else { return }

        // Get current artifact IDs from Firebase
        let firebaseArtifactIds = Set(artifacts.map { $0.id })
        
        // Get local artifact IDs
        let localArtifactIds = Set(sceneManager.artifactIdToAnchorId.keys)
        
        // Find artifacts that were deleted remotely
        let deletedIds = localArtifactIds.subtracting(firebaseArtifactIds)
        for artifactId in deletedIds {
            if let anchorId = sceneManager.artifactIdToAnchorId[artifactId],
               let anchor = arView.session.currentFrame?.anchors.first(where: { $0.identifier == anchorId }) {
                // Remove the anchor and entity
                self.removeArtifactLocally(anchor: anchor, in: arView)
            }
        }
        
        // Process updates and new artifacts
        for artifact in artifacts {
            // Skip if this is our own artifact (to avoid conflicts)
            if sceneManager.artifactIdToAnchorId[artifact.id] != nil {
                // Update existing artifact if transform changed
                if let anchorId = sceneManager.artifactIdToAnchorId[artifact.id],
                   let anchor = arView.session.currentFrame?.anchors.first(where: { $0.identifier == anchorId }),
                   let newTransform = ArtifactData.arrayToTransform(artifact.transform ?? []) {
                    // Only update if transform is significantly different
                    let currentTransform = anchor.transform
                    let positionDiff = simd_length(newTransform.columns.3 - currentTransform.columns.3)
                    if positionDiff > 0.01 {
                        // Update the anchor transform (this will be handled by ARKit automatically)
                        // For now, we'll let ARKit handle it through the world map
                    }
                }
                continue
            }
            
            // New artifact from another user - add it locally
            if let transform = ArtifactData.arrayToTransform(artifact.transform ?? []) {
                self.addRemoteArtifact(artifact: artifact, transform: transform, in: arView)
            }
        }
    }
    
    private func removeArtifactLocally(anchor: ARAnchor, in arView: ARView) {
        // Remove model entity if it's a model
        if let anchorName = anchor.name, anchorName.hasPrefix(anchorNamePrefix) {
            // Find anchor entity by matching the anchor name
            // Since we store anchor entities with the same name pattern, we can match by name
            // or by finding the anchor entity whose transform matches the ARAnchor's transform
            if let index = sceneManager.anchorEntities.firstIndex(where: { anchorEntity in
                // Match by checking if the anchor entity's position is close to the ARAnchor's position
                let entityTransform = anchorEntity.transformMatrix(relativeTo: nil)
                let anchorTransform = anchor.transform
                let entityPos = SIMD3<Float>(entityTransform.columns.3.x, entityTransform.columns.3.y, entityTransform.columns.3.z)
                let anchorPos = SIMD3<Float>(anchorTransform.columns.3.x, anchorTransform.columns.3.y, anchorTransform.columns.3.z)
                let positionDiff = simd_length(entityPos - anchorPos)
                return positionDiff < 0.05 // 5cm threshold for matching
            }) {
                sceneManager.anchorEntities[index].removeFromParent()
                sceneManager.anchorEntities.remove(at: index)
            }
        }
        
        // Remove annotation if it's an annotation
        if let anchorName = anchor.name, anchorName.hasPrefix(annotationNamePrefix) {
            // Find annotation by anchor identifier
            if let (id, _) = sceneManager.annotationAnchors.first(where: { $0.value.identifier == anchor.identifier }) {
                sceneManager.annotationViews[id]?.removeFromSuperview()
                sceneManager.deleteButtons[id]?.removeFromSuperview()
                sceneManager.annotationViews.removeValue(forKey: id)
                sceneManager.deleteButtons.removeValue(forKey: id)
                sceneManager.annotationAnchors.removeValue(forKey: id)
                sceneManager.isEditing.removeValue(forKey: id)
                sceneManager.hasBeenTapped.removeValue(forKey: id)
            }
        }
        
        // Clean up tracking
        if let artifactId = sceneManager.artifactIds[anchor.identifier] {
            sceneManager.artifactIds.removeValue(forKey: anchor.identifier)
            sceneManager.artifactIdToAnchorId.removeValue(forKey: artifactId)
        }
        
        arView.session.remove(anchor: anchor)
    }
    
    private func addRemoteArtifact(artifact: ArtifactData, transform: simd_float4x4, in arView: ARView) {
        switch artifact.type {
        case .model:
            // Create ARAnchor for model
            let modelName = artifact.modelName ?? "unknown"
            let anchorName = anchorNamePrefix + modelName
            let anchor = ARAnchor(name: anchorName, transform: transform)
            arView.session.add(anchor: anchor)
            
            // Track the artifact ID after anchor is created
            sceneManager.artifactIds[anchor.identifier] = artifact.id
            sceneManager.artifactIdToAnchorId[artifact.id] = anchor.identifier
            
            // Load and place the model
            if let model = modelsViewModel.models.first(where: { $0.name == modelName }) {
                if model.modelEntity != nil {
                    let modelAnchor = ModelAnchor(model: model, anchor: anchor)
                    placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
                } else {
                    model.asyncLoadModelEntity { completed, error in
                        guard completed else { return }
                        let modelAnchor = ModelAnchor(model: model, anchor: anchor)
                        self.placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
                    }
                }
            }
            
        case .annotation:
            // Create ARAnchor for annotation
            let annotationText = artifact.annotationText ?? ""
            let annotationId = UUID()
            let payload = AnnotationData(id: annotationId, text: annotationText)
            let name = annotationNamePrefix + encodeAnnotation(payload)
            let anchor = ARAnchor(name: name, transform: transform)
            arView.session.add(anchor: anchor)
            
            // Track the artifact ID after anchor is created
            sceneManager.artifactIds[anchor.identifier] = artifact.id
            sceneManager.artifactIdToAnchorId[artifact.id] = anchor.identifier
            
            attachAnnotationView(for: anchor, data: payload, on: arView)
            sceneManager.hasBeenTapped[annotationId] = !annotationText.isEmpty
        }
    }
    
    private func getTransformForPlacement(in arView: ARView) -> simd_float4x4? {
        let center = arView.center
        let preferredQuery = arView.makeRaycastQuery(from: center, allowing: .existingPlaneGeometry, alignment: .any)
        let fallbackQuery = arView.makeRaycastQuery(from: center, allowing: .estimatedPlane, alignment: .any)
        let result = preferredQuery.flatMap { arView.session.raycast($0).first } ??
                     fallbackQuery.flatMap { arView.session.raycast($0).first }
        return result?.worldTransform
    }
    
    private func getTransformForPlacement(in arView: ARView, at point: CGPoint) -> simd_float4x4? {
        let preferredQuery = arView.makeRaycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .any)
        let fallbackQuery = arView.makeRaycastQuery(from: point, allowing: .estimatedPlane, alignment: .any)
        let result = preferredQuery.flatMap { arView.session.raycast($0).first } ??
                     fallbackQuery.flatMap { arView.session.raycast($0).first }
        return result?.worldTransform
    }
}

// MARK: - Persistence

class SceneManager: ObservableObject {
    @Published var isPersistenceAvailable: Bool = false
    @Published var anchorEntities: [AnchorEntity] = []
    
    var shouldSaveSceneToFilesystem: Bool = false
    var shouldLoadSceneToFilesystem: Bool = false

    var shouldSaveSceneToCloud = false
    var shouldLoadSceneFromCloud = false
    var selectedCloudSceneId: String? {
        didSet {
            // Persist scene ID to UserDefaults
            if let sceneId = selectedCloudSceneId {
                UserDefaults.standard.set(sceneId, forKey: "currentSceneId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentSceneId")
            }
        }
    }
    
    // Track artifact IDs for Firebase syncing
    // Maps ARAnchor identifier to artifact ID (UUID string)
    var artifactIds: [UUID: String] = [:]
    // Maps artifact ID to ARAnchor identifier
    var artifactIdToAnchorId: [String: UUID] = [:]

    // Artifact sync gating (ensures relocalization before loading/streaming)
    var pendingSceneIdForArtifacts: String?
    var hasRelocalizedForArtifacts: Bool = false
    var hasStartedArtifactSync: Bool = false
    var shouldAttemptSceneAutoMatch: Bool = false
    var autoMatchCandidates: [CloudSceneMeta] = []
    var autoMatchIndex: Int = 0
    var autoMatchAttemptInProgress: Bool = false
    var autoMatchTimer: Timer?
    var autoMatchCurrentSceneIdCandidate: String?

    // Auto-load state for last scene on cold start
    var shouldAutoloadLastScene: Bool = false
    
    init() {
        // Load scene ID from UserDefaults on init
        if let savedSceneId = UserDefaults.standard.string(forKey: "currentSceneId") {
            self.selectedCloudSceneId = savedSceneId
            self.shouldAutoloadLastScene = true
        }
    }
    
    func getOrCreateSceneId() -> String {
        if let existingId = selectedCloudSceneId {
            return existingId
        }
        // Create new scene ID
        let newSceneId = UUID().uuidString
        selectedCloudSceneId = newSceneId
        return newSceneId
    }
    
    lazy var persistenceUrl: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("arf.persistence")
        } catch {
            fatalError("Unable to get persistenceURL: \(error.localizedDescription)")
        }
    }()
    
    var scenePersistenceData: Data? {
        return try? Data(contentsOf: persistenceUrl)
    }
    
    // 2D Annotation state (UITextView-based)
    @Published var annotationViews: [UUID: UITextView] = [:]
    @Published var deleteButtons: [UUID: UIButton] = [:]
    var annotationAnchors: [UUID: ARAnchor] = [:]
    var isEditing: [UUID: Bool] = [:]
    var hasBeenTapped: [UUID: Bool] = [:] // placeholder-clearing flag
    var pendingAnnotationText: String? = nil
    var annotationsSceneObserver: Cancellable? = nil
    
    func requestAddAnnotation(text: String) {
        self.pendingAnnotationText = text
    }
}

extension ARViewContainer {
    private func updatePersistenceAvailability(for arView: ARView) {
        guard let currentFrame = arView.session.currentFrame else {
            print("ARFrame not available")
            return
        }
        
        switch currentFrame.worldMappingStatus {
        case .mapped:
            self.sceneManager.isPersistenceAvailable = !self.sceneManager.anchorEntities.isEmpty
        default:
            self.sceneManager.isPersistenceAvailable = false
        }
    }
    
    private func handlePersistence(for arView: CustomARView) {
        // Try to automatically match the current environment to an existing scene (sequential relocalization attempts)
        if self.sceneManager.shouldAttemptSceneAutoMatch && !self.sceneManager.autoMatchAttemptInProgress {
            self.startSceneAutoMatch(on: arView)
            return
        }

        if self.sceneManager.shouldSaveSceneToCloud {
            // Only allow save once mapping is fully established to reduce drift on restore
            guard arView.session.currentFrame?.worldMappingStatus == .mapped else {
                print("ℹ️ Waiting for fully mapped world before saving scene to cloud")
                return
            }
            self.sceneManager.shouldSaveSceneToCloud = false
            arView.session.getCurrentWorldMap { map, err in
                guard let map = map else { print("No world map:", err?.localizedDescription ?? ""); return }
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    CloudSceneStore.save(data: data) { result in
                        if case let .failure(e) = result { print("Cloud save failed:", e) }
                    }
                } catch { print("Archive error:", error) }
            }
            return
        }

        if self.sceneManager.shouldLoadSceneFromCloud {
            self.sceneManager.shouldLoadSceneFromCloud = false
            self.modelsViewModel.clearModelEntityFromMemory()
            self.sceneManager.anchorEntities.removeAll(keepingCapacity: true)
            self.sceneManager.hasStartedArtifactSync = false
            self.sceneManager.hasRelocalizedForArtifacts = false
            self.sceneManager.artifactIds.removeAll()
            self.sceneManager.artifactIdToAnchorId.removeAll()
            ArtifactSyncService.shared.stopAllListeners()
            
            // Clear any existing 2D views + buttons
            for (_, view) in self.sceneManager.annotationViews { view.removeFromSuperview() }
            for (_, btn) in self.sceneManager.deleteButtons { btn.removeFromSuperview() }
            self.sceneManager.annotationViews.removeAll(keepingCapacity: true)
            self.sceneManager.deleteButtons.removeAll(keepingCapacity: true)
            self.sceneManager.annotationAnchors.removeAll(keepingCapacity: true)
            self.sceneManager.isEditing.removeAll(keepingCapacity: true)
            self.sceneManager.hasBeenTapped.removeAll(keepingCapacity: true)

            if let id = self.sceneManager.selectedCloudSceneId {
                self.sceneManager.selectedCloudSceneId = id
                self.sceneManager.pendingSceneIdForArtifacts = id
                CloudSceneStore.load(sceneId: id) { result in
                    switch result {
                    case .success(let data):
                        ScenePersistenceHelper.loadScene(for: arView, with: data)
                        // Artifacts will load after relocalization
                    case .failure(let error):
                        print("Cloud load failed:", error)
                    }
                }
            } else {
                CloudSceneStore.loadMostRecentSceneData { result in
                    switch result {
                    case .success(let payload):
                        self.sceneManager.selectedCloudSceneId = payload.id
                        self.sceneManager.pendingSceneIdForArtifacts = payload.id
                        ScenePersistenceHelper.loadScene(for: arView, with: payload.data)
                        // Artifacts will load after relocalization
                    case .failure(let error):
                        print("Cloud load (latest) failed:", error)
                    }
                }
            }
            return
        }
    }
    
    // Load artifacts from Firebase when scene is loaded
    private func loadArtifactsFromFirebase(sceneId: String, arView: ARView) {
        ArtifactSyncService.shared.loadSceneArtifacts(sceneId: sceneId) { result in
            switch result {
            case .success(let artifacts):
                DispatchQueue.main.async {
                    // Add artifacts that aren't already loaded
                    for artifact in artifacts {
                        // Skip if we already have this artifact
                        if self.sceneManager.artifactIdToAnchorId[artifact.id] != nil {
                            continue
                        }
                        
                        if let transform = ArtifactData.arrayToTransform(artifact.transform ?? []) {
                            self.addRemoteArtifact(artifact: artifact, transform: transform, in: arView)
                        }
                    }
                }
            case .failure(let error):
                print("❌ Failed to load artifacts from Firebase: \(error.localizedDescription)")
            }
        }
    }

    // Begin Firebase syncing only after the session is relocalized to the target scene
    private func startArtifactSyncIfReady(arView: ARView) {
        guard sceneManager.hasRelocalizedForArtifacts else { return }
        guard let sceneId = sceneManager.pendingSceneIdForArtifacts else { return }
        guard !sceneManager.hasStartedArtifactSync else { return }

        sceneManager.hasStartedArtifactSync = true
        setupFirebaseListener(sceneId: sceneId, arView: arView)
        loadArtifactsFromFirebase(sceneId: sceneId, arView: arView)
    }

    // MARK: - Scene Auto-Match (attempt relocalization against user's saved scenes)

    private func startSceneAutoMatch(on arView: CustomARView) {
        sceneManager.autoMatchAttemptInProgress = true
        CloudSceneStore.fetchAllSceneMeta(limit: 10) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let metas):
                    guard !metas.isEmpty else {
                        self.sceneManager.shouldAttemptSceneAutoMatch = false
                        self.sceneManager.autoMatchAttemptInProgress = false
                        return
                    }
                    self.sceneManager.autoMatchCandidates = metas
                    self.sceneManager.autoMatchIndex = 0
                    self.tryNextSceneAutoMatch(on: arView)
                case .failure(let error):
                    print("❌ Scene auto-match fetch failed:", error.localizedDescription)
                    self.sceneManager.shouldAttemptSceneAutoMatch = false
                    self.sceneManager.autoMatchAttemptInProgress = false
                }
            }
        }
    }

    private func tryNextSceneAutoMatch(on arView: CustomARView) {
        // End of list
        guard sceneManager.autoMatchIndex < sceneManager.autoMatchCandidates.count else {
            sceneManager.shouldAttemptSceneAutoMatch = false
            sceneManager.autoMatchAttemptInProgress = false
            sceneManager.autoMatchTimer?.invalidate()
            sceneManager.autoMatchTimer = nil
            sceneManager.autoMatchCurrentSceneIdCandidate = nil
            sceneManager.pendingSceneIdForArtifacts = nil
            // Clear any persisted scene id so new placements create a fresh scene
            sceneManager.selectedCloudSceneId = nil
            print("ℹ️ No matching scene found; auto-match exhausted.")
            return
        }

        let meta = sceneManager.autoMatchCandidates[sceneManager.autoMatchIndex]
        sceneManager.autoMatchIndex += 1

        // Reset listeners/state before attempting another map
        ArtifactSyncService.shared.stopAllListeners()
        sceneManager.anchorEntities.removeAll(keepingCapacity: true)
        sceneManager.hasRelocalizedForArtifacts = false
        sceneManager.hasStartedArtifactSync = false
        sceneManager.pendingSceneIdForArtifacts = meta.id
        sceneManager.autoMatchCurrentSceneIdCandidate = meta.id
        // Clear 2D overlays
        for (_, view) in sceneManager.annotationViews { view.removeFromSuperview() }
        for (_, btn) in sceneManager.deleteButtons { btn.removeFromSuperview() }
        sceneManager.annotationViews.removeAll(keepingCapacity: true)
        sceneManager.deleteButtons.removeAll(keepingCapacity: true)
        sceneManager.annotationAnchors.removeAll(keepingCapacity: true)
        sceneManager.isEditing.removeAll(keepingCapacity: true)
        sceneManager.hasBeenTapped.removeAll(keepingCapacity: true)

        CloudSceneStore.load(sceneId: meta.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    print("🔄 Attempting auto-match with scene:", meta.id)
                    ScenePersistenceHelper.loadScene(for: arView, with: data)
                    // If we don't relocalize to this map within the window, try the next one
                    self.sceneManager.autoMatchTimer?.invalidate()
                    self.sceneManager.autoMatchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                        if !self.sceneManager.hasRelocalizedForArtifacts {
                            self.tryNextSceneAutoMatch(on: arView)
                        } else {
                            // Success; stop timer chain
                            self.sceneManager.autoMatchAttemptInProgress = false
                            self.sceneManager.shouldAttemptSceneAutoMatch = false
                        }
                    }
                case .failure(let error):
                    print("❌ Failed to load scene \(meta.id) for auto-match:", error.localizedDescription)
                    self.tryNextSceneAutoMatch(on: arView)
                }
            }
        }
    }
}

extension ARViewContainer {
    class Coordinator: NSObject, ARSessionDelegate, UITextViewDelegate {
        var parent: ARViewContainer
        weak var arView: ARView?
        private var relocalizationRetryCount = 0
        private var relocalizationRetryWorkItem: DispatchWorkItem?
        private var stableRelocalizedFrameCount = 0
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        // We can’t capture id via UIButton target/action directly; we register it here.
        func registerDeleteButton(_ button: UIButton, for id: UUID) {
            button.addTarget(self, action: #selector(handleDeleteButton(_:)), for: .touchUpInside)
            // Store association by reusing the sceneManager map (keyed by id)
            parent.sceneManager.deleteButtons[id] = button
        }

        private func resetRelocalizationState() {
            parent.sceneManager.hasRelocalizedForArtifacts = false
            parent.sceneManager.hasStartedArtifactSync = false
            relocalizationRetryWorkItem?.cancel()
            relocalizationRetryWorkItem = nil
            relocalizationRetryCount = 0
            stableRelocalizedFrameCount = 0
        }

        private func scheduleRelocalizationRetry(arView: ARView, session: ARSession) {
            guard !parent.sceneManager.hasStartedArtifactSync else { return }
            relocalizationRetryWorkItem?.cancel()
            relocalizationRetryCount = 0
            attemptRelocalization(arView: arView, session: session)
        }

        private func attemptRelocalization(arView: ARView, session: ARSession) {
            guard relocalizationRetryCount < 10 else { return }
            relocalizationRetryWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak arView, weak session] in
                guard let self = self, let arView = arView, let session = session else { return }
                self.evaluateRelocalization(arView: arView, session: session, isRetry: true)
            }
            relocalizationRetryWorkItem = workItem
            relocalizationRetryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

        private func evaluateRelocalization(arView: ARView, session: ARSession, isRetry: Bool = false) {
            let trackingState = session.currentFrame?.camera.trackingState ?? .notAvailable
            let mappingStatus = session.currentFrame?.worldMappingStatus ?? .notAvailable
            let hasGoodMapping = (mappingStatus == .mapped)

            if case .normal = trackingState, hasGoodMapping {
                stableRelocalizedFrameCount += 1
                if stableRelocalizedFrameCount >= 3 { // require a few consecutive mapped frames for stability
                    parent.sceneManager.hasRelocalizedForArtifacts = true
                    // Stop any auto-match timers now that we have a match
                    parent.sceneManager.autoMatchTimer?.invalidate()
                    parent.sceneManager.autoMatchTimer = nil
                    parent.sceneManager.autoMatchAttemptInProgress = false
                    parent.sceneManager.shouldAttemptSceneAutoMatch = false
                    // Only commit the auto-match candidate once relocalized
                    if let candidate = parent.sceneManager.autoMatchCurrentSceneIdCandidate {
                        parent.sceneManager.selectedCloudSceneId = candidate
                        parent.sceneManager.pendingSceneIdForArtifacts = candidate
                        parent.sceneManager.autoMatchCurrentSceneIdCandidate = nil
                    }
                    parent.startArtifactSyncIfReady(arView: arView)
                    relocalizationRetryWorkItem?.cancel()
                    relocalizationRetryWorkItem = nil
                    relocalizationRetryCount = 0
                    return
                }
            } else {
                stableRelocalizedFrameCount = 0
            }

            parent.sceneManager.hasRelocalizedForArtifacts = false
            if !isRetry {
                scheduleRelocalizationRetry(arView: arView, session: session)
            } else {
                attemptRelocalization(arView: arView, session: session)
            }
        }

        @objc func handleTapToPlaceAnnotation(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)
            
            // If a 3D model is selected for placement, ignore (model flow handles it)
            if parent.placementSettings.selectedModel != nil { return }
            
            // 1) If tap hits an existing annotation view: enter edit mode
            for (id, tv) in parent.sceneManager.annotationViews {
                if tv.frame.contains(location) {
                    parent.sceneManager.isEditing[id] = true
                    tv.isUserInteractionEnabled = true
                    tv.isEditable = true
                    tv.layer.borderWidth = 2
                    tv.layer.borderColor = UIColor.systemBlue.cgColor
                    if parent.sceneManager.hasBeenTapped[id] == false {
                        tv.text = ""
                        parent.sceneManager.hasBeenTapped[id] = true
                    }
                    tv.becomeFirstResponder()
                    parent.animatePopIn(tv)
                    return
                }
            }

            // 2) If some annotation is editing, end editing
            if let editingId = parent.sceneManager.isEditing.first(where: { $0.value })?.key {
                parent.sceneManager.isEditing[editingId] = false
                if let tv = parent.sceneManager.annotationViews[editingId] {
                    tv.isEditable = false
                    tv.layer.borderWidth = 0
                    tv.isUserInteractionEnabled = false
                    tv.resignFirstResponder()
                    
                    let trimmed = tv.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        // Restore placeholder and show delete button
                        tv.text = "Tap to Edit"
                        parent.sceneManager.hasBeenTapped[editingId] = false
                        parent.showDeleteButton(for: editingId, on: arView)
                    } else {
                        // Hide delete; update anchor name for persistence with new text
                        parent.hideDeleteButton(for: editingId)
                        if let oldAnchor = parent.sceneManager.annotationAnchors[editingId] {
                            let transform = oldAnchor.transform
                            let payload = ARViewContainer.AnnotationData(id: editingId, text: tv.text)
                            let name = annotationNamePrefix + parent.encodeAnnotation(payload)
                            let newAnchor = ARAnchor(name: name, transform: transform)
                            arView.session.add(anchor: newAnchor)
                            arView.session.remove(anchor: oldAnchor)
                            parent.sceneManager.annotationAnchors[editingId] = newAnchor
                            
                            // Update artifact ID mapping
                            if let artifactId = parent.sceneManager.artifactIds[oldAnchor.identifier] {
                                parent.sceneManager.artifactIds.removeValue(forKey: oldAnchor.identifier)
                                parent.sceneManager.artifactIds[newAnchor.identifier] = artifactId
                                parent.sceneManager.artifactIdToAnchorId[artifactId] = newAnchor.identifier
                                // Update existing artifact
                                parent.updateArtifact(anchor: newAnchor, annotationText: tv.text)
                            } else {
                                // First-time save after text entry
                                parent.saveAnnotationArtifact(anchor: newAnchor, annotationId: editingId, text: tv.text, transform: transform)
                            }
                        }
                    }
                }
                return
            }
            
            // 3) Otherwise, create a new annotation at tap
            parent.placeAnnotation(at: location, on: arView)
        }

        @objc func handleDeleteButton(_ sender: UIButton) {
            guard let arView = arView else { return }
            // Identify which annotation this button belongs to
            guard let (id, _) = parent.sceneManager.deleteButtons.first(where: { $0.value === sender }) else {
                parent.animatePopOut(sender) {
                    sender.removeFromSuperview()
                }
                return
            }
            // Animate pop-out and remove
            if let tv = parent.sceneManager.annotationViews[id] {
                parent.animatePopOut(tv) {
                    tv.removeFromSuperview()
                }
                parent.animatePopOut(sender) {
                    sender.removeFromSuperview()
                }
            } else {
                parent.animatePopOut(sender) {
                    sender.removeFromSuperview()
                }
            }
            // Remove anchor and state
            if let anchor = parent.sceneManager.annotationAnchors[id] {
                // Automatically delete from Firebase
                parent.deleteArtifact(anchor: anchor)
                arView.session.remove(anchor: anchor)
            }
            parent.sceneManager.annotationViews[id] = nil
            parent.sceneManager.deleteButtons[id] = nil
            parent.sceneManager.annotationAnchors[id] = nil
            parent.sceneManager.isEditing[id] = nil
            parent.sceneManager.hasBeenTapped[id] = nil
        }

        // UITextViewDelegate — show/hide delete button when text becomes empty/non-empty
        func textViewDidChange(_ textView: UITextView) {
            guard let arView = arView else { return }
            if let (id, _) = parent.sceneManager.annotationViews.first(where: { $0.value === textView }) {
                let empty = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if empty {
                    parent.showDeleteButton(for: id, on: arView)
                } else {
                    parent.hideDeleteButton(for: id)
                }
            }
        }

        // Track relocalization; only sync artifacts after we're aligned to the saved world map
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            guard let arView = arView else { return }
            evaluateRelocalization(arView: arView, session: session)
        }

        func sessionWasInterrupted(_ session: ARSession) {
            resetRelocalizationState()
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            guard let arView = arView else { return }
            evaluateRelocalization(arView: arView, session: session)
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            resetRelocalizationState()
            guard let arView = arView else { return }
            scheduleRelocalizationRetry(arView: arView, session: session)
        }
        
        // ARSession: anchors added (from live placement or from Cloud load)
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let arView = arView else { return }
            for anchor in anchors {
                if let name = anchor.name, name.hasPrefix(annotationNamePrefix) {
                    let base64 = String(name.dropFirst(annotationNamePrefix.count))
                    if let data = parent.decodeAnnotation(from: base64) {
                        parent.attachAnnotationView(for: anchor, data: data, on: arView)
                    }
                }
            }
            // Model-anchors (existing logic)
            for anchor in anchors {
                if let anchorName = anchor.name, anchorName.hasPrefix(anchorNamePrefix) {
                    let modelName = anchorName.dropFirst(anchorNamePrefix.count)
                    print("ARSession: didAdd anchor for modelName: \(modelName)")
                    
                    guard let model = parent.modelsViewModel.models.first(where: { $0.name == modelName }) else {
                        print("Unable to retrieve model from modelsViewModel")
                        return
                    }
                    
                    if model.modelEntity == nil {
                        model.asyncLoadModelEntity { [weak self] completed, error in
                            guard let self = self else { return }
                            if completed {
                                let modelAnchor = ModelAnchor(model: model, anchor: anchor)
                                self.parent.placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
                                print("Adding modelAnchor with name: \(model.name)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

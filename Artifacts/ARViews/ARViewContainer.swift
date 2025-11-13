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
        arView.installGestures([.rotation, .translation], for: clonedEntity)
        let anchorEntity = AnchorEntity(plane: .any)
        anchorEntity.addChild(clonedEntity)
        anchorEntity.anchoring = AnchoringComponent(anchor)
        arView.scene.addAnchor(anchorEntity)
        self.sceneManager.anchorEntities.append(anchorEntity)
    }
    
    private func getTransformForPlacement(in arView: ARView) -> simd_float4x4? {
        guard let query = arView.makeRaycastQuery(from: arView.center, allowing: .estimatedPlane, alignment: .any),
              let result = arView.session.raycast(query).first else { return nil }
        return result.worldTransform
    }
    
    private func getTransformForPlacement(in arView: ARView, at point: CGPoint) -> simd_float4x4? {
        guard let query = arView.makeRaycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
              let result = arView.session.raycast(query).first else { return nil }
        return result.worldTransform
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
    var selectedCloudSceneId: String?
    
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
        case .mapped, .extending:
            self.sceneManager.isPersistenceAvailable = !self.sceneManager.anchorEntities.isEmpty
        default:
            self.sceneManager.isPersistenceAvailable = false
        }
    }
    
    private func handlePersistence(for arView: CustomARView) {
        if self.sceneManager.shouldSaveSceneToCloud {
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
            
            // Clear any existing 2D views + buttons
            for (_, view) in self.sceneManager.annotationViews { view.removeFromSuperview() }
            for (_, btn) in self.sceneManager.deleteButtons { btn.removeFromSuperview() }
            self.sceneManager.annotationViews.removeAll(keepingCapacity: true)
            self.sceneManager.deleteButtons.removeAll(keepingCapacity: true)
            self.sceneManager.annotationAnchors.removeAll(keepingCapacity: true)
            self.sceneManager.isEditing.removeAll(keepingCapacity: true)
            self.sceneManager.hasBeenTapped.removeAll(keepingCapacity: true)

            if let id = self.sceneManager.selectedCloudSceneId {
                CloudSceneStore.load(sceneId: id) { result in
                    switch result {
                    case .success(let data):
                        ScenePersistenceHelper.loadScene(for: arView, with: data)
                    case .failure(let error):
                        print("Cloud load failed:", error)
                    }
                }
            } else {
                CloudSceneStore.loadMostRecentSceneData { result in
                    switch result {
                    case .success(let payload):
                        self.sceneManager.selectedCloudSceneId = payload.id
                        ScenePersistenceHelper.loadScene(for: arView, with: payload.data)
                    case .failure(let error):
                        print("Cloud load (latest) failed:", error)
                    }
                }
            }
            return
        }
    }
}

extension ARViewContainer {
    class Coordinator: NSObject, ARSessionDelegate, UITextViewDelegate {
        var parent: ARViewContainer
        weak var arView: ARView?
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        // We can’t capture id via UIButton target/action directly; we register it here.
        func registerDeleteButton(_ button: UIButton, for id: UUID) {
            button.addTarget(self, action: #selector(handleDeleteButton(_:)), for: .touchUpInside)
            // Store association by reusing the sceneManager map (keyed by id)
            parent.sceneManager.deleteButtons[id] = button
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

//
//  ARViewContainer+Coordinator.swift
//  ARTutorial
//
//  Coordinator handles ARSessionDelegate callbacks, UITextViewDelegate
//  callbacks, gesture recognition, delete-button events, and drawing
//  notification subscriptions.
//

import RealityKit
import ARKit
import UIKit

extension ARViewContainer {

    class Coordinator: NSObject, ARSessionDelegate, UITextViewDelegate {

        var parent: ARViewContainer
        weak var arView: ARView?

        /// Retained reference to the draw pan gesture so ARViewContainer
        /// can enable/disable it from updateUIView.
        var drawPanGesture: UIPanGestureRecognizer?

        /// Tracks the current finger screen position while drawing.
        /// Set by handleDrawPan; consumed by tickDrawing on every AR frame.
        var currentFingerPosition: CGPoint? = nil

        /// Notification observers retained for the lifetime of the coordinator.
        var notificationObservers: [NSObjectProtocol] = []

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        deinit {
            notificationObservers.forEach {
                NotificationCenter.default.removeObserver($0)
            }
        }

        // MARK: - ARSessionDelegate: Collaboration

        func session(_ session: ARSession,
                     didOutputCollaborationData data: ARSession.CollaborationData) {
            parent.collaborationManager.sendCollaborationData(data)
        }

        // MARK: - ARSessionDelegate: Anchors Added

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let arView = arView else { return }

            for anchor in anchors {
                // Annotation anchors
                if let name = anchor.name, name.hasPrefix(annotationNamePrefix) {
                    let base64 = String(name.dropFirst(annotationNamePrefix.count))
                    if var data = parent.decodeAnnotation(from: base64) {
                        if let override = parent.sceneManager.annotationTextOverrides[data.id.uuidString] {
                            data.text = override
                        }
                        parent.attachAnnotationView(for: anchor, data: data, on: arView)
                    }
                }
                // Model anchors
                if let anchorName = anchor.name, anchorName.hasPrefix(anchorNamePrefix) {
                    let modelName = anchorName.dropFirst(anchorNamePrefix.count)
                    print("ARSession: didAdd anchor for modelName: \(modelName)")

                    guard let model = parent.modelsViewModel.models
                        .first(where: { $0.name == modelName }) else {
                        print("Unable to retrieve model from modelsViewModel")
                        continue
                    }

                    if model.modelEntity == nil {
                        model.asyncLoadModelEntity { [weak self] completed, _ in
                            guard let self = self else { return }
                            if completed {
                                let modelAnchor = ModelAnchor(model: model, anchor: anchor)
                                self.parent.placementSettings.modelsConfirmedForPlacement
                                    .append(modelAnchor)
                                print("Adding modelAnchor with name: \(model.name)")
                            }
                        }
                    } else {
                        let modelAnchor = ModelAnchor(model: model, anchor: anchor)
                        self.parent.placementSettings.modelsConfirmedForPlacement
                            .append(modelAnchor)
                    }
                }
            }
        }

        // MARK: - ARSessionDelegate: Frame Update (drives smooth drawing)

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard case .draw = parent.placementSettings.selectedTool else { return }
            guard currentFingerPosition != nil else { return }
            DispatchQueue.main.async {
                self.tickDrawing()
            }
        }

        // MARK: - Delete Button

        func registerDeleteButton(_ button: UIButton, for id: UUID) {
            button.addTarget(self,
                             action: #selector(handleDeleteButton(_:)),
                             for: .touchUpInside)
            parent.sceneManager.deleteButtons[id] = button
        }

        @objc func handleDeleteButton(_ sender: UIButton) {
            guard let arView = arView else { return }
            guard let (id, _) = parent.sceneManager.deleteButtons
                .first(where: { $0.value === sender }) else {
                parent.animatePopOut(sender) { sender.removeFromSuperview() }
                return
            }
            if let tv = parent.sceneManager.annotationViews[id] {
                parent.animatePopOut(tv)     { tv.removeFromSuperview()     }
                parent.animatePopOut(sender) { sender.removeFromSuperview() }
            } else {
                parent.animatePopOut(sender) { sender.removeFromSuperview() }
            }
            if let anchor = parent.sceneManager.annotationAnchors[id] {
                arView.session.remove(anchor: anchor)
            }
            parent.sceneManager.annotationViews[id]   = nil
            parent.sceneManager.deleteButtons[id]     = nil
            parent.sceneManager.annotationAnchors[id] = nil
            parent.sceneManager.isEditing[id]         = nil
            parent.sceneManager.hasBeenTapped[id]     = nil
        }

        // MARK: - Tap Gesture (Annotation Placement & Editing)

        @objc func handleTapToPlaceAnnotation(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)

            // If a 3D model tool is active, PlacementView handles confirm/cancel
            if case .model = parent.placementSettings.selectedTool { return }

            // Draw tool is active — tap does nothing (pan gesture handles drawing)
            if case .draw = parent.placementSettings.selectedTool { return }

            // 1) Tap hits an existing annotation → enter edit mode
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

            // 2) Some annotation is currently editing → end editing
            if let editingId = parent.sceneManager.isEditing.first(where: { $0.value })?.key {
                parent.sceneManager.isEditing[editingId] = false
                if let tv = parent.sceneManager.annotationViews[editingId] {
                    tv.isEditable = false
                    tv.layer.borderWidth = 0
                    tv.isUserInteractionEnabled = false
                    tv.resignFirstResponder()

                    let trimmed = tv.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        tv.text = "Tap to Edit"
                        parent.sceneManager.hasBeenTapped[editingId] = false
                        parent.showDeleteButton(for: editingId, on: arView)
                    } else {
                        parent.hideDeleteButton(for: editingId)
                        if let oldAnchor = parent.sceneManager.annotationAnchors[editingId] {
                            let transform = oldAnchor.transform
                            let payload = ARViewContainer.AnnotationData(
                                id: editingId,
                                text: tv.text
                            )
                            let name = annotationNamePrefix + parent.encodeAnnotation(payload)
                            let newAnchor = ARAnchor(name: name, transform: transform)
                            arView.session.add(anchor: newAnchor)
                            arView.session.remove(anchor: oldAnchor)
                            parent.sceneManager.annotationAnchors[editingId] = newAnchor
                        }
                    }
                    parent.updateAnnotationTextInFirestore(annotationId: editingId, text: trimmed)
                }
                return
            }

            // 3) No annotation editing — dispatch based on selected tool
            switch parent.placementSettings.selectedTool {
            case .annotation:
                parent.placeAnnotation(at: location, on: arView)
            case .model, .draw, .none:
                return
            }
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            guard let arView = arView else { return }
            if let (id, _) = parent.sceneManager.annotationViews
                .first(where: { $0.value === textView }) {
                let empty = textView.text
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if empty {
                    parent.showDeleteButton(for: id, on: arView)
                } else {
                    parent.hideDeleteButton(for: id)
                }
            }
        }
    }
}

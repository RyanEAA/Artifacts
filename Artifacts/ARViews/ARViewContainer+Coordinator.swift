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
import FirebaseAuth

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
        /// Prevents queueing unbounded draw ticks on the main thread.
        var isDrawingTickScheduled: Bool = false

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
                        if parent.sceneManager.isLoadArtifactFilterActive,
                           !parent.sceneManager.loadVisibleAnnotationArtifactIDs.contains(data.id.uuidString) {
                            continue
                        }
                        if let override = parent.sceneManager.annotationTextOverrides[data.id.uuidString] {
                            data.text = override
                        }
                        if let colorHex = parent.sceneManager.annotationColorOverrides[data.id.uuidString] {
                            data.colorHex = colorHex
                        }
                        let ownerUid = parent.sceneManager.selectedSceneOwnerUid ?? Auth.auth().currentUser?.uid ?? ""
                        let pos = SIMD3<Float>(
                            anchor.transform.columns.3.x,
                            anchor.transform.columns.3.y,
                            anchor.transform.columns.3.z
                        )
                        parent.upsertArtifactOwnerBadge(
                            artifactId: data.id.uuidString,
                            ownerUid: ownerUid,
                            worldPosition: pos,
                            yOffset: -84,
                            on: arView
                        )
                        parent.attachAnnotationView(for: anchor, data: data, on: arView)
                    }
                }
                // Model anchors
                if let anchorName = anchor.name, anchorName.hasPrefix(anchorNamePrefix) {
                    let modelName = anchorName.dropFirst(anchorNamePrefix.count)
                    print("ARSession: didAdd anchor for modelName: \(modelName)")
                    let matchedRecord = self.parent.consumeMatchingVisibleModelRecord(
                        modelName: String(modelName),
                        transform: anchor.transform
                    )
                    if self.parent.sceneManager.isLoadArtifactFilterActive, matchedRecord == nil {
                        continue
                    }
                    guard let model = parent.modelsViewModel.models
                        .first(where: { $0.name == modelName }) else {
                        print("Unable to retrieve model from modelsViewModel")
                        continue
                    }

                    if model.modelEntity == nil {
                        model.asyncLoadModelEntity { [weak self] completed, _ in
                            guard let self = self else { return }
                            if completed {
                                let modelAnchor = ModelAnchor(
                                    model: model,
                                    anchor: anchor,
                                    artifactId: matchedRecord?.artifactId,
                                    ownerUid: matchedRecord?.ownerUid
                                )
                                self.parent.placementSettings.modelsConfirmedForPlacement
                                    .append(modelAnchor)
                                print("Adding modelAnchor with name: \(model.name)")
                            }
                        }
                    } else {
                        let modelAnchor = ModelAnchor(
                            model: model,
                            anchor: anchor,
                            artifactId: matchedRecord?.artifactId,
                            ownerUid: matchedRecord?.ownerUid
                        )
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
            guard !isDrawingTickScheduled else { return }
            isDrawingTickScheduled = true
            DispatchQueue.main.async {
                self.tickDrawing()
                self.isDrawingTickScheduled = false
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
            parent.sceneManager.annotationColors[id]  = nil
            if parent.sceneManager.activeAnnotationEditingId == id {
                parent.sceneManager.clearActiveAnnotationEditingState()
            }
            let artifactId = id.uuidString
            parent.sceneManager.artifactOwnerBadgeViews[artifactId]?.removeFromSuperview()
            parent.sceneManager.artifactOwnerBadgeViews[artifactId] = nil
            parent.sceneManager.artifactOwnerBadgeWorldPositions[artifactId] = nil
            parent.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] = nil
            parent.sceneManager.artifactOwnerBadgeOwnerUids[artifactId] = nil
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
                    if let activeId = parent.sceneManager.activeAnnotationEditingId, activeId != id {
                        _ = finishActiveAnnotationEditingIfNeeded(on: arView)
                    }
                    parent.sceneManager.isEditing[id] = true
                    parent.sceneManager.activeAnnotationEditingId = id
                    let selectedColor = parent.sceneManager.annotationColor(for: id)
                    parent.sceneManager.activeAnnotationColor = selectedColor
                    tv.isUserInteractionEnabled = true
                    tv.isEditable = true
                    parent.sceneManager.applyAnnotationStyle(
                        to: tv,
                        color: selectedColor,
                        isEditing: true
                    )
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
            if finishActiveAnnotationEditingIfNeeded(on: arView) {
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

        @discardableResult
        func finishActiveAnnotationEditingIfNeeded(on arView: ARView) -> Bool {
            guard let editingId = parent.sceneManager.activeAnnotationEditingId
                ?? parent.sceneManager.isEditing.first(where: { $0.value })?.key else {
                return false
            }

            parent.sceneManager.isEditing[editingId] = false
            if let tv = parent.sceneManager.annotationViews[editingId] {
                tv.isEditable = false
                tv.isUserInteractionEnabled = false
                tv.resignFirstResponder()
                parent.sceneManager.applyAnnotationStyle(
                    to: tv,
                    color: parent.sceneManager.annotationColor(for: editingId),
                    isEditing: false
                )

                let trimmed = tv.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    tv.text = "Tap to Edit"
                    parent.sceneManager.hasBeenTapped[editingId] = false
                    parent.showDeleteButton(for: editingId, on: arView)
                } else {
                    parent.hideDeleteButton(for: editingId)
                }

                if let oldAnchor = parent.sceneManager.annotationAnchors[editingId] {
                    let transform = oldAnchor.transform
                    let payload = ARViewContainer.AnnotationData(
                        id: editingId,
                        text: trimmed.isEmpty ? "" : tv.text,
                        colorHex: parent.annotationColorHex(
                            from: parent.sceneManager.annotationColor(for: editingId)
                        )
                    )
                    let name = annotationNamePrefix + parent.encodeAnnotation(payload)
                    let newAnchor = ARAnchor(name: name, transform: transform)
                    arView.session.add(anchor: newAnchor)
                    arView.session.remove(anchor: oldAnchor)
                    parent.sceneManager.annotationAnchors[editingId] = newAnchor
                }
                parent.updateAnnotationTextInFirestore(annotationId: editingId, text: trimmed)
            }
            parent.sceneManager.clearActiveAnnotationEditingState()
            return true
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

        func subscribeToArtifactDeletionNotifications(arView: ARView) {
            let delete = NotificationCenter.default.addObserver(
                forName: .artifactDeleted,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                guard let artifactId = notification.object as? String else { return }

                if let anchorEntity = self.parent.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] {
                    if let anchors = arView.session.currentFrame?.anchors,
                       let sessionAnchor = anchors.first(where: { $0.identifier == anchorEntity.anchorIdentifier }) {
                        arView.session.remove(anchor: sessionAnchor)
                    }
                    anchorEntity.removeFromParent()
                    self.parent.sceneManager.anchorEntities.removeAll { $0 === anchorEntity }
                    self.parent.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] = nil
                }

                if let fallbackEntity = self.parent.sceneManager.fallbackModelEntitiesByArtifactId[artifactId] {
                    fallbackEntity.removeFromParent()
                    self.parent.sceneManager.fallbackModelEntitiesByArtifactId[artifactId] = nil
                    self.parent.sceneManager.fallbackRestoredModelArtifactIds.remove(artifactId)
                }

                if let id = UUID(uuidString: artifactId) {
                    if let view = self.parent.sceneManager.annotationViews[id] {
                        view.removeFromSuperview()
                    }
                    if let button = self.parent.sceneManager.deleteButtons[id] {
                        button.removeFromSuperview()
                    }
                    if let anchor = self.parent.sceneManager.annotationAnchors[id] {
                        arView.session.remove(anchor: anchor)
                    }
                    self.parent.sceneManager.annotationViews[id] = nil
                    self.parent.sceneManager.deleteButtons[id] = nil
                    self.parent.sceneManager.annotationAnchors[id] = nil
                    self.parent.sceneManager.isEditing[id] = nil
                    self.parent.sceneManager.hasBeenTapped[id] = nil
                    self.parent.sceneManager.annotationColors[id] = nil
                    if self.parent.sceneManager.activeAnnotationEditingId == id {
                        self.parent.sceneManager.clearActiveAnnotationEditingState()
                    }
                    self.parent.sceneManager.fallbackRestoredAnnotationArtifactIds.remove(artifactId)
                }

                self.parent.sceneManager.artifactOwnerBadgeViews[artifactId]?.removeFromSuperview()
                self.parent.sceneManager.artifactOwnerBadgeViews[artifactId] = nil
                self.parent.sceneManager.artifactOwnerBadgeWorldPositions[artifactId] = nil
                self.parent.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] = nil
                self.parent.sceneManager.artifactOwnerBadgeOwnerUids[artifactId] = nil
            }

            notificationObservers.append(delete)
        }

        func subscribeToAnnotationNotifications(arView: ARView) {
            let finishEditing = NotificationCenter.default.addObserver(
                forName: .finishAnnotationEditing,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.finishActiveAnnotationEditingIfNeeded(on: arView)
            }

            let colorChanged = NotificationCenter.default.addObserver(
                forName: .annotationColorChanged,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                guard let id = notification.userInfo?["annotationId"] as? UUID,
                      let color = notification.userInfo?["annotationColor"] as? UIColor else { return }

                let colorHex = self.parent.annotationColorHex(from: color)
                if let oldAnchor = self.parent.sceneManager.annotationAnchors[id] {
                    let text = self.parent.sceneManager.annotationViews[id]?.text ?? ""
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let payload = ARViewContainer.AnnotationData(
                        id: id,
                        text: trimmed.isEmpty || text == "Tap to Edit" ? "" : text,
                        colorHex: colorHex
                    )
                    let name = annotationNamePrefix + self.parent.encodeAnnotation(payload)
                    let newAnchor = ARAnchor(name: name, transform: oldAnchor.transform)
                    arView.session.add(anchor: newAnchor)
                    arView.session.remove(anchor: oldAnchor)
                    self.parent.sceneManager.annotationAnchors[id] = newAnchor
                }

                self.parent.updateAnnotationColorInFirestore(annotationId: id, colorHex: colorHex)
            }

            notificationObservers.append(contentsOf: [finishEditing, colorChanged])
        }
    }
}

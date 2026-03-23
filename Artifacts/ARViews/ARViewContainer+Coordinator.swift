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
                    if parent.sceneManager.isLoadArtifactFilterActive {
                        continue
                    }
                    let base64 = String(name.dropFirst(annotationNamePrefix.count))
                    if var data = parent.decodeAnnotation(from: base64) {
                        if parent.sceneManager.locallyPlacedAnnotationIDs.remove(data.id) != nil {
                            continue
                        }
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
                        let ownerUid = parent.sceneManager.loadVisibleAnnotationOwnerUIDs[data.id.uuidString]
                            ?? parent.sceneManager.selectedSceneOwnerUid
                            ?? Auth.auth().currentUser?.uid
                            ?? ""
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
                    if parent.sceneManager.isLoadArtifactFilterActive {
                        continue
                    }
                    if self.parent.sceneManager.locallyPlacedModelAnchorIDs.remove(anchor.identifier) != nil {
                        continue
                    }
                    let modelName = anchorName.dropFirst(anchorNamePrefix.count)
                    print("ARSession: didAdd anchor for modelName: \(modelName)")
                    let matchedRecord = self.parent.consumeMatchingVisibleModelRecord(
                        modelName: String(modelName),
                        transform: anchor.transform
                    )
                    if self.parent.sceneManager.isLoadArtifactFilterActive, matchedRecord == nil {
                        continue
                    }
                    if let artifactId = matchedRecord?.artifactId {
                        if self.parent.sceneManager.fallbackRestoredModelArtifactIds.contains(artifactId)
                            || self.parent.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] != nil
                            || self.parent.sceneManager.fallbackModelEntitiesByArtifactId[artifactId] != nil {
                            continue
                        }
                    }
                    if self.hasEquivalentPlacedModel(named: String(modelName), transform: anchor.transform) {
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

        private func hasEquivalentPlacedModel(named modelName: String, transform: simd_float4x4) -> Bool {
            let targetPosition = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            for (artifactId, anchorEntity) in parent.sceneManager.modelAnchorEntitiesByArtifactId {
                guard parent.sceneManager.modelArtifactNamesById[artifactId] == modelName else { continue }
                let existingTransform = anchorEntity.transformMatrix(relativeTo: nil)
                let existingPosition = SIMD3<Float>(
                    existingTransform.columns.3.x,
                    existingTransform.columns.3.y,
                    existingTransform.columns.3.z
                )
                if simd_distance(existingPosition, targetPosition) < 0.08 {
                    return true
                }
            }

            for (artifactId, entity) in parent.sceneManager.fallbackModelEntitiesByArtifactId {
                guard parent.sceneManager.modelArtifactNamesById[artifactId] == modelName else { continue }
                let existingTransform = entity.transformMatrix(relativeTo: nil)
                let existingPosition = SIMD3<Float>(
                    existingTransform.columns.3.x,
                    existingTransform.columns.3.y,
                    existingTransform.columns.3.z
                )
                if simd_distance(existingPosition, targetPosition) < 0.08 {
                    return true
                }
            }

            return false
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            parent.sceneManager.updateLoadRelocalizationState(for: camera.trackingState)
        }

        // MARK: - ARSessionDelegate: Frame Update (drives smooth drawing)

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            DispatchQueue.main.async {
                // ✅ tracking state
                self.parent.arSessionState.trackingState = frame.camera.trackingState
            }

            // ✅ drawing logic (keep existing behavior)
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

        func registerQuickDeleteButton(_ button: UIButton) {
            button.addTarget(self,
                             action: #selector(handleQuickDeleteButton(_:)),
                             for: .touchUpInside)
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
            parent.sceneManager.locallyPlacedAnnotationIDs.remove(id)
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
            parent.sceneManager.deletedArtifactIds.insert(artifactId)
            parent.sceneManager.pendingArtifactSaveTasks[artifactId]?.cancel()
            parent.sceneManager.pendingArtifactSaveTasks[artifactId] = nil
            parent.removeArtifactOwnerBadge(artifactId: artifactId)
            ArtifactsService.shared.deleteArtifact(artifactId: artifactId)
        }

        @objc func handleQuickDeleteButton(_ sender: UIButton) {
            guard let arView = arView else { return }
            guard let artifactId = parent.sceneManager.selectedArtifactForQuickDelete else { return }
            let drawingArtifactIds = parent.sceneManager.drawingBadgeMembersById[artifactId] ?? []
            let modelDeletionContext = modelDeletionContext(for: artifactId)
            parent.hideQuickDeleteButton()
            let artifactIdsToDelete = drawingArtifactIds.isEmpty ? [artifactId] : drawingArtifactIds
            for id in artifactIdsToDelete {
                parent.sceneManager.deletedArtifactIds.insert(id)
                parent.sceneManager.pendingArtifactSaveTasks[id]?.cancel()
                parent.sceneManager.pendingArtifactSaveTasks[id] = nil
            }
            removeLocalArtifact(artifactId, from: arView)
            Task {
                if drawingArtifactIds.isEmpty, let modelDeletionContext {
                    try? await ArtifactsService.shared.deleteMyDraftModelArtifact(
                        sceneId: modelDeletionContext.sceneId,
                        modelName: modelDeletionContext.modelName,
                        transform: modelDeletionContext.transform
                    )
                }
                for id in artifactIdsToDelete {
                    ArtifactsService.shared.deleteArtifact(artifactId: id)
                }
            }
        }

        private func isEntity(_ entity: Entity, descendantOf ancestor: Entity) -> Bool {
            var current: Entity? = entity
            while let node = current {
                if node === ancestor {
                    return true
                }
                current = node.parent
            }
            return false
        }

        private func artifactIdForTappedEntity(_ entity: Entity) -> String? {
            for (artifactId, anchorEntity) in parent.sceneManager.modelAnchorEntitiesByArtifactId {
                if entity === anchorEntity
                    || isEntity(entity, descendantOf: anchorEntity)
                    || isEntity(anchorEntity, descendantOf: entity) {
                    return artifactId
                }
            }

            for (artifactId, fallbackEntity) in parent.sceneManager.fallbackModelEntitiesByArtifactId {
                if entity === fallbackEntity
                    || isEntity(entity, descendantOf: fallbackEntity)
                    || isEntity(fallbackEntity, descendantOf: entity) {
                    return artifactId
                }
            }

            for stroke in parent.sceneManager.drawingManager.strokeGroups {
                if stroke.entities.contains(where: {
                    entity === $0 || isEntity(entity, descendantOf: $0) || isEntity($0, descendantOf: entity)
                }) {
                    if let drawingClusterId = parent.sceneManager.drawingBadgeMembersById.first(where: { _, members in
                        members.contains(stroke.artifactId)
                    })?.key {
                        return drawingClusterId
                    }
                    return stroke.artifactId
                }
            }

            return nil
        }

        private func removeLocalArtifact(_ artifactId: String, from arView: ARView) {
            if let drawingArtifactIds = self.parent.sceneManager.drawingBadgeMembersById[artifactId], !drawingArtifactIds.isEmpty {
                let memberIds = drawingArtifactIds
                self.parent.removeArtifactOwnerBadge(artifactId: artifactId)
                self.parent.sceneManager.drawingBadgeMembersById[artifactId] = nil
                for memberId in memberIds {
                    removeLocalArtifact(memberId, from: arView)
                }
                self.parent.syncDrawingOwnerBadges(on: arView)
                return
            }

            self.parent.sceneManager.loadVisibleModelRecords.removeAll { $0.artifactId == artifactId }
            self.parent.sceneManager.loadVisibleAnnotationArtifactIDs.remove(artifactId)
            self.parent.sceneManager.loadVisibleAnnotationOwnerUIDs[artifactId] = nil
            self.parent.sceneManager.annotationTextOverrides[artifactId] = nil
            self.parent.sceneManager.annotationColorOverrides[artifactId] = nil
            if let anchorEntity = self.parent.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] {
                if let anchors = arView.session.currentFrame?.anchors,
                   let sessionAnchor = anchors.first(where: { $0.identifier == anchorEntity.anchorIdentifier }) {
                    arView.session.remove(anchor: sessionAnchor)
                }
                anchorEntity.removeFromParent()
                self.parent.sceneManager.anchorEntities.removeAll { $0 === anchorEntity }
                self.parent.sceneManager.modelAnchorEntitiesByArtifactId[artifactId] = nil
                self.parent.sceneManager.modelArtifactNamesById[artifactId] = nil
            }

            if let fallbackEntity = self.parent.sceneManager.fallbackModelEntitiesByArtifactId[artifactId] {
                fallbackEntity.removeFromParent()
                self.parent.sceneManager.fallbackModelEntitiesByArtifactId[artifactId] = nil
                self.parent.sceneManager.modelArtifactNamesById[artifactId] = nil
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

            if self.parent.sceneManager.drawingManager.removeStroke(artifactId: artifactId, in: arView.scene) {
                // Removal handled above; nothing else needed here.
                self.parent.syncDrawingOwnerBadges(on: arView)
            }

            self.parent.removeArtifactOwnerBadge(artifactId: artifactId)
        }

        private func modelDeletionContext(for artifactId: String) -> (sceneId: String, modelName: String, transform: simd_float4x4)? {
            guard let sceneId = self.parent.sceneManager.selectedCloudSceneId, !sceneId.isEmpty else {
                return nil
            }

            if let anchorEntity = self.parent.sceneManager.modelAnchorEntitiesByArtifactId[artifactId],
               let modelName = self.parent.sceneManager.modelArtifactNamesById[artifactId] {
                return (sceneId, modelName, anchorEntity.transformMatrix(relativeTo: nil))
            }

            if let fallbackEntity = self.parent.sceneManager.fallbackModelEntitiesByArtifactId[artifactId],
               let modelName = self.parent.sceneManager.modelArtifactNamesById[artifactId] {
                return (sceneId, modelName, fallbackEntity.transformMatrix(relativeTo: nil))
            }

            return nil
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
                    guard parent.canEditAnnotation(id) else {
                        parent.hideQuickDeleteButton()
                        return
                    }
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
                    parent.showQuickDeleteButton(for: id.uuidString, on: arView)
                    parent.animatePopIn(tv)
                    return
                }
            }

            // 2) Some annotation is currently editing → end editing
            if finishActiveAnnotationEditingIfNeeded(on: arView) {
                parent.hideQuickDeleteButton()
                return
            }

            if let entity = arView.entity(at: location),
               let artifactId = artifactIdForTappedEntity(entity) {
                parent.showQuickDeleteButton(for: artifactId, on: arView)
                return
            }

            parent.hideQuickDeleteButton()

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
            guard parent.canEditAnnotation(editingId) else {
                parent.sceneManager.isEditing[editingId] = false
                parent.sceneManager.clearActiveAnnotationEditingState()
                parent.hideQuickDeleteButton()
                return false
            }

            parent.hideQuickDeleteButton()
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
            if let (id, _) = parent.sceneManager.annotationViews
                .first(where: { $0.value === textView }) {
                parent.sceneManager.hasBeenTapped[id] = !textView.text
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                self.removeLocalArtifact(artifactId, from: arView)
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

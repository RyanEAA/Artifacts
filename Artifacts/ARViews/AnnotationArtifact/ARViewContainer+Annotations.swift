//
//  ARViewContainer+Annotations.swift
//  ARTutorial
//

import RealityKit
import ARKit
import UIKit
import Foundation
import FirebaseAuth

extension ARViewContainer {

    struct AnnotationData: Codable {
        let id: UUID
        var text: String
        var colorHex: String?
    }
}

extension ARViewContainer {

    func annotationColorHex(from color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "58D68D"
        }
        let red = Int(round(r * 255))
        let green = Int(round(g * 255))
        let blue = Int(round(b * 255))
        return String(format: "%02X%02X%02X", red, green, blue)
    }

    func annotationColor(from hex: String?) -> UIColor? {
        guard var hex else { return nil }
        hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    func prefetchOwnerUsernameIfNeeded(ownerUid: String) {
        guard !ownerUid.isEmpty else { return }
        if self.sceneManager.artifactOwnerUsernames[ownerUid] != nil { return }
        if ownerUid == Auth.auth().currentUser?.uid,
           let displayName = Auth.auth().currentUser?.displayName,
           !displayName.isEmpty {
            self.sceneManager.artifactOwnerUsernames[ownerUid] = displayName
            self.refreshOwnerBadgeLabels(for: ownerUid)
            return
        }
        guard !self.sceneManager.artifactOwnerUsernameLookupsInFlight.contains(ownerUid) else { return }
        self.sceneManager.artifactOwnerUsernameLookupsInFlight.insert(ownerUid)

        Task {
            let username = try? await ArtifactsService.shared.fetchUsername(for: ownerUid)
            await MainActor.run {
                self.sceneManager.artifactOwnerUsernameLookupsInFlight.remove(ownerUid)
                if let username = username, !username.isEmpty {
                    self.sceneManager.artifactOwnerUsernames[ownerUid] = username
                    self.refreshOwnerBadgeLabels(for: ownerUid)
                }
            }
        }
    }

    private func refreshOwnerBadgeLabels(for ownerUid: String) {
        for (artifactId, storedOwnerUid) in self.sceneManager.artifactOwnerBadgeOwnerUids where storedOwnerUid == ownerUid {
            guard let label = self.sceneManager.artifactOwnerBadgeViews[artifactId] else { continue }
            self.configureOwnerBadgeLabel(label, ownerUid: ownerUid)
        }
    }

    private func ownerBadgeFallbackText(for ownerUid: String) -> String {
        if ownerUid == Auth.auth().currentUser?.uid {
            if let displayName = Auth.auth().currentUser?.displayName,
               !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return displayName
            }
            return "You"
        }
        return "friend"
    }

    private func ownerBadgeText(for ownerUid: String) -> String {
        if let username = self.sceneManager.artifactOwnerUsernames[ownerUid], !username.isEmpty {
            return "@\(username)"
        }
        return ownerBadgeFallbackText(for: ownerUid)
    }

    private func configureOwnerBadgeLabel(_ label: UILabel, ownerUid: String) {
        let text = ownerBadgeText(for: ownerUid)
        label.text = text.isEmpty ? nil : text
        label.sizeToFit()
        label.bounds = CGRect(
            x: 0,
            y: 0,
            width: max(44, label.bounds.width + 10),
            height: 18
        )
    }

    func removeArtifactOwnerBadge(artifactId: String) {
        self.sceneManager.artifactOwnerBadgeViews[artifactId]?.removeFromSuperview()
        self.sceneManager.artifactOwnerBadgeViews[artifactId] = nil
        self.sceneManager.artifactOwnerBadgeWorldPositions[artifactId] = nil
        self.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] = nil
        self.sceneManager.artifactOwnerBadgeOwnerUids[artifactId] = nil
        if self.sceneManager.selectedArtifactForQuickDelete == artifactId {
            self.hideQuickDeleteButton()
        }
    }

    func showQuickDeleteButton(for artifactId: String, on arView: ARView) {
        guard self.sceneManager.artifactOwnerBadgeOwnerUids[artifactId] == Auth.auth().currentUser?.uid else {
            hideQuickDeleteButton()
            return
        }

        let button: UIButton
        let shouldAnimateIn = self.sceneManager.selectedArtifactForQuickDelete != artifactId
        if let existing = self.sceneManager.quickDeleteButton {
            button = existing
        } else {
            let created = UIButton(type: .system)
            created.setTitle("Delete", for: .normal)
            created.setTitleColor(UIColor.white.withAlphaComponent(0.95), for: .normal)
            created.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            created.backgroundColor = UIColor.systemRed.withAlphaComponent(0.68)
            created.layer.cornerRadius = 14
            created.layer.borderWidth = 1
            created.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.22).cgColor
            created.layer.masksToBounds = true
            (arView.session.delegate as? Coordinator)?.registerQuickDeleteButton(created)
            arView.addSubview(created)
            self.sceneManager.quickDeleteButton = created
            button = created
        }

        self.sceneManager.selectedArtifactForQuickDelete = artifactId
        button.bounds.size = CGSize(width: 92, height: 34)
        button.isHidden = false
        layoutQuickDeleteButton(on: arView)
        arView.bringSubviewToFront(button)
        if shouldAnimateIn {
            button.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            button.alpha = 0
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    button.transform = .identity
                    button.alpha = 1
                }
            )
        } else {
            button.transform = .identity
            button.alpha = 1
        }
    }

    func hideQuickDeleteButton() {
        self.sceneManager.selectedArtifactForQuickDelete = nil
        guard let button = self.sceneManager.quickDeleteButton, !button.isHidden else { return }
        UIView.animate(
            withDuration: 0.14,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                button.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
                button.alpha = 0
            },
            completion: { _ in
                button.isHidden = true
                button.transform = .identity
            }
        )
    }

    private func drawingOverlayWorldPosition(
        artifactId: String,
        verticalPadding: Float = 0.02
    ) -> SIMD3<Float>? {
        guard let stroke = self.sceneManager.drawingManager.strokeGroups.first(where: { $0.artifactId == artifactId }),
              !stroke.points.isEmpty else { return nil }

        var minX = stroke.points[0].x
        var maxX = stroke.points[0].x
        var maxY = stroke.points[0].y
        var averageZ: Float = 0

        for point in stroke.points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
            averageZ += point.z
        }

        averageZ /= Float(stroke.points.count)
        return SIMD3<Float>((minX + maxX) * 0.5, maxY + verticalPadding, averageZ)
    }

    private func drawingCenterWorldPosition(artifactId: String) -> SIMD3<Float>? {
        guard let stroke = self.sceneManager.drawingManager.strokeGroups.first(where: { $0.artifactId == artifactId }),
              !stroke.points.isEmpty else { return nil }

        var minX = stroke.points[0].x
        var maxX = stroke.points[0].x
        var minY = stroke.points[0].y
        var maxY = stroke.points[0].y
        var averageZ: Float = 0

        for point in stroke.points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
            averageZ += point.z
        }

        averageZ /= Float(stroke.points.count)
        return SIMD3<Float>((minX + maxX) * 0.5, (minY + maxY) * 0.5, averageZ)
    }

    private func quickDeleteButtonCenterForModel(artifactId: String, on arView: ARView) -> CGPoint? {
        let rootEntity: Entity?
        if let anchorEntity = self.sceneManager.modelAnchorEntitiesByArtifactId[artifactId],
           anchorEntity.scene != nil {
            rootEntity = anchorEntity
        } else if let fallbackEntity = self.sceneManager.fallbackModelEntitiesByArtifactId[artifactId],
                  fallbackEntity.scene != nil {
            rootEntity = fallbackEntity
        } else {
            rootEntity = nil
        }

        guard let rootEntity, let modelEntity = firstModelEntity(in: rootEntity) else { return nil }
        let modelName = self.sceneManager.modelArtifactNamesById[artifactId]
        let center = self.modelCenterWorldPosition(for: modelEntity, modelName: modelName)
        guard let projected = arView.project(center) else { return nil }
        return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
    }

    private func quickDeleteButtonCenterForDrawing(artifactId: String, on arView: ARView) -> CGPoint? {
        guard let center = drawingCenterWorldPosition(artifactId: artifactId),
              let projected = arView.project(center) else { return nil }
        return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
    }

    private func quickDeleteButtonCenter(for artifactId: String, on arView: ARView) -> CGPoint? {
        if let annotationId = UUID(uuidString: artifactId),
           let tv = self.sceneManager.annotationViews[annotationId],
           !tv.isHidden {
            return CGPoint(x: tv.frame.midX, y: tv.frame.maxY + 8 + 17)
        }

        if let modelCenter = quickDeleteButtonCenterForModel(artifactId: artifactId, on: arView) {
            return modelCenter
        }

        if let drawingCenter = quickDeleteButtonCenterForDrawing(artifactId: artifactId, on: arView) {
            return drawingCenter
        }

        guard let placement = self.liveOwnerBadgePlacement(for: artifactId),
              let projected = arView.project(placement.worldPosition) else {
            return nil
        }

        return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y) + 38)
    }

    func layoutQuickDeleteButton(on arView: ARView) {
        guard let artifactId = self.sceneManager.selectedArtifactForQuickDelete,
              let button = self.sceneManager.quickDeleteButton else { return }

        guard let center = quickDeleteButtonCenter(for: artifactId, on: arView) else {
            hideQuickDeleteButton()
            return
        }

        button.center = center
        button.isHidden = false
        arView.bringSubviewToFront(button)
    }

    private func firstModelEntity(in entity: Entity) -> ModelEntity? {
        if let modelEntity = entity as? ModelEntity {
            return modelEntity
        }
        for child in entity.children {
            if let found = firstModelEntity(in: child) {
                return found
            }
        }
        return nil
    }

    private func liveOwnerBadgePlacement(for artifactId: String) -> (worldPosition: SIMD3<Float>, yOffset: CGFloat)? {
        if let anchorEntity = self.sceneManager.modelAnchorEntitiesByArtifactId[artifactId],
           anchorEntity.scene != nil,
           let modelEntity = firstModelEntity(in: anchorEntity) {
            let modelName = self.sceneManager.modelArtifactNamesById[artifactId]
            return (self.modelBadgeWorldPosition(for: modelEntity, modelName: modelName), -8)
        }

        if let fallbackEntity = self.sceneManager.fallbackModelEntitiesByArtifactId[artifactId],
           fallbackEntity.scene != nil,
           let modelEntity = firstModelEntity(in: fallbackEntity) {
            let modelName = self.sceneManager.modelArtifactNamesById[artifactId]
            return (self.modelBadgeWorldPosition(for: modelEntity, modelName: modelName), -8)
        }

        if let annotationId = UUID(uuidString: artifactId),
           let anchor = self.sceneManager.annotationAnchors[annotationId] {
            let pos = SIMD3<Float>(
                anchor.transform.columns.3.x,
                anchor.transform.columns.3.y,
                anchor.transform.columns.3.z
            )
            let yOffset = self.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] ?? -84
            return (pos, yOffset)
        }

        if let drawingPosition = drawingOverlayWorldPosition(artifactId: artifactId) {
            let yOffset = self.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] ?? -14
            return (drawingPosition, yOffset)
        }

        return nil
    }

    func startRealtimeAnnotationSyncIfNeeded(on arView: ARView) {
        guard let sceneId = self.sceneManager.selectedCloudSceneId, !sceneId.isEmpty else { return }

        if self.sceneManager.annotationTextListenerSceneId == sceneId,
           self.sceneManager.annotationTextListener != nil {
            return
        }

        self.sceneManager.stopAnnotationTextListener()
        self.sceneManager.annotationTextListenerSceneId = sceneId
        self.sceneManager.annotationTextListener = ArtifactsService.shared.listenVisibleAnnotationTextOverrides(
            sceneId: sceneId
        ) { overrides in
            DispatchQueue.main.async {
                self.sceneManager.annotationTextOverrides = overrides
                self.applyAnnotationTextOverrides(on: arView, overrides: overrides)
            }
        }
    }

    func applyAnnotationTextOverrides(on arView: ARView, overrides: [String: String]) {
        for (artifactId, rawText) in overrides {
            guard let id = UUID(uuidString: artifactId),
                  let tv = self.sceneManager.annotationViews[id] else { continue }
            if self.sceneManager.isEditing[id] == true { continue }

            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayText = trimmed.isEmpty ? "Tap to Edit" : rawText
            if tv.text != displayText {
                tv.text = displayText
            }

            self.sceneManager.hasBeenTapped[id] = !trimmed.isEmpty

            guard let oldAnchor = self.sceneManager.annotationAnchors[id] else { continue }
            let payload = AnnotationData(
                id: id,
                text: rawText,
                colorHex: annotationColorHex(from: self.sceneManager.annotationColor(for: id))
            )
            let desiredName = annotationNamePrefix + encodeAnnotation(payload)
            if oldAnchor.name == desiredName { continue }
            let newAnchor = ARAnchor(name: desiredName, transform: oldAnchor.transform)
            arView.session.add(anchor: newAnchor)
            arView.session.remove(anchor: oldAnchor)
            self.sceneManager.annotationAnchors[id] = newAnchor
        }
    }

    private func saveAnnotationToFirestore(
        annotationId: UUID,
        text: String,
        colorHex: String?,
        transform: simd_float4x4,
        on arView: ARView
    ) {
        let artifactId = annotationId.uuidString

        let coordinate = LocationService.shared.currentCoordinate

        self.sceneManager.deletedArtifactIds.remove(artifactId)
        self.sceneManager.pendingArtifactSaveTasks[artifactId]?.cancel()

        let task = Task {
            defer {
                DispatchQueue.main.async {
                    self.sceneManager.pendingArtifactSaveTasks[artifactId] = nil
                }
            }
            do {
                if Task.isCancelled || self.sceneManager.deletedArtifactIds.contains(artifactId) { return }
                let sceneId = try await writableSceneIdForArtifactWrites()
                if Task.isCancelled || self.sceneManager.deletedArtifactIds.contains(artifactId) { return }
                let ownerUid = Auth.auth().currentUser?.uid ?? ""
                let pos = SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
                self.upsertArtifactOwnerBadge(
                    artifactId: artifactId,
                    ownerUid: ownerUid,
                    worldPosition: pos,
                    yOffset: -84,
                    on: arView
                )
                try await ArtifactsService.shared.createAnnotationArtifact(
                    artifactId: artifactId,
                    annotationText: text,
                    annotationColorHex: colorHex,
                    sceneId: sceneId,
                    transform: transform,
                    coordinate: coordinate
                )
                if self.sceneManager.deletedArtifactIds.contains(artifactId) {
                    try await ArtifactsService.shared.deleteArtifactAsync(artifactId: artifactId)
                }
            } catch {
                print("⚠️ createAnnotationArtifact error:", error.localizedDescription)
            }
        }
        self.sceneManager.pendingArtifactSaveTasks[artifactId] = task
    }

    func updateAnnotationTextInFirestore(annotationId: UUID, text: String) {
        let artifactId = annotationId.uuidString
        Task {
            do {
                try await ArtifactsService.shared.updateAnnotationText(
                    artifactId: artifactId,
                    annotationText: text
                )
            } catch {
                print("⚠️ updateAnnotationText error:", error.localizedDescription)
            }
        }
    }

    func updateAnnotationColorInFirestore(annotationId: UUID, colorHex: String?) {
        let artifactId = annotationId.uuidString
        Task {
            do {
                try await ArtifactsService.shared.updateAnnotationColor(
                    artifactId: artifactId,
                    annotationColorHex: colorHex
                )
            } catch {
                print("⚠️ updateAnnotationColor error:", error.localizedDescription)
            }
        }
    }

    func makeTextView(id: UUID, text: String, color: UIColor) -> UITextView {
        let tv = UITextView(frame: .zero)
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        tv.text = isEmpty ? "Tap to Edit" : text
        tv.font = .systemFont(ofSize: 16, weight: .semibold)
        tv.textAlignment = .center
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        self.sceneManager.applyAnnotationStyle(to: tv, color: color, isEditing: false)
        tv.isScrollEnabled = false
        tv.isEditable = false
        tv.isUserInteractionEnabled = false
        tv.bounds.size = CGSize(width: annotationWidth, height: annotationHeight)
        return tv
    }

    func attachAnnotationView(for anchor: ARAnchor, data: AnnotationData, on arView: ARView) {
        if self.sceneManager.annotationViews[data.id] != nil { return }
        let resolvedColor = annotationColor(from: data.colorHex)
            ?? self.sceneManager.annotationColors[data.id]
            ?? SceneManager.defaultAnnotationColor
        self.sceneManager.annotationColors[data.id] = resolvedColor
        let tv = makeTextView(id: data.id, text: data.text, color: resolvedColor)
        if let coord = arView.session.delegate as? Coordinator {
            tv.delegate = coord
        }
        arView.addSubview(tv)
        self.sceneManager.annotationViews[data.id] = tv
        self.sceneManager.annotationAnchors[data.id] = anchor
        self.sceneManager.isEditing[data.id] = false
        let hasText = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.sceneManager.hasBeenTapped[data.id] = hasText
        if self.sceneManager.isAwaitingVisibleArtifactsAfterLoad {
            tv.alpha = 1
            tv.isHidden = true
        } else {
            animatePopIn(tv)
        }
        self.sceneManager.markRestoredAnnotationIfAwaiting()
    }

    func layoutAnnotations(on arView: ARView) {
        guard let frame = arView.session.currentFrame else { return }
        let worldToCamera = simd_inverse(frame.camera.transform)

        for (id, anchor) in self.sceneManager.annotationAnchors {
            let pos = SIMD3<Float>(
                anchor.transform.columns.3.x,
                anchor.transform.columns.3.y,
                anchor.transform.columns.3.z
            )
            if let p = arView.project(pos) {
                if let tv = self.sceneManager.annotationViews[id] {
                    let cameraSpace = simd_mul(worldToCamera, SIMD4<Float>(pos.x, pos.y, pos.z, 1))
                    let isInFrontOfCamera = cameraSpace.z < 0
                    let shouldKeepHidden = self.sceneManager.isAwaitingVisibleArtifactsAfterLoad
                    tv.isHidden = shouldKeepHidden || !isInFrontOfCamera
                    tv.bounds.size = CGSize(width: annotationWidth, height: annotationHeight)
                    tv.center = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y) - 20)

                }
            } else {
                self.sceneManager.annotationViews[id]?.isHidden = true
            }
        }

        self.layoutArtifactOwnerBadges(on: arView)
    }

    func upsertArtifactOwnerBadge(
        artifactId: String,
        ownerUid: String,
        worldPosition: SIMD3<Float>,
        yOffset: CGFloat = -36,
        on arView: ARView
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.upsertArtifactOwnerBadge(
                    artifactId: artifactId,
                    ownerUid: ownerUid,
                    worldPosition: worldPosition,
                    yOffset: yOffset,
                    on: arView
                )
            }
            return
        }

        let label: UILabel
        if let existing = self.sceneManager.artifactOwnerBadgeViews[artifactId] {
            label = existing
        } else {
            let created = UILabel(frame: .zero)
            created.font = .systemFont(ofSize: 10, weight: .bold)
            created.textColor = .white
            created.backgroundColor = UIColor.black.withAlphaComponent(0.65)
            created.layer.cornerRadius = 8
            created.layer.masksToBounds = true
            created.textAlignment = .center
            created.clipsToBounds = true
            created.isUserInteractionEnabled = false
            created.alpha = 0.9
            arView.addSubview(created)
            self.sceneManager.artifactOwnerBadgeViews[artifactId] = created
            label = created
        }

        self.sceneManager.artifactOwnerBadgeOwnerUids[artifactId] = ownerUid
        self.prefetchOwnerUsernameIfNeeded(ownerUid: ownerUid)
        configureOwnerBadgeLabel(label, ownerUid: ownerUid)
        label.isHidden = false

        self.sceneManager.artifactOwnerBadgeWorldPositions[artifactId] = worldPosition
        self.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] = yOffset
        resolveOwnerUsernameIfNeeded(ownerUid: ownerUid, for: label)
    }

    private func layoutArtifactOwnerBadges(on arView: ARView) {
        guard let frame = arView.session.currentFrame else { return }
        let worldToCamera = simd_inverse(frame.camera.transform)

        var staleArtifactIds: [String] = []

        for (artifactId, label) in self.sceneManager.artifactOwnerBadgeViews {
            guard let placement = self.liveOwnerBadgePlacement(for: artifactId) else {
                staleArtifactIds.append(artifactId)
                continue
            }
            let worldPos = placement.worldPosition
            self.sceneManager.artifactOwnerBadgeWorldPositions[artifactId] = worldPos
            self.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] = placement.yOffset

            if let ownerUid = self.sceneManager.artifactOwnerBadgeOwnerUids[artifactId],
               (label.text == nil || label.text?.isEmpty == true || label.text == ownerBadgeFallbackText(for: ownerUid)) {
                resolveOwnerUsernameIfNeeded(ownerUid: ownerUid, for: label)
                configureOwnerBadgeLabel(label, ownerUid: ownerUid)
            }

            if let p = arView.project(worldPos) {
                let cameraSpace = simd_mul(worldToCamera, SIMD4<Float>(worldPos.x, worldPos.y, worldPos.z, 1))
                let isInFrontOfCamera = cameraSpace.z < 0
                label.isHidden = self.sceneManager.isAwaitingVisibleArtifactsAfterLoad || !isInFrontOfCamera || label.text == nil
                if isInFrontOfCamera {
                    let yOffset = self.sceneManager.artifactOwnerBadgeOffsetsY[artifactId] ?? -36
                    label.center = CGPoint(
                        x: CGFloat(p.x),
                        y: CGFloat(p.y) + yOffset
                    )
                    arView.bringSubviewToFront(label)
                }
            } else {
                label.isHidden = true
            }
        }

        staleArtifactIds.forEach { self.removeArtifactOwnerBadge(artifactId: $0) }
        self.layoutQuickDeleteButton(on: arView)
    }

    private func resolveOwnerUsernameIfNeeded(ownerUid: String, for label: UILabel) {
        guard !ownerUid.isEmpty else { return }
        if let cached = self.sceneManager.artifactOwnerUsernames[ownerUid] {
            configureOwnerBadgeLabel(label, ownerUid: ownerUid)
            return
        }
        self.prefetchOwnerUsernameIfNeeded(ownerUid: ownerUid)
    }

    func encodeAnnotation(_ data: AnnotationData) -> String {
        if let d = try? JSONEncoder().encode(data) {
            return d.base64EncodedString()
        }
        return ""
    }

    func decodeAnnotation(from base64: String) -> AnnotationData? {
        guard let d = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(AnnotationData.self, from: d)
    }

    func placePendingAnnotationIfNeeded(on arView: ARView) {
        guard let text = self.sceneManager.pendingAnnotationText else { return }
        guard let transform = getTransformForPlacement(in: arView) else { return }

        startRealtimeAnnotationSyncIfNeeded(on: arView)

        let id = UUID()
        let color = SceneManager.defaultAnnotationColor
        self.sceneManager.annotationColors[id] = color
        let payload = AnnotationData(
            id: id,
            text: text,
            colorHex: annotationColorHex(from: color)
        )
        let name = annotationNamePrefix + encodeAnnotation(payload)
        let anchor = ARAnchor(name: name, transform: transform)
        arView.session.add(anchor: anchor)
        let ownerUid = Auth.auth().currentUser?.uid ?? ""
        let pos = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        self.upsertArtifactOwnerBadge(
            artifactId: id.uuidString,
            ownerUid: ownerUid,
            worldPosition: pos,
            yOffset: -84,
            on: arView
        )
        attachAnnotationView(for: anchor, data: payload, on: arView)
        self.sceneManager.hasBeenTapped[id] = false
        self.sceneManager.pendingAnnotationText = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let colorHex = annotationColorHex(from: color)
        saveAnnotationToFirestore(
            annotationId: id,
            text: trimmed,
            colorHex: colorHex,
            transform: transform,
            on: arView
        )
    }

    func placeAnnotation(at point: CGPoint, on arView: ARView) {
        let rawText = (self.sceneManager.pendingAnnotationText?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Tap to Edit"

        guard let transform = getTransformForPlacement(in: arView, at: point) else { return }

        startRealtimeAnnotationSyncIfNeeded(on: arView)

        let id = UUID()
        let color = SceneManager.defaultAnnotationColor
        self.sceneManager.annotationColors[id] = color
        let payload = AnnotationData(
            id: id,
            text: rawText == "Tap to Edit" ? "" : rawText,
            colorHex: annotationColorHex(from: color)
        )
        let name = annotationNamePrefix + encodeAnnotation(payload)
        let anchor = ARAnchor(name: name, transform: transform)
        arView.session.add(anchor: anchor)
        let ownerUid = Auth.auth().currentUser?.uid ?? ""
        let pos = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        self.upsertArtifactOwnerBadge(
            artifactId: id.uuidString,
            ownerUid: ownerUid,
            worldPosition: pos,
            yOffset: -84,
            on: arView
        )
        attachAnnotationView(for: anchor, data: payload, on: arView)
        self.sceneManager.hasBeenTapped[id] = (rawText != "Tap to Edit")
        self.sceneManager.pendingAnnotationText = nil
        self.placementSettings.selectedTool = .none

        let trimmed = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let colorHex = annotationColorHex(from: color)
        saveAnnotationToFirestore(
            annotationId: id,
            text: trimmed,
            colorHex: colorHex,
            transform: transform,
            on: arView
        )
    }

    func animatePopIn(_ view: UIView) {
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        view.alpha = 0
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8,
            options: [.curveEaseOut],
            animations: {
                view.transform = .identity
                view.alpha = 1
            },
            completion: nil
        )
    }

    func animatePopOut(_ view: UIView, completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.20,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                view.alpha = 0
            },
            completion: { _ in completion?() }
        )
    }
}

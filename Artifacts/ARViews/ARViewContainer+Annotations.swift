//
//  ARViewContainer+Annotations.swift
//  ARTutorial
//

import RealityKit
import ARKit
import UIKit
import Foundation

extension ARViewContainer {

    struct AnnotationData: Codable {
        let id: UUID
        var text: String
    }
}

extension ARViewContainer {

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
            if trimmed.isEmpty {
                self.showDeleteButton(for: id, on: arView)
            } else {
                self.hideDeleteButton(for: id)
            }

            guard let oldAnchor = self.sceneManager.annotationAnchors[id] else { continue }
            let payload = AnnotationData(id: id, text: rawText)
            let desiredName = annotationNamePrefix + encodeAnnotation(payload)
            if oldAnchor.name == desiredName { continue }
            let newAnchor = ARAnchor(name: desiredName, transform: oldAnchor.transform)
            arView.session.add(anchor: newAnchor)
            arView.session.remove(anchor: oldAnchor)
            self.sceneManager.annotationAnchors[id] = newAnchor
        }
    }

    private func saveAnnotationToFirestore(annotationId: UUID, text: String, transform: simd_float4x4) {
        let sceneId = currentSceneIdForArtifacts()
        let artifactId = annotationId.uuidString

        let coordinate = LocationService.shared.currentCoordinate

        Task {
            do {
                try await ArtifactsService.shared.createAnnotationArtifact(
                    artifactId: artifactId,
                    annotationText: text,
                    sceneId: sceneId,
                    transform: transform,
                    coordinate: coordinate
                )
            } catch {
                print("⚠️ createAnnotationArtifact error:", error.localizedDescription)
            }
        }
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

    func makeTextView(id: UUID, text: String) -> UITextView {
        let tv = UITextView(frame: .zero)
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        tv.text = isEmpty ? "Tap to Edit" : text
        tv.font = .systemFont(ofSize: 16, weight: .semibold)
        tv.textAlignment = .center
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        tv.backgroundColor = UIColor.mintGreen.withAlphaComponent(0.92)
        tv.textColor = UIColor.black.withAlphaComponent(0.92)
        tv.layer.cornerRadius = 14
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.mintGreen.withAlphaComponent(0.35).cgColor
        tv.layer.masksToBounds = true
        tv.isScrollEnabled = false
        tv.isEditable = false
        tv.isUserInteractionEnabled = false
        tv.bounds.size = CGSize(width: annotationWidth, height: annotationHeight)
        return tv
    }

    func attachAnnotationView(for anchor: ARAnchor, data: AnnotationData, on arView: ARView) {
        if self.sceneManager.annotationViews[data.id] != nil { return }
        let tv = makeTextView(id: data.id, text: data.text)
        if let coord = arView.session.delegate as? Coordinator {
            tv.delegate = coord
        }
        arView.addSubview(tv)
        self.sceneManager.annotationViews[data.id] = tv
        self.sceneManager.annotationAnchors[data.id] = anchor
        self.sceneManager.isEditing[data.id] = false
        let hasText = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.sceneManager.hasBeenTapped[data.id] = hasText
        animatePopIn(tv)
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
                    tv.isHidden = !isInFrontOfCamera
                    tv.bounds.size = CGSize(width: annotationWidth, height: annotationHeight)
                    tv.center = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y) - 20)

                    if let btn = self.sceneManager.deleteButtons[id] {
                        let shouldShowDelete = isInFrontOfCamera && self.shouldShowDeleteButton(for: id)
                        btn.isHidden = !shouldShowDelete
                        if shouldShowDelete {
                            let f = tv.frame
                            btn.bounds.size = CGSize(width: 80, height: 32)
                            btn.center = CGPoint(x: f.midX, y: f.maxY + 8 + btn.bounds.height / 2)
                        }
                    }
                }
            } else {
                self.sceneManager.annotationViews[id]?.isHidden = true
                self.sceneManager.deleteButtons[id]?.isHidden = true
            }
        }
    }

    private func shouldShowDeleteButton(for id: UUID) -> Bool {
        if self.sceneManager.isEditing[id] == true { return false }
        guard let tv = self.sceneManager.annotationViews[id] else { return false }
        let trimmed = tv.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || tv.text == "Tap to Edit"
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
        let payload = AnnotationData(id: id, text: text)
        let name = annotationNamePrefix + encodeAnnotation(payload)
        let anchor = ARAnchor(name: name, transform: transform)
        arView.session.add(anchor: anchor)
        attachAnnotationView(for: anchor, data: payload, on: arView)
        self.sceneManager.hasBeenTapped[id] = false
        self.sceneManager.pendingAnnotationText = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        saveAnnotationToFirestore(annotationId: id, text: trimmed, transform: transform)
    }

    func placeAnnotation(at point: CGPoint, on arView: ARView) {
        let rawText = (self.sceneManager.pendingAnnotationText?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Tap to Edit"

        guard let transform = getTransformForPlacement(in: arView, at: point) else { return }

        startRealtimeAnnotationSyncIfNeeded(on: arView)

        let id = UUID()
        let payload = AnnotationData(id: id, text: rawText == "Tap to Edit" ? "" : rawText)
        let name = annotationNamePrefix + encodeAnnotation(payload)
        let anchor = ARAnchor(name: name, transform: transform)
        arView.session.add(anchor: anchor)
        attachAnnotationView(for: anchor, data: payload, on: arView)
        self.sceneManager.hasBeenTapped[id] = (rawText != "Tap to Edit")
        self.sceneManager.pendingAnnotationText = nil
        self.placementSettings.selectedTool = .none

        let trimmed = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        saveAnnotationToFirestore(annotationId: id, text: trimmed, transform: transform)
    }

    func showDeleteButton(for id: UUID, on arView: ARView) {
        guard let tv = self.sceneManager.annotationViews[id] else { return }
        let button: UIButton
        if let existing = self.sceneManager.deleteButtons[id] {
            button = existing
        } else {
            let btn = UIButton(type: .system)
            btn.setTitle("Delete", for: .normal)
            btn.setTitleColor(UIColor.white.withAlphaComponent(0.95), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            btn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
            btn.layer.cornerRadius = 14
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.35).cgColor
            btn.layer.masksToBounds = true
            (arView.session.delegate as? Coordinator)?.registerDeleteButton(btn, for: id)
            self.sceneManager.deleteButtons[id] = btn
            arView.addSubview(btn)
            button = btn
        }
        button.isHidden = false
        let f = tv.frame
        button.bounds.size = CGSize(width: 92, height: 34)
        button.center = CGPoint(x: f.midX, y: f.maxY + 8 + button.bounds.height / 2)
    }

    func hideDeleteButton(for id: UUID) {
        self.sceneManager.deleteButtons[id]?.isHidden = true
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

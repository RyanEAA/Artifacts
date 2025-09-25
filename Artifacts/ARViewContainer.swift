//
//  ARViewContainer.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/9/25.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit
import Combine

struct ARViewContainer: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.arView = arView

        // Configure AR session with plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        // Tap gesture to add/edit annotations
        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        // Per‑frame update to align annotation views with anchors
        context.coordinator.updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator = context.coordinator] _ in
            coordinator?.updateAnnotationPositions()
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No updates needed
    }

    class Coordinator: NSObject, UITextViewDelegate {
        weak var arView: ARView?

        struct Annotation {
            var anchor: AnchorEntity
            var view: UITextView
            var isEditing: Bool
            // Optional delete button that appears when the text is empty
            var deleteButton: UIButton?
            var hasBeenTapped: Bool
        }

        var annotations: [Annotation] = []
        var updateSubscription: Cancellable?

        deinit {
            updateSubscription?.cancel()
        }

        // Helper to “pop in” a view (used when opening annotations)
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

        @objc
        func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let location = sender.location(in: arView)

            // 1. If user tapped an existing annotation, enter edit mode
            for index in annotations.indices {
                if annotations[index].view.frame.contains(location) {
                    annotations[index].isEditing = true
                    let textView = annotations[index].view
                    // Clear placeholder text on first tap
                    if !annotations[index].hasBeenTapped {
                        annotations[index].hasBeenTapped = true
                        textView.text = ""
                    }
                    // Enable user interaction only while editing
                    textView.isUserInteractionEnabled = true
                    textView.isEditable = true
                    textView.layer.borderWidth = 2
                    textView.layer.borderColor = UIColor.systemBlue.cgColor
                    textView.becomeFirstResponder()
                    // Pop-in animation when opening
                    animatePopIn(textView)
                    return
                }
            }

            // 2. If no annotation view was hit but one is currently being edited, stop editing
            if let editingIndex = annotations.firstIndex(where: { $0.isEditing }) {
                annotations[editingIndex].isEditing = false
                let textView = annotations[editingIndex].view
                textView.isEditable = false
                textView.layer.borderWidth = 0
                // Disable user interaction to let touches fall through when not editing
                textView.isUserInteractionEnabled = false
                textView.resignFirstResponder()
                return
            }

            // 3. Otherwise, perform raycast and add a new annotation
            guard let result = arView
                    .raycast(from: location, allowing: .estimatedPlane, alignment: .any)
                    .first else { return }

            let anchor = AnchorEntity(.world(transform: result.worldTransform))
            arView.scene.addAnchor(anchor)

            let width: CGFloat = 160
            let height: CGFloat = 80
            let frame = CGRect(
                x: location.x - width/2,
                y: location.y - height/2,
                width: width,
                height: height)

            let textView = UITextView(frame: frame)
            textView.text = "Tap to Edit"
            textView.backgroundColor = UIColor.mintGreen.withAlphaComponent(0.9)
            textView.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            textView.textAlignment = .center
            textView.layer.cornerRadius = 8
            textView.layer.masksToBounds = true
            textView.isScrollEnabled = false
            textView.isEditable = false
            // Disable user interaction until editing starts so taps fall through
            textView.isUserInteractionEnabled = false
            textView.delegate = self

            arView.addSubview(textView)
            annotations.append(Annotation(anchor: anchor, view: textView, isEditing: false, deleteButton: nil, hasBeenTapped: false))
            // Pop-in animation for a newly added annotation
            animatePopIn(textView)
        }

        // Show a "Delete?" button when the annotation's text becomes empty
        func showDeleteButton(for index: Int) {
            guard let arView = arView else { return }
            let annotation = annotations[index]
            // If the button doesn't already exist, create it
            if annotation.deleteButton == nil {
                let buttonWidth: CGFloat = 80
                let buttonHeight: CGFloat = 32
                let textViewFrame = annotation.view.frame
                let button = UIButton(frame: CGRect(
                    x: textViewFrame.midX - buttonWidth / 2,
                    y: textViewFrame.maxY + 8,
                    width: buttonWidth,
                    height: buttonHeight))
                button.setTitle("Delete", for: .normal)
                button.setTitleColor(.white, for: .normal)
                button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
                button.layer.cornerRadius = 6
                button.layer.masksToBounds = true
                button.addTarget(self, action: #selector(deleteAnnotation(_:)), for: .touchUpInside)
                arView.addSubview(button)
                annotations[index].deleteButton = button
            }
            annotations[index].deleteButton?.isHidden = false
        }

        // Hide the delete button when there is text or editing ends
        func hideDeleteButton(for index: Int) {
            if let button = annotations[index].deleteButton {
                button.isHidden = true
            }
        }

        // Called when the delete button is tapped. Removes the annotation's view and anchor with a pop-out animation.
        @objc
        func deleteAnnotation(_ sender: UIButton) {
            // Find the annotation associated with this button
            guard let idx = annotations.firstIndex(where: { $0.deleteButton == sender }) else { return }
            let annotation = annotations[idx]

            // Instantly hide the delete button for smoother pop‑out
            annotation.deleteButton?.isHidden = true

            // Animate the text view shrinking before removal
            UIView.animate(
                withDuration: 0.2,
                animations: {
                    annotation.view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                    annotation.view.alpha = 0
                },
                completion: { _ in
                    annotation.view.removeFromSuperview()
                    annotation.deleteButton?.removeFromSuperview()
                    self.arView?.scene.removeAnchor(annotation.anchor)
                    self.annotations.remove(at: idx)
                }
            )
        }

        // UITextViewDelegate — called whenever the text changes
        func textViewDidChange(_ textView: UITextView) {
            // Show the delete button when the text field is empty, hide it otherwise
            guard let idx = annotations.firstIndex(where: { $0.view == textView }) else { return }
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showDeleteButton(for: idx)
            } else {
                hideDeleteButton(for: idx)
            }
        }

        func updateAnnotationPositions() {
            guard let arView = arView,
                  let frame = arView.session.currentFrame else { return }

            // Determine interface orientation
            let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait

            for index in annotations.indices {
                let annotation = annotations[index]
                let worldPosition = annotation.anchor.position(relativeTo: nil)
                let projected = frame.camera.projectPoint(worldPosition,
                                                          orientation: orientation,
                                                          viewportSize: arView.bounds.size)
                DispatchQueue.main.async {
                    annotation.view.center = CGPoint(x: projected.x, y: projected.y)
                    // Update the delete button's position if it exists and is visible
                    if let button = annotation.deleteButton, !button.isHidden {
                        let tvFrame = annotation.view.frame
                        let bw = button.frame.size.width
                        let bh = button.frame.size.height
                        let newX = tvFrame.midX - bw / 2
                        let newY = tvFrame.maxY + 8
                        button.frame = CGRect(x: newX, y: newY, width: bw, height: bh)
                    }
                }
            }
        }

        // UITextViewDelegate — reset editing state when editing finishes
        func textViewDidEndEditing(_ textView: UITextView) {
            for index in annotations.indices where annotations[index].view == textView {
                annotations[index].isEditing = false
                textView.isEditable = false
                textView.layer.borderWidth = 0
                // Disable user interaction when editing ends
                textView.isUserInteractionEnabled = false
                textView.resignFirstResponder()
                hideDeleteButton(for: index)
                // If no text was entered, restore placeholder and reset first‑tap flag
                if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textView.text = "Tap to Edit"
                    annotations[index].hasBeenTapped = false
                }
                break
            }
        }
    }
}

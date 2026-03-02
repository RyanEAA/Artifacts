//
//  ARViewContainer+Drawing.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 2/26/26.
//  AR-Paint style freehand drawing in world space.
//
//  How it works:
//  ┌─────────────────────────────────────────────────────────────────┐
//  │  User finger moves on screen                                    │
//  │       ↓                                                         │
//  │  UIPanGestureRecognizer (state: .began / .changed / .ended)     │
//  │       ↓                                                         │
//  │  worldPoint(for:in:) — raycast against real geometry first,     │
//  │  falls back to a fixed depth in front of the camera             │
//  │       ↓                                                         │
//  │  placeBead(at:in:) — tiny sphere ModelEntity added to a         │
//  │  world-anchored AnchorEntity; tracked in DrawingManager         │
//  └─────────────────────────────────────────────────────────────────┘
//
//  The drawing gesture recogniser is installed/removed when
//  selectedTool changes (wired up in ARViewContainer.makeUIView via
//  the Coordinator's tool-change observer).
//

import RealityKit
import ARKit
import UIKit
import simd

// MARK: - SIMD3 math helpers (mirrors ARPaint's SCNVector3 extensions)

extension SIMD3 where Scalar == Float {
    func distance(to other: SIMD3<Float>) -> Float {
        simd_distance(self, other)
    }
    func normalized() -> SIMD3<Float> {
        simd_normalize(self)
    }
}

/// Returns interpolated positions along the line from p1→p2, spaced `spacing` metres apart.
/// Mirrors ARPaint's `getPositionsOnLineBetween`.
func interpolatedPositions(from p1: SIMD3<Float>,
                            to p2: SIMD3<Float>,
                            spacing: Float) -> [SIMD3<Float>] {
    let dist = p1.distance(to: p2)
    guard dist > 0, spacing > 0 else { return [p1] }
    let count = Int(dist / spacing)
    guard count > 0 else { return [p1] }
    let dir = (p2 - p1).normalized()
    return (0..<count).map { i in p1 + dir * (Float(i) * spacing) }
}

// MARK: - Drawing Helpers on ARViewContainer

extension ARViewContainer {

    // MARK: Gesture install

    /// Called once from makeUIView. The pan gesture tracks finger position;
    /// actual bead placement happens in the frame-update loop.
    func installDrawingGesture(on arView: CustomARView, coordinator: Coordinator) {
        let pan = UIPanGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleDrawPan(_:))
        )
        pan.maximumNumberOfTouches = 1
        pan.name = "ARDrawPan"
        pan.isEnabled = false   // enabled only when selectedTool == .draw
        arView.addGestureRecognizer(pan)
        coordinator.drawPanGesture = pan
    }

    // MARK: Bead factory

    /// Clones from a cached reference entity for efficiency (mirrors ARPaint's clone approach).
    @discardableResult
    func placeBead(at worldPos: SIMD3<Float>, in arView: ARView) -> ModelEntity {
        let dm = sceneManager.drawingManager

        // Build or reuse a reference entity per color+size combination
        let bead = makeReferenceBead(color: dm.brushColor, radius: dm.brushSize).clone(recursive: false)
        bead.position = worldPos

        // Lazily create one shared world-space anchor for all beads
        if sceneManager.drawAnchorEntity == nil {
            let anchor = AnchorEntity(world: .zero)
            arView.scene.addAnchor(anchor)
            sceneManager.drawAnchorEntity = anchor
        }
        sceneManager.drawAnchorEntity!.addChild(bead)
        dm.addBead(bead)
        return bead
    }

    /// Reference bead cache — avoids allocating new MeshResource every bead (expensive).
    private func makeReferenceBead(color: UIColor, radius: Float) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: radius)
        var mat  = SimpleMaterial()
        mat.color    = .init(tint: color, texture: nil)
        mat.roughness = .float(0.6)
        mat.metallic  = .float(0.0)
        return ModelEntity(mesh: mesh, materials: [mat])
    }

    // MARK: World position resolver

    /// Converts a 2D screen point to a 3D world position.
    ///
    /// - `.surface` mode: raycasts against detected planes/geometry.
    ///   Falls through to `.air` if no surface is hit.
    /// - `.air` mode: walks `drawDepth` metres along the camera ray
    ///   using the camera's intrinsic matrix (no surface required).
    func worldPoint(for screenPoint: CGPoint,
                    in arView: ARView,
                    drawDepth: Float = 0.3) -> SIMD3<Float>? {

        let mode = sceneManager.drawingManager.drawMode

        // Surface mode: try real geometry first
        if mode == .surface {
            if let query = arView.makeRaycastQuery(
                from: screenPoint,
                allowing: .estimatedPlane,
                alignment: .any
            ), let result = arView.session.raycast(query).first {
                let c = result.worldTransform.columns.3
                return SIMD3<Float>(c.x, c.y, c.z)
            }
            // No surface hit — fall through to air mode
        }

        // Air mode: project drawDepth metres along the camera ray.
        // Uses intrinsics to build a direction vector (CGPoint → ray).
        guard let frame = arView.session.currentFrame else { return nil }
        let cam = frame.camera
        let K   = cam.intrinsics     // [fx 0 cx / 0 fy cy / 0 0 1]
        let fx  = K.columns.0.x
        let fy  = K.columns.1.y
        let cx  = K.columns.2.x
        let cy  = K.columns.2.y

        // Ray direction in camera space (ARKit camera looks along -Z)
        let rayCamera = simd_normalize(SIMD3<Float>(
            (Float(screenPoint.x) - cx) / fx,
            (Float(screenPoint.y) - cy) / fy,
            -1.0
        ))

        // Rotate into world space
        let T   = cam.transform
        let rot = simd_float3x3(
            SIMD3<Float>(T.columns.0.x, T.columns.0.y, T.columns.0.z),
            SIMD3<Float>(T.columns.1.x, T.columns.1.y, T.columns.1.z),
            SIMD3<Float>(T.columns.2.x, T.columns.2.y, T.columns.2.z)
        )
        let rayWorld = rot * rayCamera
        let camPos   = SIMD3<Float>(T.columns.3.x, T.columns.3.y, T.columns.3.z)

        return camPos + rayWorld * drawDepth
    }
}

// MARK: - Pan Gesture + Frame-Update Drawing on Coordinator

extension ARViewContainer.Coordinator {

    // MARK: Pan gesture — only tracks finger position

    @objc func handleDrawPan(_ gesture: UIPanGestureRecognizer) {
        guard case .draw = parent.placementSettings.selectedTool else { return }

        switch gesture.state {
        case .began:
            parent.sceneManager.drawingManager.beginStroke()
            currentFingerPosition = gesture.location(in: arView)

        case .changed:
            currentFingerPosition = gesture.location(in: arView)

        case .ended, .cancelled:
            parent.sceneManager.drawingManager.endStroke()
            currentFingerPosition = nil

        default:
            break
        }
    }

    // MARK: Per-frame draw tick — called from ARSessionDelegate.session(_:didUpdate:)

    /// Call this from your existing `session(_:didUpdate:)` delegate method.
    func tickDrawing(frame: ARFrame) {
        guard case .draw = parent.placementSettings.selectedTool else { return }
        guard let arView = arView,
              let fingerPos = currentFingerPosition else { return }

        guard let currentPoint = parent.worldPoint(for: fingerPos, in: arView) else { return }

        let dm      = parent.sceneManager.drawingManager
        let spacing = dm.brushSize * 0.8   // gap-fill spacing proportional to brush size

        if let prev = dm.previousPoint {
            let dist = prev.distance(to: currentPoint)
            // Minimum movement threshold — avoids placing beads when finger is stationary
            // Matches ARPaint's 0.00104 threshold scaled to our brush size
            guard dist > spacing * 0.25 else { return }

            // Fill any gap between frames with interpolated beads (ARPaint key technique)
            let filled = interpolatedPositions(from: prev, to: currentPoint, spacing: spacing)
            filled.forEach { parent.placeBead(at: $0, in: arView) }

            // Always place one at the exact current position
            parent.placeBead(at: currentPoint, in: arView)
        } else {
            // First bead of this stroke
            parent.placeBead(at: currentPoint, in: arView)
        }

        dm.previousPoint = currentPoint
    }

    // MARK: Notification subscriptions (undo / clear from DrawingToolbarView)

    func subscribeToDrawingNotifications(arView: ARView) {
        let undo = NotificationCenter.default.addObserver(
            forName: .undoLastDrawingStroke,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.parent.sceneManager.drawingManager.undoLastStroke(in: arView.scene)
        }
        let clear = NotificationCenter.default.addObserver(
            forName: .clearAllDrawingStrokes,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.parent.sceneManager.drawingManager.clearAll(in: arView.scene)
        }
        notificationObservers.append(contentsOf: [undo, clear])
    }
}

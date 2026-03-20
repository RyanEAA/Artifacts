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
//  │  placeStrokeSegment(from:to:in:) — a slim 3D segment added to   │
//  │  a world-anchored AnchorEntity; tracked in DrawingManager       │
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
import FirebaseAuth

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

    private func strokeSpacing(for radius: Float, motionScale: Float) -> Float {
        let clampedMotion = min(max(motionScale, 0), 1)
        let multiplier = 0.24 + (0.38 * clampedMotion)
        return max(radius * multiplier, 0.0009)
    }

    // MARK: Gesture install

    /// Called once from makeUIView. The pan gesture tracks finger position;
    /// actual stroke placement happens in the frame-update loop.
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

    // MARK: Stroke geometry

    @discardableResult
    func placeStrokeSegment(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        color: UIColor,
        radius: Float,
        in arView: ARView
    ) -> ModelEntity? {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0002 else { return nil }
        let overlap = min(radius * 1.6, length * 0.35)
        let stretchedLength = length + overlap

        let segment = makeReferenceStrokeSegment(color: color).clone(recursive: false)
        segment.position = (start + end) * 0.5
        segment.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
        segment.scale = SIMD3<Float>(radius, stretchedLength, radius)
        segment.generateCollisionShapes(recursive: false)

        if sceneManager.drawAnchorEntity == nil {
            let anchor = AnchorEntity(world: .zero)
            arView.scene.addAnchor(anchor)
            sceneManager.drawAnchorEntity = anchor
        }
        sceneManager.drawAnchorEntity!.addChild(segment)
        return segment
    }

    @discardableResult
    func placeStrokeDot(at worldPos: SIMD3<Float>, color: UIColor, radius: Float, in arView: ARView) -> ModelEntity {
        let dot = makeReferenceStrokeDot(color: color).clone(recursive: false)
        dot.position = worldPos
        dot.scale = SIMD3<Float>(repeating: radius)
        dot.generateCollisionShapes(recursive: false)

        if sceneManager.drawAnchorEntity == nil {
            let anchor = AnchorEntity(world: .zero)
            arView.scene.addAnchor(anchor)
            sceneManager.drawAnchorEntity = anchor
        }
        sceneManager.drawAnchorEntity!.addChild(dot)
        return dot
    }

    private func makeReferenceStrokeSegment(color: UIColor) -> ModelEntity {
        let colorComponents = color.cgColor.components ?? [1, 1, 1, 1]
        let r = colorComponents.indices.contains(0) ? colorComponents[0] : 1
        let g = colorComponents.indices.contains(1) ? colorComponents[1] : r
        let b = colorComponents.indices.contains(2) ? colorComponents[2] : r
        let a = colorComponents.indices.contains(3) ? colorComponents[3] : 1
        let key = String(format: "segment_r%.3f_g%.3f_b%.3f_a%.3f", r, g, b, a)

        if let cached = sceneManager.drawingStrokePrototypeCache[key] {
            return cached
        }

        let mesh = MeshResource.generateCylinder(height: 1.0, radius: 1.0)
        var mat  = SimpleMaterial()
        mat.color    = .init(tint: color, texture: nil)
        mat.roughness = .float(0.6)
        mat.metallic  = .float(0.0)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        sceneManager.drawingStrokePrototypeCache[key] = entity
        return entity
    }

    private func makeReferenceStrokeDot(color: UIColor) -> ModelEntity {
        let colorComponents = color.cgColor.components ?? [1, 1, 1, 1]
        let r = colorComponents.indices.contains(0) ? colorComponents[0] : 1
        let g = colorComponents.indices.contains(1) ? colorComponents[1] : r
        let b = colorComponents.indices.contains(2) ? colorComponents[2] : r
        let a = colorComponents.indices.contains(3) ? colorComponents[3] : 1
        let key = String(format: "dot_r%.3f_g%.3f_b%.3f_a%.3f", r, g, b, a)

        if let cached = sceneManager.drawingStrokePrototypeCache[key] {
            return cached
        }

        let mesh = MeshResource.generateSphere(radius: 1.0)
        var mat  = SimpleMaterial()
        mat.color    = .init(tint: color, texture: nil)
        mat.roughness = .float(0.6)
        mat.metallic  = .float(0.0)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        sceneManager.drawingStrokePrototypeCache[key] = entity
        return entity
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

        // Air mode: project drawDepth metres along the view-space ray.
        // Use ARView's built-in projection first so touch mapping stays aligned
        // with the current viewport on iPhone/iPad and in any orientation.
        if let ray = arView.ray(through: screenPoint) {
            return ray.origin + (ray.direction * drawDepth)
        }

        // Fallback: convert the UIKit touch point into camera-image space before
        // applying intrinsics. This keeps the math consistent with larger iPad
        // viewports if ARView can't provide a ray directly.
        guard let frame = arView.session.currentFrame else { return nil }
        let cam = frame.camera
        let K = cam.intrinsics
        let fx = K.columns.0.x
        let fy = K.columns.1.y
        let cx = K.columns.2.x
        let cy = K.columns.2.y
        let viewSize = arView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let imageResolution = cam.imageResolution
        let imagePoint = SIMD2<Float>(
            Float(screenPoint.x / viewSize.width) * Float(imageResolution.width),
            Float(screenPoint.y / viewSize.height) * Float(imageResolution.height)
        )

        let rayCamera = simd_normalize(SIMD3<Float>(
            (imagePoint.x - cx) / fx,
            (imagePoint.y - cy) / fy,
            -1.0
        ))

        let transform = cam.transform
        let rotation = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        let rayWorld = rotation * rayCamera
        let cameraPosition = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )

        return cameraPosition + (rayWorld * drawDepth)
    }

    func saveDrawingStrokeToFirestore(_ stroke: DrawingManager.StrokeRecord, on arView: ARView) {
        let coordinate = LocationService.shared.currentCoordinate
        self.sceneManager.deletedArtifactIds.remove(stroke.artifactId)
        self.sceneManager.pendingArtifactSaveTasks[stroke.artifactId]?.cancel()

        let task = Task {
            defer {
                DispatchQueue.main.async {
                    self.sceneManager.pendingArtifactSaveTasks[stroke.artifactId] = nil
                }
            }
            do {
                if Task.isCancelled || self.sceneManager.deletedArtifactIds.contains(stroke.artifactId) { return }
                let sceneId = try await writableSceneIdForArtifactWrites()
                if Task.isCancelled || self.sceneManager.deletedArtifactIds.contains(stroke.artifactId) { return }
                try await ArtifactsService.shared.createDrawingArtifact(
                    artifactId: stroke.artifactId,
                    artworkId: stroke.artworkId,
                    sceneId: sceneId,
                    points: stroke.points,
                    colorRGBA: stroke.colorRGBA,
                    brushSize: stroke.brushSize,
                    coordinate: coordinate
                )
                if let first = stroke.points.first {
                    let ownerUid = Auth.auth().currentUser?.uid ?? ""
                    self.sceneManager.artifactOwnerBadgeOwnerUids[stroke.artifactId] = ownerUid
                    self.sceneManager.artifactOwnerBadgeWorldPositions[stroke.artifactId] = first
                    self.sceneManager.artifactOwnerBadgeOffsetsY[stroke.artifactId] = -14
                    self.syncDrawingOwnerBadges(on: arView)
                }
                if self.sceneManager.deletedArtifactIds.contains(stroke.artifactId) {
                    try await ArtifactsService.shared.deleteArtifactAsync(artifactId: stroke.artifactId)
                }
            } catch {
                print("⚠️ createDrawingArtifact error:", error.localizedDescription)
            }
        }
        self.sceneManager.pendingArtifactSaveTasks[stroke.artifactId] = task
    }

    func clearAllDrawings(in arView: ARView) {
        let drawingArtifactIds = self.sceneManager.drawingManager.strokeGroups.map(\.artifactId)
        self.sceneManager.drawingManager.clearAll(in: arView.scene)
        self.sceneManager.drawAnchorEntity?.removeFromParent()
        self.sceneManager.drawAnchorEntity = nil
        self.sceneManager.drawingStrokePrototypeCache.removeAll(keepingCapacity: true)
        for artifactId in drawingArtifactIds {
            self.removeArtifactOwnerBadge(artifactId: artifactId)
        }
        let clusterBadgeIds = Array(self.sceneManager.drawingBadgeMembersById.keys)
        clusterBadgeIds.forEach { self.removeArtifactOwnerBadge(artifactId: $0) }
        self.sceneManager.drawingBadgeMembersById = [:]
    }

    func restoreDrawingsFromCloud(sceneId: String, in arView: ARView, loadToken: UUID? = nil) {
        guard !sceneId.isEmpty else { return }
        Task {
            do {
                let strokes = try await ArtifactsService.shared.fetchVisibleDrawingArtifacts(sceneId: sceneId)
                let strokeClusters = ArtifactsService.shared.clusteredDrawingArtifacts(strokes)
                await MainActor.run {
                    if let loadToken, self.sceneManager.visibleArtifactLoadToken != loadToken { return }
                    for cluster in strokeClusters {
                        var clusterRestored = false
                        for stroke in cluster {
                            guard !stroke.points.isEmpty else { continue }
                            let step = max(1, stroke.points.count / 320)
                            let sampled = stride(from: 0, to: stroke.points.count, by: step)
                                .map { stroke.points[$0] }
                            let pointsToRender = sampled
                            guard !pointsToRender.isEmpty else { continue }

                            let color = UIColor(
                                red: CGFloat(stroke.colorRGBA.x),
                                green: CGFloat(stroke.colorRGBA.y),
                                blue: CGFloat(stroke.colorRGBA.z),
                                alpha: CGFloat(stroke.colorRGBA.w)
                            )
                            var entities: [ModelEntity] = []
                            if pointsToRender.count == 1 {
                                let dot = self.placeStrokeDot(
                                    at: pointsToRender[0],
                                    color: color,
                                    radius: stroke.brushSize,
                                    in: arView
                                )
                                entities.append(dot)
                            } else {
                                let startCap = self.placeStrokeDot(
                                    at: pointsToRender[0],
                                    color: color,
                                    radius: stroke.brushSize,
                                    in: arView
                                )
                                entities.append(startCap)
                                for index in 1..<pointsToRender.count {
                                    if let segment = self.placeStrokeSegment(
                                        from: pointsToRender[index - 1],
                                        to: pointsToRender[index],
                                        color: color,
                                        radius: stroke.brushSize,
                                        in: arView
                                    ) {
                                        self.sceneManager.drawAnchorEntity?.isEnabled = !self.sceneManager.isAwaitingVisibleArtifactsAfterLoad
                                        entities.append(segment)
                                    }
                                }
                                let endCap = self.placeStrokeDot(
                                    at: pointsToRender[pointsToRender.count - 1],
                                    color: color,
                                    radius: stroke.brushSize,
                                    in: arView
                                )
                                entities.append(endCap)
                            }

                            self.sceneManager.drawingManager.appendRestoredStroke(
                                artifactId: stroke.artifactId,
                                artworkId: stroke.artworkId,
                                colorRGBA: stroke.colorRGBA,
                                brushSize: stroke.brushSize,
                                entities: entities,
                                points: pointsToRender
                            )
                            if let first = pointsToRender.first {
                                self.sceneManager.artifactOwnerBadgeOwnerUids[stroke.artifactId] = stroke.ownerUid
                                self.sceneManager.artifactOwnerBadgeWorldPositions[stroke.artifactId] = first
                                self.sceneManager.artifactOwnerBadgeOffsetsY[stroke.artifactId] = -14
                            }
                            clusterRestored = true
                        }
                        if clusterRestored {
                            let drawingOnlyLoad = self.sceneManager.isAwaitingOnlyDrawingsAfterLoad()
                            if drawingOnlyLoad {
                                self.sceneManager.drawAnchorEntity?.isEnabled = true
                            }
                            self.syncDrawingOwnerBadges(on: arView)
                            if drawingOnlyLoad {
                                DispatchQueue.main.async {
                                    self.sceneManager.markRestoredDrawingIfAwaiting()
                                }
                            } else {
                                self.sceneManager.markRestoredDrawingIfAwaiting()
                            }
                        }
                    }
                }
            } catch {
                print("⚠️ fetchVisibleDrawingArtifacts error:", error.localizedDescription)
            }
        }
    }

    func restoreDrawingsAfterRelocalization(sceneId: String, in arView: ARView, loadToken: UUID? = nil, maxWaitSeconds: TimeInterval = 10) {
        guard !sceneId.isEmpty else { return }

        if self.sceneManager.areModelAndAnnotationRestoresSatisfied() {
            self.restoreDrawingsFromCloud(sceneId: sceneId, in: arView, loadToken: loadToken)
            return
        }

        let deadline = Date().addingTimeInterval(maxWaitSeconds)

        func attemptDrawingRestore() {
            if let loadToken, self.sceneManager.visibleArtifactLoadToken != loadToken {
                return
            }
            if self.sceneManager.areModelAndAnnotationRestoresSatisfied() || Date() >= deadline {
                self.restoreDrawingsFromCloud(sceneId: sceneId, in: arView, loadToken: loadToken)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                attemptDrawingRestore()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + maxWaitSeconds) {
            if let loadToken, self.sceneManager.visibleArtifactLoadToken != loadToken {
                return
            }
            if self.sceneManager.isAwaitingVisibleArtifactsAfterLoad {
                // Fallback: when world-map relocalization doesn't re-add anchors in time,
                // restore models/annotations directly from artifact transforms.
                self.restoreVisibleModelsAndAnnotationsFromCloud(sceneId: sceneId, in: arView, loadToken: loadToken ?? self.sceneManager.visibleArtifactLoadToken)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            attemptDrawingRestore()
        }
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
            if let arView = arView,
               let lastPoint = parent.sceneManager.drawingManager.previousPoint,
               !parent.sceneManager.drawingManager.activeStrokeEntities.isEmpty {
                let endCap = parent.placeStrokeDot(
                    at: lastPoint,
                    color: parent.sceneManager.drawingManager.brushColor,
                    radius: parent.sceneManager.drawingManager.brushSize,
                    in: arView
                )
                parent.sceneManager.drawingManager.addStrokeEntity(endCap, endingAt: lastPoint)
            }
            if let stroke = parent.sceneManager.drawingManager.endStroke(),
               let arView = arView {
                parent.saveDrawingStrokeToFirestore(stroke, on: arView)
            }
            currentFingerPosition = nil

        default:
            break
        }
    }

    // MARK: Per-frame draw tick — called from ARSessionDelegate.session(_:didUpdate:)

    /// Call this from your existing `session(_:didUpdate:)` delegate method.
    func tickDrawing() {
        guard case .draw = parent.placementSettings.selectedTool else { return }
        guard let arView = arView,
              let fingerPos = currentFingerPosition else { return }

        guard let rawPoint = parent.worldPoint(for: fingerPos, in: arView) else { return }

        let dm = parent.sceneManager.drawingManager
        let rawDistance = dm.previousPoint?.distance(to: rawPoint) ?? 0
        let motionNormalizer = max(dm.brushSize * 4.0, 0.01)
        let motionScale = min(max(rawDistance / motionNormalizer, 0), 1)
        let responsiveness = 0.10 + (0.14 * motionScale)
        let currentPoint = dm.smoothPoint(rawPoint, responsiveness: responsiveness)
        let spacing = parent.strokeSpacing(for: dm.brushSize, motionScale: motionScale)

        if let prev = dm.previousPoint {
            let dist = prev.distance(to: currentPoint)
            guard dist > max(spacing * 0.18, 0.00035) else { return }

            let filled = Array(interpolatedPositions(from: prev, to: currentPoint, spacing: spacing).dropFirst().prefix(80))
            var segmentStart = prev
            for point in filled + [currentPoint] {
                if dm.activeStrokeEntities.isEmpty {
                    let startCap = parent.placeStrokeDot(
                        at: segmentStart,
                        color: dm.brushColor,
                        radius: dm.brushSize,
                        in: arView
                    )
                    dm.addStrokeEntity(startCap, endingAt: segmentStart)
                }
                if let segment = parent.placeStrokeSegment(
                    from: segmentStart,
                    to: point,
                    color: dm.brushColor,
                    radius: dm.brushSize,
                    in: arView
                ) {
                    dm.addStrokeEntity(segment, endingAt: point)
                }
                segmentStart = point
            }
        } else {
            dm.addStrokePoint(currentPoint)
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
            guard let self = self else { return }
            if let artifactId = self.parent.sceneManager.drawingManager.undoLastStroke(in: arView.scene) {
                self.parent.sceneManager.deletedArtifactIds.insert(artifactId)
                self.parent.sceneManager.pendingArtifactSaveTasks[artifactId]?.cancel()
                self.parent.sceneManager.pendingArtifactSaveTasks[artifactId] = nil
                self.parent.removeArtifactOwnerBadge(artifactId: artifactId)
                ArtifactsService.shared.deleteArtifact(artifactId: artifactId)
                self.parent.syncDrawingOwnerBadges(on: arView)
            }
        }
        let clear = NotificationCenter.default.addObserver(
            forName: .clearAllDrawingStrokes,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let artifactIds = self.parent.sceneManager.drawingManager.clearCurrentArtwork(in: arView.scene)
            artifactIds.forEach { artifactId in
                self.parent.sceneManager.deletedArtifactIds.insert(artifactId)
                self.parent.sceneManager.pendingArtifactSaveTasks[artifactId]?.cancel()
                self.parent.sceneManager.pendingArtifactSaveTasks[artifactId] = nil
                self.parent.removeArtifactOwnerBadge(artifactId: artifactId)
                ArtifactsService.shared.deleteArtifact(artifactId: artifactId)
            }
            self.parent.syncDrawingOwnerBadges(on: arView)
        }
        let clearScene = NotificationCenter.default.addObserver(
            forName: .clearSceneDrawings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.parent.clearAllDrawings(in: arView)
        }
        let deleteArtifact = NotificationCenter.default.addObserver(
            forName: .artifactDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let artifactId = notification.object as? String else { return }
            if self.parent.sceneManager.drawingManager.removeStroke(artifactId: artifactId, in: arView.scene) {
                self.parent.removeArtifactOwnerBadge(artifactId: artifactId)
                self.parent.syncDrawingOwnerBadges(on: arView)
            }
        }
        notificationObservers.append(contentsOf: [undo, clear, clearScene, deleteArtifact])
    }
}

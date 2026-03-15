//
//  DrawingManager.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 2/26/26.
//
//  Observable state container for the AR draw tool.
//  Owns the active stroke color, brush size, and the undo stack of
//  placed stroke entities so they can be removed one-by-one or all at once.
//

import Foundation
import RealityKit
import UIKit
import Combine
import simd

// MARK: - Draw Mode

enum DrawMode {
    case air        // Fixed depth in front of camera (always works)
    case surface    // Raycasts against detected planes/geometry
}

// MARK: - DrawingManager

class DrawingManager: ObservableObject {

    // MARK: Brush settings

    @Published var brushColor: UIColor = .white
    @Published var brushSize: Float   = 0.004   // sphere radius in metres (matches ARPaint default)
    @Published var drawMode: DrawMode = .air

    // MARK: Stroke tracking

    struct StrokeRecord {
        let artifactId: String
        let colorRGBA: SIMD4<Float>
        let brushSize: Float
        var beads: [ModelEntity]
        var points: [SIMD3<Float>]
    }

    /// Completed strokes — one finger drag with points and placed entities.
    private(set) var strokeGroups: [StrokeRecord] = []

    /// Beads belonging to the stroke currently being drawn.
    private(set) var activeStroke: [ModelEntity] = []
    private(set) var activeStrokePoints: [SIMD3<Float>] = []
    private var activeStrokeArtifactId: String?
    private var activeStrokeColorRGBA: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    private var activeStrokeBrushSize: Float = 0.004

    /// Last world-space bead position — used for gap-filling interpolation.
    var previousPoint: SIMD3<Float>? = nil
    private var smoothedPoint: SIMD3<Float>? = nil
    private let smoothingFactor: Float = 0.22
    private(set) var totalBeadCount: Int = 0
    private let maxBeadCount: Int = 3200

    // MARK: Stroke lifecycle

    func beginStroke() {
        activeStroke  = []
        activeStrokePoints = []
        activeStrokeArtifactId = UUID().uuidString
        activeStrokeColorRGBA = rgba(from: brushColor)
        activeStrokeBrushSize = brushSize
        previousPoint = nil
        smoothedPoint = nil
    }

    func addBead(_ entity: ModelEntity, point: SIMD3<Float>) {
        activeStroke.append(entity)
        activeStrokePoints.append(point)
        totalBeadCount += 1
        trimIfNeeded()
    }

    @discardableResult
    func endStroke() -> StrokeRecord? {
        guard !activeStroke.isEmpty else { return nil }
        let record = StrokeRecord(
            artifactId: activeStrokeArtifactId ?? UUID().uuidString,
            colorRGBA: activeStrokeColorRGBA,
            brushSize: activeStrokeBrushSize,
            beads: activeStroke,
            points: activeStrokePoints
        )
        strokeGroups.append(record)
        activeStroke  = []
        activeStrokePoints = []
        activeStrokeArtifactId = nil
        previousPoint = nil
        smoothedPoint = nil
        objectWillChange.send()
        return record
    }

    // MARK: Undo / Clear

    func undoLastStroke(in scene: RealityKit.Scene) -> String? {
        guard let last = strokeGroups.popLast() else { return nil }
        last.beads.forEach { $0.removeFromParent() }
        totalBeadCount = max(0, totalBeadCount - last.beads.count)
        objectWillChange.send()
        return last.artifactId
    }

    func clearAll(in scene: RealityKit.Scene) {
        (strokeGroups.flatMap { $0.beads } + activeStroke).forEach { $0.removeFromParent() }
        strokeGroups.removeAll()
        activeStroke  = []
        activeStrokePoints = []
        activeStrokeArtifactId = nil
        previousPoint = nil
        smoothedPoint = nil
        totalBeadCount = 0
        objectWillChange.send()
    }

    @discardableResult
    func removeStroke(artifactId: String, in scene: RealityKit.Scene) -> Bool {
        guard let index = strokeGroups.firstIndex(where: { $0.artifactId == artifactId }) else { return false }
        let stroke = strokeGroups.remove(at: index)
        stroke.beads.forEach { $0.removeFromParent() }
        totalBeadCount = max(0, totalBeadCount - stroke.beads.count)
        objectWillChange.send()
        return true
    }

    var canUndo: Bool { !strokeGroups.isEmpty }

    func appendRestoredStroke(
        artifactId: String,
        colorRGBA: SIMD4<Float>,
        brushSize: Float,
        beads: [ModelEntity],
        points: [SIMD3<Float>]
    ) {
        guard !beads.isEmpty else { return }
        strokeGroups.append(
            StrokeRecord(
                artifactId: artifactId,
                colorRGBA: colorRGBA,
                brushSize: brushSize,
                beads: beads,
                points: points
            )
        )
        totalBeadCount += beads.count
        trimIfNeeded()
        objectWillChange.send()
    }

    func smoothPoint(_ raw: SIMD3<Float>) -> SIMD3<Float> {
        guard let prev = smoothedPoint else {
            smoothedPoint = raw
            return raw
        }
        let next = simd_mix(prev, raw, SIMD3<Float>(repeating: smoothingFactor))
        smoothedPoint = next
        return next
    }

    private func trimIfNeeded() {
        while totalBeadCount > maxBeadCount {
            if !strokeGroups.isEmpty {
                if strokeGroups[0].beads.isEmpty {
                    strokeGroups.removeFirst()
                    continue
                }
                let removed = strokeGroups[0].beads.removeFirst()
                removed.removeFromParent()
                totalBeadCount -= 1
                if !strokeGroups[0].points.isEmpty {
                    strokeGroups[0].points.removeFirst()
                }
                if strokeGroups[0].beads.isEmpty {
                    strokeGroups.removeFirst()
                }
                continue
            }

            if !activeStroke.isEmpty {
                let removed = activeStroke.removeFirst()
                removed.removeFromParent()
                totalBeadCount -= 1
                if !activeStrokePoints.isEmpty {
                    activeStrokePoints.removeFirst()
                }
                continue
            }

            break
        }
    }

    private func rgba(from color: UIColor) -> SIMD4<Float> {
        let c = color.cgColor.components ?? [1, 1, 1, 1]
        let r = Float(c.indices.contains(0) ? c[0] : CGFloat(1))
        let g = Float(c.indices.contains(1) ? c[1] : CGFloat(r))
        let b = Float(c.indices.contains(2) ? c[2] : CGFloat(r))
        let a = Float(c.indices.contains(3) ? c[3] : CGFloat(1))
        return SIMD4<Float>(r, g, b, a)
    }
}

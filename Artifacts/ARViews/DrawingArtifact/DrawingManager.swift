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
    @Published var brushSize: Float   = 0.004   // stroke radius in metres
    @Published var drawMode: DrawMode = .air

    // MARK: Stroke tracking

    struct StrokeRecord {
        let artifactId: String
        let artworkId: String
        let colorRGBA: SIMD4<Float>
        let brushSize: Float
        var entities: [ModelEntity]
        var points: [SIMD3<Float>]
    }

    /// Completed strokes — one finger drag with points and placed entities.
    private(set) var strokeGroups: [StrokeRecord] = []

    /// Render entities belonging to the stroke currently being drawn.
    private(set) var activeStrokeEntities: [ModelEntity] = []
    private(set) var activeStrokePoints: [SIMD3<Float>] = []
    private var activeStrokeArtifactId: String?
    private(set) var currentArtworkId: String?
    private var activeStrokeColorRGBA: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    private var activeStrokeBrushSize: Float = 0.004

    /// Last world-space stroke point — used for gap-filling interpolation.
    var previousPoint: SIMD3<Float>? = nil
    private var smoothedPoint: SIMD3<Float>? = nil
    private let minSmoothingFactor: Float = 0.10
    private let maxSmoothingFactor: Float = 0.24
    private(set) var totalStrokeEntityCount: Int = 0
    private let maxStrokeEntityCount: Int = 3200

    // MARK: Stroke lifecycle

    func beginStroke() {
        activeStrokeEntities = []
        activeStrokePoints = []
        activeStrokeArtifactId = UUID().uuidString
        if currentArtworkId == nil {
            currentArtworkId = UUID().uuidString
        }
        activeStrokeColorRGBA = rgba(from: brushColor)
        activeStrokeBrushSize = brushSize
        previousPoint = nil
        smoothedPoint = nil
    }

    func addStrokeEntity(_ entity: ModelEntity, endingAt point: SIMD3<Float>) {
        activeStrokeEntities.append(entity)
        if activeStrokePoints.isEmpty {
            trimIfNeeded()
            activeStrokePoints.append(point)
        } else if activeStrokePoints.last != point {
            activeStrokePoints.append(point)
        }
        totalStrokeEntityCount += 1
        trimIfNeeded()
    }

    func addStrokePoint(_ point: SIMD3<Float>) {
        if activeStrokePoints.last != point {
            activeStrokePoints.append(point)
        }
    }

    @discardableResult
    func endStroke() -> StrokeRecord? {
        guard !activeStrokeEntities.isEmpty else { return nil }
        let record = StrokeRecord(
            artifactId: activeStrokeArtifactId ?? UUID().uuidString,
            artworkId: currentArtworkId ?? UUID().uuidString,
            colorRGBA: activeStrokeColorRGBA,
            brushSize: activeStrokeBrushSize,
            entities: activeStrokeEntities,
            points: activeStrokePoints
        )
        strokeGroups.append(record)
        activeStrokeEntities = []
        activeStrokePoints = []
        activeStrokeArtifactId = nil
        previousPoint = nil
        smoothedPoint = nil
        objectWillChange.send()
        return record
    }

    // MARK: Undo / Clear

    func undoLastStroke(in scene: RealityKit.Scene) -> String? {
        guard let artworkId = currentArtworkId else { return nil }
        let index = strokeGroups.lastIndex(where: { $0.artworkId == artworkId })
        guard let index else { return nil }
        let last = strokeGroups.remove(at: index)
        last.entities.forEach { $0.removeFromParent() }
        totalStrokeEntityCount = max(0, totalStrokeEntityCount - last.entities.count)
        objectWillChange.send()
        return last.artifactId
    }

    func clearAll(in scene: RealityKit.Scene) {
        (strokeGroups.flatMap { $0.entities } + activeStrokeEntities).forEach { $0.removeFromParent() }
        strokeGroups.removeAll()
        activeStrokeEntities = []
        activeStrokePoints = []
        activeStrokeArtifactId = nil
        currentArtworkId = nil
        previousPoint = nil
        smoothedPoint = nil
        totalStrokeEntityCount = 0
        objectWillChange.send()
    }

    func clearCurrentArtwork(in scene: RealityKit.Scene) -> [String] {
        let artworkId = currentArtworkId

        let removedArtifactIds = strokeGroups
            .filter { record in
                guard let artworkId else { return false }
                return record.artworkId == artworkId
            }
            .map(\.artifactId)

        strokeGroups.removeAll { record in
            guard let artworkId else { return false }
            if record.artworkId == artworkId {
                record.entities.forEach { $0.removeFromParent() }
                totalStrokeEntityCount = max(0, totalStrokeEntityCount - record.entities.count)
                return true
            }
            return false
        }

        activeStrokeEntities.forEach { $0.removeFromParent() }
        totalStrokeEntityCount = max(0, totalStrokeEntityCount - activeStrokeEntities.count)
        activeStrokeEntities = []
        activeStrokePoints = []
        activeStrokeArtifactId = nil
        currentArtworkId = nil
        previousPoint = nil
        smoothedPoint = nil
        objectWillChange.send()
        return removedArtifactIds
    }

    @discardableResult
    func removeStroke(artifactId: String, in scene: RealityKit.Scene) -> Bool {
        guard let index = strokeGroups.firstIndex(where: { $0.artifactId == artifactId }) else { return false }
        let stroke = strokeGroups.remove(at: index)
        stroke.entities.forEach { $0.removeFromParent() }
        totalStrokeEntityCount = max(0, totalStrokeEntityCount - stroke.entities.count)
        objectWillChange.send()
        return true
    }

    var canUndo: Bool {
        guard let artworkId = currentArtworkId else { return false }
        return strokeGroups.contains(where: { $0.artworkId == artworkId })
    }

    func appendRestoredStroke(
        artifactId: String,
        artworkId: String,
        colorRGBA: SIMD4<Float>,
        brushSize: Float,
        entities: [ModelEntity],
        points: [SIMD3<Float>]
    ) {
        guard !entities.isEmpty else { return }
        strokeGroups.append(
            StrokeRecord(
                artifactId: artifactId,
                artworkId: artworkId,
                colorRGBA: colorRGBA,
                brushSize: brushSize,
                entities: entities,
                points: points
            )
        )
        totalStrokeEntityCount += entities.count
        trimIfNeeded()
        objectWillChange.send()
    }

    func finishCurrentArtwork() {
        currentArtworkId = nil
    }

    func smoothPoint(_ raw: SIMD3<Float>, responsiveness: Float? = nil) -> SIMD3<Float> {
        guard let prev = smoothedPoint else {
            smoothedPoint = raw
            return raw
        }
        let blend = min(
            max(responsiveness ?? maxSmoothingFactor, minSmoothingFactor),
            maxSmoothingFactor
        )
        let next = simd_mix(prev, raw, SIMD3<Float>(repeating: blend))
        smoothedPoint = next
        return next
    }

    private func trimIfNeeded() {
        while totalStrokeEntityCount > maxStrokeEntityCount {
            if !strokeGroups.isEmpty {
                if strokeGroups[0].entities.isEmpty {
                    strokeGroups.removeFirst()
                    continue
                }
                let removed = strokeGroups[0].entities.removeFirst()
                removed.removeFromParent()
                totalStrokeEntityCount -= 1
                if !strokeGroups[0].points.isEmpty {
                    strokeGroups[0].points.removeFirst()
                }
                if strokeGroups[0].entities.isEmpty {
                    strokeGroups.removeFirst()
                }
                continue
            }

            if !activeStrokeEntities.isEmpty {
                let removed = activeStrokeEntities.removeFirst()
                removed.removeFromParent()
                totalStrokeEntityCount -= 1
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

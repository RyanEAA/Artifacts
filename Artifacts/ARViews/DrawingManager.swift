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

    /// Completed strokes — each entry is one finger drag (array of beads).
    private(set) var strokeGroups: [[ModelEntity]] = []

    /// Beads belonging to the stroke currently being drawn.
    private(set) var activeStroke: [ModelEntity] = []

    /// Last world-space bead position — used for gap-filling interpolation.
    var previousPoint: SIMD3<Float>? = nil

    // MARK: Stroke lifecycle

    func beginStroke() {
        activeStroke  = []
        previousPoint = nil
    }

    func addBead(_ entity: ModelEntity) {
        activeStroke.append(entity)
    }

    func endStroke() {
        guard !activeStroke.isEmpty else { return }
        strokeGroups.append(activeStroke)
        activeStroke  = []
        previousPoint = nil
        objectWillChange.send()
    }

    // MARK: Undo / Clear

    func undoLastStroke(in scene: RealityKit.Scene) {
        guard let last = strokeGroups.popLast() else { return }
        last.forEach { $0.removeFromParent() }
        objectWillChange.send()
    }

    func clearAll(in scene: RealityKit.Scene) {
        (strokeGroups.flatMap { $0 } + activeStroke).forEach { $0.removeFromParent() }
        strokeGroups.removeAll()
        activeStroke  = []
        previousPoint = nil
        objectWillChange.send()
    }

    var canUndo: Bool { !strokeGroups.isEmpty }
}

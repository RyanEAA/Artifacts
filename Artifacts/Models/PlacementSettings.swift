//
//  PlacementSettings.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/10/25.
//

import SwiftUI
import RealityKit
import Combine
import ARKit

enum PlacementTool {
    case none
    case model(Model)
    case annotation
    case draw
}

struct ModelAnchor {
    var model: Model
    var anchor: ARAnchor?
}

class PlacementSettings: ObservableObject {

    /// Single source of truth for what tool is active.
    @Published var selectedTool: PlacementTool = .none

    /// Convenience accessor — derived from selectedTool.
    /// Read-only; set selectedTool instead.
    var selectedModel: Model? {
        if case .model(let m) = selectedTool { return m }
        return nil
    }

    // Keeps track of the order of placed models; last item is most recent
    @Published var recentlyPlaced: [Model] = []

    // Models queued to be placed in the next scene update tick
    var modelsConfirmedForPlacement: [ModelAnchor] = []

    @Published var isModelLoadInProgress: Bool = false
    @Published var modelLoadMessage: String = ""

    // Retains the SceneEvents.Update subscriber
    var sceneObserver: Cancellable?
}





















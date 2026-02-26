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
}


struct ModelAnchor {
    var model: Model
    var anchor: ARAnchor?
}

class PlacementSettings: ObservableObject {
    // when user selects a model in BrowseView, this property is set
    @Published var selectedTool: PlacementTool = .none
    @Published var selectedModel: Model?{
        willSet(newValue){
            print("setting selectedModel to \(String(describing: newValue?.name))")
        }
    }
    
    // this property keeps track of the order of models that have been placed. Last item is the most recently placed
    @Published var recentlyPlaced: [Model] = []
    
    // this property will keep track of all the content that has been configured
    var modelsConfirmedForPlacement: [ModelAnchor] = []
    
    // retains cancellable object for our SceneEvents.Update subscriber
    var sceneObserver: Cancellable?
}

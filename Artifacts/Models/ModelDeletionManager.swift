//
//  ModelDeletionManager.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/27/25.
//

import SwiftUI
import RealityKit

class ModelDeletionManager: ObservableObject {
    // where model that will be deleted
    @Published var entitySelectedForDeletion: ModelEntity? = nil {
        willSet(newValue) {
        
        // selecting new entitySelectedForDeletion
        
        // clearing entitySelectedForDeletion
            
            if self.entitySelectedForDeletion == nil, let newlySelectedEntity = newValue {
                // selecting new entitySelectedForDeletion, no prior selection
                print("Selecting new entitySelectedForDeletion, no prior selection.")
                
                // highlight newlySelectedModelEntity
                let component = ModelDebugOptionsComponent(visualizationMode: .lightingDiffuse)
                newlySelectedEntity.modelDebugOptions = component
            } else if let previouslySelectedModelEntity = self.entitySelectedForDeletion, let newlySelectedEntity = newValue {
                print("Selecting new entitySelectedForDeletion, had a prior selection")
                
                // unhighlight previouslySelectedModelEntity
                previouslySelectedModelEntity.modelDebugOptions = nil
                
                // highligh newlySelectedModelEntity
                let component = ModelDebugOptionsComponent(visualizationMode: .lightingDiffuse)
                newlySelectedEntity.modelDebugOptions = component
            } else if newValue == nil {
                // clearing entitySelectedForDeletion
                print("Clearing entitySelectedForDeletion")
                
                self.entitySelectedForDeletion?.modelDebugOptions = nil
            }
        }

    }
    
    
}

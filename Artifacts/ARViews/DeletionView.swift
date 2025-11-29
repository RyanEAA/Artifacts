//
//  DeletionView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/27/25.
//

import SwiftUI
import ARKit

struct DeletionView: View {
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var modelDeletionManager: ModelDeletionManager
    
    var body: some View {
        HStack {
            
            Spacer()
            
            DeletionButton(systemIconName: "xmark.circle.fill") {
                print("Cancel Deletion button Pressed")
                self.modelDeletionManager.entitySelectedForDeletion = nil
            }
            
            Spacer()

            
            DeletionButton(systemIconName: "trash.circle.fill") {
                print("Cofirm Deletion button Pressed")
                
                guard let anchorEntity = self.modelDeletionManager.entitySelectedForDeletion?.anchor else { return }
                
                guard let anchoringIdentifier = anchorEntity.anchorIdentifier else { return }
                
                if let index = self.sceneManager.anchorEntities.firstIndex(where: { $0.anchorIdentifier == anchoringIdentifier}) {
                    let entityToRemove = self.sceneManager.anchorEntities[index]
                    
                    // Find the ARAnchor identifier by searching through tracked anchors
                    // We'll match by checking if any tracked anchor's position matches this entity
                    let entityTransform = entityToRemove.transformMatrix(relativeTo: nil)
                    let entityPos = SIMD3<Float>(entityTransform.columns.3.x, entityTransform.columns.3.y, entityTransform.columns.3.z)
                    
                    // Search through all tracked artifact IDs to find a match
                    // Since we don't have direct access to ARAnchor here, we'll use a notification
                    // to let ARViewContainer handle the Firebase deletion
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DeleteArtifactByAnchorEntity"),
                        object: nil,
                        userInfo: [
                            "anchorEntityIdentifier": anchoringIdentifier.uuidString,
                            "entityPosition": [entityPos.x, entityPos.y, entityPos.z]
                        ]
                    )
                    
                    // Remove the anchor entity locally
                    entityToRemove.removeFromParent()
                    self.sceneManager.anchorEntities.remove(at: index)
                } else {
                    // If we can't find it in anchorEntities, just remove the entity
                    anchorEntity.removeFromParent()
                }
                
                self.modelDeletionManager.entitySelectedForDeletion = nil
            }
            
            Spacer()

        }
        .padding(.bottom, 30)
    }
}

struct DeletionButton: View{
    let systemIconName: String
    let action: () -> Void
    
    var body: some View{
        
        Button(action: {
            self.action()
        }) {
            Image(systemName: systemIconName)
                .font(.system(size: 50, weight: .light, design: .default))
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 75, height: 75)
        
    }
}

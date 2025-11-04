//
//  PlacementView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/10/25.
//

import SwiftUI

struct PlacementView: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    var body: some View {
        HStack {
            
            Spacer()
            
            // cancel button
            PlacementButton(systemIconName: "xmark.circle.fill") {
                print("Cancel Placement Button Pressed")
                self.placementSettings.selectedModel = nil
            }
            
            Spacer()
            
            // confirm button
            PlacementButton(systemIconName: "checkmark.circle.fill") {
                print("Confirm Placement Button Pressed")

                let modelAnchor = ModelAnchor(model: self.placementSettings.selectedModel!, anchor: nil)
                self.placementSettings.modelsConfirmedForPlacement.append(modelAnchor)
                
                self.placementSettings.selectedModel = nil
            }
            
            Spacer()
        }
        .padding(.bottom, 30)
    }
}

struct PlacementButton: View{
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

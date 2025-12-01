//
//  ContentView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/7/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @EnvironmentObject var modelDeletionManager: ModelDeletionManager
    @EnvironmentObject var sceneManager: SceneManager
    
    @State private var selectedControlMode: Int = 0
    @State private var isControlsVisible: Bool = true
    @State private var showBrowse: Bool = false
    @State private var showSettings: Bool = false
    
    var body: some View {
        
        ZStack(alignment: .bottom){
             //adding AR View Container
            ARViewContainer()
               
            
            if self.placementSettings.selectedModel != nil {
                PlacementView()
            } else if self.modelDeletionManager.entitySelectedForDeletion != nil {
                DeletionView()
            } else {
                ControlView(selectedControlMode: $selectedControlMode, isControlsVisible: $isControlsVisible, showBrowse: $showBrowse, showSettings: $showSettings)
            }

            if sceneManager.showInitialScanPrompt {
                VStack {
                    Text("Move your device to scan your space so we can find your scene.")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear() {
            self.modelsViewModel.fetchData()
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(PlacementSettings())
        .environmentObject(SessionSettings())
        .environmentObject(SceneManager())
        .environmentObject(ModelsViewModel())
        .environmentObject(ModelDeletionManager())
        .environmentObject(LocationProvider())
}

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
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear() {
            self.modelsViewModel.fetchData()
            self.ensureSignedIn()
        }
    }
    func ensureSignedIn() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error = error { print("Anon sign-in failed:", error) }
                else { print("Signed in as:", result?.user.uid ?? "nil") }
            }
        } else {
            print("Already signed in:", Auth.auth().currentUser?.uid ?? "nil")
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
}

//
//  ContentView.swift
//  ARTutorial
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
            ARViewContainer()
               
            
            switch placementSettings.selectedTool {
            case .model:
                PlacementView()
            case .draw:
                DrawingToolbarView()
            default:
                if sceneManager.activeAnnotationEditingId != nil {
                    AnnotationToolbarView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 24)
                } else if self.modelDeletionManager.entitySelectedForDeletion != nil {
                    DeletionView()
                } else {
                    ControlView(selectedControlMode: $selectedControlMode, isControlsVisible: $isControlsVisible, showBrowse: $showBrowse, showSettings: $showSettings)
                }
            }

            if placementSettings.isModelLoadInProgress {
                ModelSelectionLoadingOverlay(text: placementSettings.modelLoadMessage)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear() {
            self.modelsViewModel.fetchData()
            self.ensureSignedIn()
            LocationService.shared.start()
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

private struct ModelSelectionLoadingOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.20)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("MintGreen")))
                    .scaleEffect(1.12)

                Text(text.isEmpty ? "Preparing model..." : text)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color("MintGreen").opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .allowsHitTesting(true)
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

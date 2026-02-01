//
//  ControlView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/7/25.
//

import SwiftUI

enum ControlModes: String, CaseIterable {
    case browse, scene
}

struct BrowseButtons: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var showBrowse: Bool
    @Binding var showSettings: Bool
    @Binding var showProfile: Bool
    var body: some View{
            


                
            HStack{
                
                Spacer()
                
                // most recently pressed button
                MostRecentlyPlacedButton().hidden(self.placementSettings.recentlyPlaced.isEmpty)
                
                
                Spacer()
                Spacer()

                
                // browse button
                ControlButton(systemIconName: "square.grid.2x2"){
                    print("Browse Button Pressed...")
                    self.showBrowse.toggle()
                }.sheet(isPresented: $showBrowse) {
                    // browse view needs to be returned
                    BrowseView(showBrowse: $showBrowse)
                        .environmentObject(placementSettings)
                }
                
                Spacer()
                Spacer()

                
                // Settings button
                ControlButton(systemIconName: "slider.horizontal.3"){
                    print("Settings Button Pressed...")
                    self.showSettings.toggle()
                }.sheet(isPresented: $showSettings) {
                    SettingsView(showSettings: $showSettings)
                }
                Spacer()
                                    
            
        }
 
        
    }
}

// ControlView.swift → SceneButtons
struct SceneButtons: View {
    @EnvironmentObject var sceneManager: SceneManager

    var body: some View {
        // SAVE (cloud)
        ControlButton(systemIconName: "icloud.and.arrow.up") {
            print("Save Scene Button Pressed..")
            sceneManager.shouldSaveSceneToCloud = true
        }
        .hidden(!sceneManager.isPersistenceAvailable)

        Spacer()

        // ControlView.swift → SceneButtons

        // LOAD (cloud)
        ControlButton(systemIconName: "icloud.and.arrow.down") {
            print("Load Scene Button Pressed")

            // Re-fetch latest id on tap, then trigger load
            CloudSceneStore.fetchMostRecentSceneMeta { result in
                switch result {
                case .success(let meta):
                    if let meta {
                        DispatchQueue.main.async {
                            self.sceneManager.selectedCloudSceneId = meta.id
                            print("Attemping to load scene with id: \(meta.id)")
                            self.sceneManager.shouldLoadSceneFromCloud = true  // ARViewContainer will do the actual load
                        }
                    } else {
                        print("No cloud scene found to load.")
                    }
                case .failure(let e):
                    print("Failed to fetch latest scene meta on tap:", e)
                }
            }
        }
        .hidden(sceneManager.selectedCloudSceneId == nil) // shows once we have *some* id

        .onAppear {
            // Prime (fetch-only) the newest id so the Load button shows up, but DON'T load yet
            CloudSceneStore.fetchMostRecentSceneMeta { result in
                switch result {
                case .success(let meta):
                    if let meta {
                        DispatchQueue.main.async {
                            self.sceneManager.selectedCloudSceneId = meta.id // just set id; no load flag here
                        }
                    }
                case .failure(let e):
                    print("Failed to fetch latest scene meta on appear:", e)
                }
            }
        }



        Spacer()

        ControlButton(systemIconName: "trash") {
            print("clear scene button pressed")
            // Remove all 3D anchor entities
            for anchorEntity in sceneManager.anchorEntities {
                print("Removing anchoEntity with id: \(String(describing: anchorEntity.anchorIdentifier)))")
                anchorEntity.removeFromParent()
            }
            sceneManager.anchorEntities.removeAll()

            // Remove all 2D annotation views from the screen
            for (_, tv) in sceneManager.annotationViews {
                tv.removeFromSuperview()
            }
            sceneManager.annotationViews.removeAll()
            sceneManager.isEditing.removeAll()
            sceneManager.hasBeenTapped.removeAll()

            // Tell ARViewContainer to also remove the underlying ARAnchors
            NotificationCenter.default.post(name: .clearAllAnnotations, object: nil)
        }
    }
}



struct ControlView: View {
    @Binding var selectedControlMode: Int
    @Binding var isControlsVisible: Bool
    @Binding var showBrowse: Bool
    @Binding var showSettings: Bool
    @State private var showProfile=false
    var body: some View {
        VStack{
            HStack {
                // add button to show ProfileView()
                if isControlsVisible {
                    ProfileViewButton(isProfileVisible: $showProfile)
                        .sheet(isPresented: $showProfile) {
                            QuickProfileView()
                        }
                }

                Spacer()
                ControlVisibilityToggleButton(isControlsVisible: $isControlsVisible)
                
            }
            Spacer()
            if isControlsVisible {
                ControlModePicker(selectedControlMode: $selectedControlMode)
                //ControlButtonBar(showBrowse: $showBrowse, showSettings: //$showSettings, selectedControlMode: selectedControlMode)
                ControlButtonBar(showBrowse: $showBrowse, showSettings: $showSettings, showProfile: $showProfile, selectedControlMode: selectedControlMode)
            }
        }
    }
}

struct ControlVisibilityToggleButton: View{
    @Binding var isControlsVisible: Bool
    var body: some View{
        HStack{
            Spacer()
            
            ZStack {
                Color.black.opacity(0.25)
                
                Button(action: {
                    print("Control Visibility Toggle Button Pressed")
                    self.isControlsVisible.toggle()
                }) {
                    Image(systemName: self.isControlsVisible ? "rectangle" : "slider.horizontal.below.rectangle")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
        }
        .padding(.top, 45)
        .padding(.trailing, 20)

        
    }
}

struct ProfileViewButton: View{
    @Binding var isProfileVisible: Bool
    var body: some View{
        HStack{
            ZStack {
                Color.black.opacity(0.25)
                
                Button(action: {
                    print("Profile Button Pressed")
                    self.isProfileVisible.toggle()
                }) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
        }
        .padding(.top, 45)
        .padding(.leading, 20)

        
    }
}

struct ControlModePicker: View {
    @Binding var selectedControlMode: Int
    
    let controlModes = ControlModes.allCases
    
    init(selectedControlMode: Binding<Int>) {
        self._selectedControlMode = selectedControlMode
        
        UISegmentedControl.appearance().selectedSegmentTintColor = .clear
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(displayP3Red: 1.0, green: 0.827, blue: 0, alpha: 1)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        UISegmentedControl.appearance().backgroundColor = UIColor(Color.black.opacity(0.25))

    }
    
    var body: some View {
        Picker(selection: $selectedControlMode, label: Text("Select a Control Mode")) {
            ForEach(0..<controlModes.count) { index in
                Text(self.controlModes[index].rawValue.uppercased()).tag(index)
                
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(maxWidth: 400)
        .padding(.horizontal, 10)
        
    }
}

struct ControlButtonBar: View{
    @Binding var showBrowse: Bool
    @Binding var showSettings: Bool
    @Binding var showProfile: Bool
    var selectedControlMode: Int
    
    var body: some View {
        HStack(alignment: .center) {
            if selectedControlMode == 1 {
                SceneButtons()
            } else {
                //BrowseButtons(showBrowse: $showBrowse, showSettings: $showSettings)
                BrowseButtons(showBrowse: $showBrowse,
                                              showSettings: $showSettings,
                                             showProfile: $showProfile)
            }
        }
        .frame(maxWidth: 500)
        .padding(30)
        .background(Color.black.opacity(0.25))
    }
}

struct ControlButton: View {
    let systemIconName: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(systemName: self.systemIconName)
                .font(.system(size: 35))
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())
        }
    }
}

struct MostRecentlyPlacedButton: View{
    @EnvironmentObject var placementSettings: PlacementSettings
    var body: some View{
        Button(action:{
            print("most recently placed button pressed")
            self.placementSettings.selectedModel = self.placementSettings.recentlyPlaced.last
        }){
            if let mostRecentlyPlacedModel = self.placementSettings.recentlyPlaced.last {
                // colelction not empy
                Image(uiImage: mostRecentlyPlacedModel.thumbnail)
                    .resizable()
                    .frame(width: 46)
                    .aspectRatio(1/1, contentMode: .fit)
            } else {
                Image(systemName: "clock.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .buttonStyle(.plain)
            
            }
        }
        .frame(width: 50, height: 50)
        .background(Color.white)
        .cornerRadius(8)

    }
}

extension Notification.Name {
    static let clearAllAnnotations = Notification.Name("ClearAllAnnotationsNotification")
}

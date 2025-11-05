//
//  AppController.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@main
struct AppController: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var session = SessionManager()
    
    @StateObject var placementSettings = PlacementSettings()
    @StateObject var sessionSettings = SessionSettings()
    @StateObject var sceneManager = SceneManager()
    @StateObject var modelsViewModel = ModelsViewModel()
    @StateObject var modelDeletionManager = ModelDeletionManager()
    @StateObject var sessionManager = SessionManager()
    @StateObject var friendsService = FriendsService()


    var body: some Scene {
        WindowGroup {
            if session.isLoading {
                StoryboardView()
                    .ignoresSafeArea()
            } else if session.user != nil {
                
                ContentView()
                    .environmentObject(session)
                    .environmentObject(placementSettings)
                    .environmentObject(sessionSettings)
                    .environmentObject(sceneManager)
                    .environmentObject(modelsViewModel)
                    .environmentObject(modelDeletionManager)
                    .environmentObject(sessionManager)
                    .environmentObject(friendsService)
            } else {
                AuthView()
                    .environmentObject(session)
            }
        }
    }
}


struct StoryboardView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        let vc = storyboard.instantiateInitialViewController()!
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

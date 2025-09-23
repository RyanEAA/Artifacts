//
//  AppDelegate.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 9/17/25.
//

import UIKit
import FirebaseCore
//import GoogleSignIn FOR LATER

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

//    func application(_ app: UIApplication, FOR LATER
//                     open url: URL,
//                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
//        return GIDSignIn.sharedInstance.handle(url)
//    }
}

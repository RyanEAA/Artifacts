//
//  ARSessionState.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 3/22/26.
//

import SwiftUI
import ARKit

class ARSessionState: ObservableObject {
    @Published var trackingState: ARCamera.TrackingState = .normal
}
    
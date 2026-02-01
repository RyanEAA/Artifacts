//
//  SessionSettings.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/13/25.
//

import SwiftUI

class SessionSettings: ObservableObject {
    @Published var isPeopleOcclusionEnabled: Bool = false
    @Published var isObjectOcclusionEnabled: Bool = false
    @Published var isLidarDebugEnabled: Bool = false
    @Published var isCollaborationEnabled: Bool = false

}

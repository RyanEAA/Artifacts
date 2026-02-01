//
//  CustomARView.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/13/25.
//

import RealityKit
import ARKit
import FocusEntity
import SwiftUI
import Combine

class CustomARView: ARView{
    var focusEntity: FocusEntity?
    var sessionSettings: SessionSettings
    var modelDeletionManager: ModelDeletionManager
    
    var defaultCofiguration: ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.isCollaborationEnabled = sessionSettings.isCollaborationEnabled
        config.planeDetection = [.horizontal, .vertical]
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            // enabled lidar functionality
            config.sceneReconstruction = .mesh
        }
        
        return config
    }
    
    private var peopleOcclusionCancellable: AnyCancellable?
    private var objectOcclusionCancellable: AnyCancellable?
    private var lidarDebugCancellable: AnyCancellable?
    private var collaborationCancellable: AnyCancellable?

    
    required init(frame frameRect: CGRect, sessionSettings: SessionSettings, modelDeletionManager: ModelDeletionManager) {
        self.sessionSettings = sessionSettings
        self.modelDeletionManager = modelDeletionManager
        
        super.init(frame: frameRect)
        
        focusEntity = FocusEntity(on: self, focus: .classic)
        
        configure()
        
        self.initializeSettings()
        
        self.setupSubscribers()
        
        self.enableObjectDeletion()
    }
    
    required init(frame frameRect: CGRect){
        fatalError("init(frame:) has not been implemented")
    }
    
    @MainActor @preconcurrency required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configure(){
        
        session.run(defaultCofiguration)
    }
    
    private func initializeSettings() {
        self.updatePeopleOcclusion(isEnabled: sessionSettings.isPeopleOcclusionEnabled)
        self.updateObjectOcclusion(isEnabled: sessionSettings.isObjectOcclusionEnabled)
        self.updateLidarDebug(isEnabled: sessionSettings.isLidarDebugEnabled)
        self.updateCollaboration(isEnabled: sessionSettings.isCollaborationEnabled)

    }
    
    private func setupSubscribers(){
        self.peopleOcclusionCancellable = sessionSettings.$isPeopleOcclusionEnabled.sink { [weak self]
            isEnabled in
            self?.updatePeopleOcclusion(isEnabled: isEnabled)
        }
        
        self.objectOcclusionCancellable = sessionSettings.$isObjectOcclusionEnabled.sink { [weak self]
            isEnabled in
            self?.updateObjectOcclusion(isEnabled: isEnabled)
        }
        
        self.lidarDebugCancellable = sessionSettings.$isLidarDebugEnabled.sink { [weak self]
            isEnabled in
            self?.updateLidarDebug(isEnabled: isEnabled)
        }
        
        self.collaborationCancellable = sessionSettings.$isCollaborationEnabled.sink { [weak self]
            isEnabled in
            self?.updateCollaboration(isEnabled: isEnabled)
        }
    }
    
    private func updatePeopleOcclusion(isEnabled: Bool) {
        print("\(#file): isPeopleOcclusionEnabled: \(isEnabled)")
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else { return }
        guard let configuration = self.session.configuration as? ARWorldTrackingConfiguration else { return }

        if isEnabled {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else {
            configuration.frameSemantics.remove(.personSegmentationWithDepth)
        }

        self.session.run(configuration, options: [])
    }
    
    private func updateObjectOcclusion(isEnabled: Bool) {
        print("\(#file): updateObjectOcclusion: \(isEnabled)")
        if isEnabled {
            self.environment.sceneUnderstanding.options.insert(.occlusion)
        } else {
            self.environment.sceneUnderstanding.options.remove(.occlusion)
        }
    }
    
    private func updateLidarDebug(isEnabled: Bool) {
        print("\(#file): updateLidarDebug: \(isEnabled)")
        if isEnabled {
            self.debugOptions.insert(.showSceneUnderstanding)
        } else {
            self.debugOptions.remove(.showSceneUnderstanding)
        }
    }
    
    private func updateCollaboration(isEnabled: Bool) {
        print("\(#file): updateCollaboration: \(isEnabled)")
        
        guard let configuration = self.session.configuration as? ARWorldTrackingConfiguration else { return }

        configuration.isCollaborationEnabled = isEnabled

        // Changing collaboration should re-run configuration but NOT reset tracking unless needed
        self.session.run(configuration, options: [])
    }
}

// MARK: - Object Deletion Methods

extension CustomARView {
    func enableObjectDeletion() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action:
                                                                #selector(handleLongPress(recognizer:)))
        self.addGestureRecognizer(longPressGesture)
    }
    
    @objc func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: self)
        
        if let entity = self.entity(at: location) as? ModelEntity {
            modelDeletionManager.entitySelectedForDeletion = entity
        }
    }
}

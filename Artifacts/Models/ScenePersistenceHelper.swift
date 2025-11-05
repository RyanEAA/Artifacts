//
//  ScenePersistenceHelper.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/26/25.
//

import Foundation
import RealityKit
import ARKit

class ScenePersistenceHelper {
    class func captureWorldMapData(for arView: CustomARView,
                                   completion: @escaping (Result<Data, Error>) -> Void) {
        arView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap else {
                completion(.failure(error ?? NSError(domain: "Scene", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to capture world map"])))
                return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
    }
//    class func saveScene(for arView: CustomARView, at persistenceUrl: URL) {
//        print("Save Scene to local filesystem")
//        
//        // 1. get current worldMap from arView.session
//        arView.session.getCurrentWorldMap { worldMap, error in
//            
//            // 2. safely wrap worldMap
//            guard let map = worldMap else {
//                print("Persistence Error: Unable to get worldMap: \(error!.localizedDescription)")
//                return
//            }
//            
//            // 3. archive data and write to filesystem
//            do {
//                let sceneData = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
//                
//                try sceneData.write(to: persistenceUrl, options: [.atomic])
//            } catch {
//                print("Persistence Error: Can't save scene to local filesystem: \(error.localizedDescription)")
//            }
//        }
//    }
    
    class func loadScene(for arView: CustomARView, with scenePersistenceData: Data) {
        print("Load Scene from local filesystem")
        
        // 1. unarchive the scenePersistenceData and retrieve ARWorldMap
        let worldMap: ARWorldMap = {
            do {
                guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from:
                                                                            scenePersistenceData) else {
                    fatalError("Persistence")
                }
                
                return worldMap
            } catch {
                fatalError("Persistence Error: unable to unarchive ARWorldMap from scenePersistenceData: \(error.localizedDescription)")
            }
        }()
        
        // 2. reset configuration and load worldMap as initialWorldMap
        let newConfig = arView.defaultCofiguration
        newConfig.initialWorldMap = worldMap
        arView.session.run(newConfig, options: [.resetTracking, .removeExistingAnchors])
//        arView.session.run(newConfig, options: [.resetTracking])

    }
}

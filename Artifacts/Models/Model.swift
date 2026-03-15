//
//  Model.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/9/25.
//

import SwiftUI
import RealityKit // uses meters
import Combine

enum ModelCategory: String, CaseIterable {
    case table
    case chair
    case decor
    case light
    case toy
    
    var label: String {
        get {
            switch self {
            case .table:
                return "Tables"
            case .chair:
                return "Chair"
            case .decor:
                return "Decor"
            case .light:
                return "Light"
            case .toy:
                return "Toys"
            }
        }
    }
}

class Model: ObservableObject, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var category: ModelCategory
    @Published var thumbnail: UIImage
    var modelEntity: ModelEntity?
    var scaleCompensation: Float
    
    private var cancellable: Cancellable?
    private var loadHandlers: [(_ completed: Bool, _ error: Error?) -> Void] = []
    private var isLoadingModelEntity = false
    
    init(name: String, category: ModelCategory, scaleCompensation: Float = 1.0) {
        self.name = name
        self.category = category
        self.thumbnail = UIImage(systemName: "photo")!
        self.scaleCompensation = scaleCompensation
        
        FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "thumbnails/\(self.name).jpg") { localUrl in
            do {
                let imageData = try Data(contentsOf: localUrl)
                self.thumbnail = UIImage(data: imageData) ?? self.thumbnail
            } catch {
                print("Error loading image: \(error.localizedDescription)")
            }
        }
    }
    
    func asyncLoadModelEntity(handler: @escaping (_ completed: Bool, _ error: Error?) -> Void ) {
        if let modelEntity {
            handler(true, nil)
            return
        }

        loadHandlers.append(handler)
        guard !isLoadingModelEntity else { return }
        isLoadingModelEntity = true

        FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(self.name).usdz") { localUrl in
            self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl)
                .sink ( receiveCompletion: {loadCompletion in
                    switch loadCompletion {
                    case .finished:
                        break
                    case .failure(let failure):
                        print("Unable to load model for \(self.name). Error: \(failure.localizedDescription)")
                        self.finishModelEntityLoad(completed: false, error: failure)
                    }
                    }, receiveValue: { modelEntity in
                        self.modelEntity = modelEntity
                        self.modelEntity?.scale *= self.scaleCompensation
                        print("model entity for \(self.name) has been loaded")
                        self.finishModelEntityLoad(completed: true, error: nil)
                    })
        }

    }

    private func finishModelEntityLoad(completed: Bool, error: Error?) {
        let handlers = loadHandlers
        loadHandlers.removeAll()
        isLoadingModelEntity = false
        handlers.forEach { $0(completed, error) }
    }
}

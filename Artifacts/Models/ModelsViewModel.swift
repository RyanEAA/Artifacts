//
//  ModelsViewModel.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/22/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

class ModelsViewModel: ObservableObject {
    @Published var models: [Model] = []
    private var prewarmInFlight: Set<String> = []
    private var prewarmedNames: Set<String> = []
    
    // creating db constant
    private let db = Firestore.firestore()
    
    // gets model data from database
    func fetchData() {
        db.collection("models").addSnapshotListener { (querySnapshot, error ) in
            guard let documents = querySnapshot?.documents else {
                print("No documents")
                return
            }
            
            self.models = documents.map { (queryDocumentSnapshot) -> Model in
                let data = queryDocumentSnapshot.data()
                
                let name = data["name"] as? String ?? ""
                let categoryText = data["category"] as? String ?? ""
                let  category = ModelCategory(rawValue: categoryText) ?? .decor
                let scaleCompensation = data["scaleCompensation"] as? Double ?? 1.0
                
                return Model(name: name, category: category, scaleCompensation: Float(scaleCompensation))
            }

            self.prewarmModelEntities(limit: 8)
        }
    }
    
    func clearModelEntityFromMemory() {
        for model in models {
            model.modelEntity = nil
        }
    }

    private func prewarmModelEntities(limit: Int) {
        guard limit > 0 else { return }

        var started = 0
        for model in models {
            guard started < limit else { break }
            guard model.modelEntity == nil else { continue }
            guard !prewarmInFlight.contains(model.name) else { continue }
            guard !prewarmedNames.contains(model.name) else { continue }

            prewarmInFlight.insert(model.name)
            started += 1

            model.asyncLoadModelEntity { [weak self] completed, _ in
                guard let self = self else { return }
                self.prewarmInFlight.remove(model.name)
                if completed {
                    self.prewarmedNames.insert(model.name)
                }
            }
        }
    }
}

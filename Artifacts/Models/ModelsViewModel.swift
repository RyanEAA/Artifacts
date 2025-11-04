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
        }
    }
    
    func clearModelEntityFromMemory() {
        for model in models {
            model.modelEntity = nil
        }
    }
}

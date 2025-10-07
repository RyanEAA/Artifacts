//
//  FirestoreModels.swift
//  Artifacts
//
//  Created by Swapnil Puri on 10/6/25.
//

import Foundation
import FirebaseFirestore

struct UserModel: Codable {
    @DocumentID var id: String?
    var username: String
    var email: String
    var bio: String
    var friendsCount: Int
    var artifactsCount: Int
    var createdAt: Date
    var lastActive: Date
}

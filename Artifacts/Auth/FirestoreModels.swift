//
//  FirestoreModels.swift
//  Artifacts
//
//  Created by Swapnil Puri on 10/6/25.
//

import Foundation
import FirebaseFirestore
import MapKit

struct UserModel: Codable {
    @DocumentID var id: String?
    var username: String
    var email: String
    var createdAt: Date
    var lastActive: Date
    var profilePictureURL: String?
}

struct Post: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let username: String
    let date: String
    let coordinate: CLLocationCoordinate2D
    let profileImage: String
    var visited: Bool = false

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id
    }
}

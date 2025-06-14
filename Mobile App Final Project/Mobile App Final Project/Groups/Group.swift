//
//  Group.swift
//  Woodpecker Map
//
//  Created by Gift G on 11/11/24.
//

import Foundation
import FirebaseFirestore

struct Group: Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore document ID
    var name: String
    var description: String
    var members: [String] // Array of user IDs
    var imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case members
        case imageURL
    }
}

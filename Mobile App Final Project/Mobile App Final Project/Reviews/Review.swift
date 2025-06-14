//
//  Review.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/26/24.
//


import Foundation
import FirebaseFirestore

struct Review: Identifiable, Codable {
    @DocumentID var id: String?
    var pinID: String
    var userID: String
    var priceRating: Int // 1-3
    var overallRating: Int // 1-5
    var notes: String
    var imageURLs: [String]
    var createdAt: Timestamp
    var groupIDs: [String]
}

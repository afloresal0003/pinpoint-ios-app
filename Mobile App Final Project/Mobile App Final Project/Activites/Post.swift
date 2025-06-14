// Post.swift
import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    @DocumentID var id: String? // Firestore manages this
    var details: PostDetails
    var groupID: String
    var likeCount: Int
    var likedBy: [String]
    var pinID: String
    var timestamp: Date
    var userID: String

    enum CodingKeys: String, CodingKey {
        case id
        case details
        case groupID
        case likeCount
        case likedBy
        case pinID
        case timestamp
        case userID
    }
}

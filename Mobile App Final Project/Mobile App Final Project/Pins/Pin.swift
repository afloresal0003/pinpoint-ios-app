// Pin.swift
import Foundation
import FirebaseFirestore

struct Pin: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var address: String
    var location: GeoPoint
    var groupIDs: [String]
    var createdAt: Timestamp
    var isAdded: Bool?
    var pricingLevel: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case location
        case groupIDs
        case createdAt
        case isAdded
        case pricingLevel
    }
}


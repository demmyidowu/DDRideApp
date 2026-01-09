//
//  DDAssignment.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

// Stored as subcollection: events/{eventId}/ddAssignments/{userId}
struct DDAssignment: Codable, Identifiable, Equatable {
    var id: String // Same as userId
    var userId: String
    var eventId: String
    var photoURL: String? // DD's photo for rider identification
    var carDescription: String? // e.g., "Blue Toyota Camry"
    var isActive: Bool
    var inactiveToggles: Int // Track how many times DD toggled inactive
    var lastActiveTimestamp: Date?
    var lastInactiveTimestamp: Date?
    var totalRidesCompleted: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case eventId
        case photoURL
        case carDescription
        case isActive
        case inactiveToggles
        case lastActiveTimestamp
        case lastInactiveTimestamp
        case totalRidesCompleted
        case createdAt
        case updatedAt
    }
}

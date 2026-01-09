//
//  DDAssignment.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct DDAssignment: Codable, Identifiable, Equatable {
    let id: String
    var ddId: String
    var eventId: String
    var chapterId: String
    var isActive: Bool
    var startTime: Date
    var endTime: Date
    var assignedBy: String // User ID
    var createdAt: Date
    var updatedAt: Date
    var inactiveToggles: [InactiveToggle]

    var activeRidesCount: Int?
    var completedRidesCount: Int?
}

struct InactiveToggle: Codable, Equatable {
    var toggledAt: Date
    var reason: String?
}

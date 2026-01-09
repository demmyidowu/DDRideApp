//
//  AdminAlert.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct AdminAlert: Codable, Identifiable, Equatable {
    let id: String
    var chapterId: String
    var type: AlertType
    var message: String
    var ddId: String? // For DD-related alerts
    var rideId: String? // For ride-related alerts
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case chapterId
        case type
        case message
        case ddId
        case rideId
        case isRead
        case createdAt
    }
}

enum AlertType: String, Codable, CaseIterable {
    case ddInactiveToggle = "dd_inactive_toggle" // DD toggled inactive >5 times in 30 min
    case ddProlongedInactive = "dd_prolonged_inactive" // DD inactive >15 min during shift
    case emergencyRide = "emergency_ride" // Emergency button pressed
    case systemError = "system_error" // System-level errors

    var displayName: String {
        switch self {
        case .ddInactiveToggle: return "DD Inactive Toggle"
        case .ddProlongedInactive: return "DD Prolonged Inactive"
        case .emergencyRide: return "Emergency Ride"
        case .systemError: return "System Error"
        }
    }
}

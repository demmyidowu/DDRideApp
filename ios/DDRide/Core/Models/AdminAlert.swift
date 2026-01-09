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
    case ddInactive = "dd_inactive"
    case emergencyRequest = "emergency_request"
    case yearTransition = "year_transition"

    var displayName: String {
        switch self {
        case .ddInactive: return "DD Inactive"
        case .emergencyRequest: return "Emergency Request"
        case .yearTransition: return "Year Transition"
        }
    }

    var iconName: String {
        switch self {
        case .ddInactive: return "exclamationmark.triangle"
        case .emergencyRequest: return "exclamationmark.circle.fill"
        case .yearTransition: return "calendar"
        }
    }
}

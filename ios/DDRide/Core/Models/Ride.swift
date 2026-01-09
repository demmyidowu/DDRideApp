//
//  Ride.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import FirebaseFirestore

struct Ride: Codable, Identifiable, Equatable {
    let id: String
    var riderId: String
    var ddId: String?
    var chapterId: String
    var eventId: String
    var pickupLocation: GeoPoint // Firebase GeoPoint for geolocation queries
    var pickupAddress: String
    var dropoffAddress: String?
    var status: RideStatus
    /// Priority algorithm: (classYear × 10) + (waitTime × 0.5), or 9999 for emergency
    var priority: Double
    var isEmergency: Bool
    var estimatedWaitTime: Int? // Minutes until DD arrives
    var queuePosition: Int? // Overall position across all DDs
    var requestedAt: Date
    var assignedAt: Date?
    var enrouteAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var cancellationReason: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case riderId
        case ddId
        case chapterId
        case eventId
        case pickupLocation
        case pickupAddress
        case dropoffAddress
        case status
        case priority
        case isEmergency
        case estimatedWaitTime
        case queuePosition
        case requestedAt
        case assignedAt
        case enrouteAt
        case completedAt
        case cancelledAt
        case cancellationReason
        case notes
    }

    static func == (lhs: Ride, rhs: Ride) -> Bool {
        lhs.id == rhs.id
    }
}

enum RideStatus: String, Codable, CaseIterable {
    case queued = "queued"
    case assigned = "assigned"
    case enroute = "enroute"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .assigned: return "Assigned"
        case .enroute: return "En Route"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

//
//  Ride.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import CoreLocation

struct Ride: Codable, Identifiable, Equatable {
    let id: String
    var riderId: String
    var ddId: String?
    var eventId: String?
    var chapterId: String
    var status: RideStatus
    var pickupLocation: Location
    var dropoffLocation: Location?
    var requestedAt: Date
    var assignedAt: Date?
    var enrouteAt: Date?
    var completedAt: Date?
    var canceledAt: Date?
    var priority: Double
    var isEmergency: Bool
    var notes: String?
    var estimatedArrivalTime: Date?

    static func == (lhs: Ride, rhs: Ride) -> Bool {
        lhs.id == rhs.id
    }
}

enum RideStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case assigned = "assigned"
    case enroute = "enroute"
    case completed = "completed"
    case canceled = "canceled"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .assigned: return "Assigned"
        case .enroute: return "En Route"
        case .completed: return "Completed"
        case .canceled: return "Canceled"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .assigned: return "blue"
        case .enroute: return "green"
        case .completed: return "gray"
        case .canceled: return "red"
        }
    }
}

struct Location: Codable, Equatable {
    var address: String
    var latitude: Double
    var longitude: Double
    var capturedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(address: String, latitude: Double, longitude: Double, capturedAt: Date = Date()) {
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.capturedAt = capturedAt
    }

    init(address: String, coordinate: CLLocationCoordinate2D, capturedAt: Date = Date()) {
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.capturedAt = capturedAt
    }
}

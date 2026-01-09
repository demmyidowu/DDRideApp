//
//  Ride.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct Ride: Codable, Identifiable, Equatable {
    let id: String
    var eventId: String
    var riderId: String
    var riderName: String
    var riderPhoneNumber: String
    var ddId: String?
    var ddName: String?
    var ddPhoneNumber: String?
    var ddCarDescription: String?
    var pickupAddress: String
    var pickupLocation: GeoPoint // Firestore GeoPoint for location queries
    var status: RideStatus
    var priority: Double // Calculated: (classYear × 10) + (waitTime × 0.5), emergency = 9999
    var estimatedETA: Int? // Minutes
    var requestTime: Date
    var assignedTime: Date?
    var enrouteTime: Date?
    var completionTime: Date?
    var isEmergency: Bool
    var emergencyReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case riderId
        case riderName
        case riderPhoneNumber
        case ddId
        case ddName
        case ddPhoneNumber
        case ddCarDescription
        case pickupAddress
        case pickupLocation
        case status
        case priority
        case estimatedETA
        case requestTime
        case assignedTime
        case enrouteTime
        case completionTime
        case isEmergency
        case emergencyReason
    }

    // Helper to convert CLLocationCoordinate2D to GeoPoint
    init(
        id: String,
        eventId: String,
        riderId: String,
        riderName: String,
        riderPhoneNumber: String,
        pickupAddress: String,
        pickupCoordinate: CLLocationCoordinate2D,
        status: RideStatus = .queued,
        priority: Double = 0,
        isEmergency: Bool = false,
        emergencyReason: String? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.riderId = riderId
        self.riderName = riderName
        self.riderPhoneNumber = riderPhoneNumber
        self.pickupAddress = pickupAddress
        self.pickupLocation = GeoPoint(latitude: pickupCoordinate.latitude, longitude: pickupCoordinate.longitude)
        self.status = status
        self.priority = priority
        self.requestTime = Date()
        self.isEmergency = isEmergency
        self.emergencyReason = emergencyReason
    }

    // CLLocationCoordinate2D helper
    var pickupCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pickupLocation.latitude, longitude: pickupLocation.longitude)
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

    var color: String {
        switch self {
        case .queued: return "orange"
        case .assigned: return "blue"
        case .enroute: return "green"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

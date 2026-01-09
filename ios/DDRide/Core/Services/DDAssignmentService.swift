//
//  DDAssignmentService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import Combine

/// Service for DD assignment logic and activity monitoring
///
/// This service implements critical business logic for:
/// - Finding the best DD based on SHORTEST WAIT TIME (not lowest ride count)
/// - Assigning rides to DDs atomically
/// - Monitoring DD activity (inactive toggles, prolonged inactivity)
/// - Generating admin alerts for DD issues
///
/// Example Usage:
/// ```swift
/// let service = DDAssignmentService.shared
///
/// // Find best available DD for a ride
/// let bestDD = try await service.findBestDD(for: event, rides: allRides)
///
/// // Assign ride to DD
/// try await service.assignRide(ride, to: bestDD)
///
/// // Check for DD monitoring alerts
/// if let alert = try await service.checkInactiveToggles(ddAssignment: assignment) {
///     // Handle admin alert
/// }
/// ```
@MainActor
class DDAssignmentService: ObservableObject {
    static let shared = DDAssignmentService()

    private let firestoreService = FirestoreService.shared
    private let queueService = RideQueueService.shared
    private var cancellables = Set<AnyCancellable>()

    // Constants for monitoring thresholds
    private let averageRideTimeMinutes: Double = 15.0
    private let inactiveToggleThreshold: Int = 5
    private let prolongedInactivityMinutes: Double = 15.0

    private init() {}

    // MARK: - Wait Time Calculation

    /// Calculate wait time for a DD based on their current active rides
    ///
    /// If DD has no active rides → 0 minutes
    /// If DD has rides → sum of estimated time for all queued/active rides
    /// Average ride time: 15 minutes per ride
    ///
    /// - Parameters:
    ///   - ddAssignment: The DD assignment to calculate wait time for
    ///   - rides: All active rides for the event
    /// - Returns: Wait time in seconds (TimeInterval)
    func calculateWaitTime(for ddAssignment: DDAssignment, with rides: [Ride]) async throws -> TimeInterval {
        // Filter rides assigned to this DD
        let ddRides = rides.filter { $0.ddId == ddAssignment.userId }

        // Only count active rides (queued, assigned, enroute)
        let activeRides = ddRides.filter {
            $0.status == .queued || $0.status == .assigned || $0.status == .enroute
        }

        // If no active rides, wait time is 0
        if activeRides.isEmpty {
            return 0
        }

        // Calculate total wait time: number of rides × average ride time
        let totalMinutes = Double(activeRides.count) * averageRideTimeMinutes

        // Convert to seconds
        return totalMinutes * 60.0
    }

    /// Calculate wait times for all DDs at once
    ///
    /// - Parameters:
    ///   - ddAssignments: All DD assignments
    ///   - rides: All active rides
    /// - Returns: Dictionary mapping DD ID to wait time in seconds
    func calculateWaitTimes(for ddAssignments: [DDAssignment], with rides: [Ride]) async -> [String: TimeInterval] {
        var waitTimes: [String: TimeInterval] = [:]

        for dd in ddAssignments {
            do {
                let waitTime = try await calculateWaitTime(for: dd, with: rides)
                waitTimes[dd.userId] = waitTime
            } catch {
                // If calculation fails, assume 0 wait time
                waitTimes[dd.userId] = 0
            }
        }

        return waitTimes
    }

    // MARK: - Find Best DD (CRITICAL ALGORITHM)

    /// Find the best DD to assign a ride to
    ///
    /// CRITICAL: This always assigns to the DD with the SHORTEST WAIT TIME
    /// NOT the DD with the lowest ride count!
    ///
    /// Algorithm:
    /// 1. Fetch all active DD assignments for the event
    /// 2. For each DD, calculate wait time (number of active rides × 15 min)
    /// 3. Select DD with MINIMUM wait time
    /// 4. If multiple DDs have same wait time, pick first one
    /// 5. Return nil if no active DDs available
    ///
    /// - Parameters:
    ///   - event: The event to find DD for
    ///   - rides: All active rides for the event (to calculate wait times)
    /// - Returns: The best DD assignment, or nil if none available
    /// - Throws: FirestoreError if operation fails
    func findBestDD(for event: Event, rides: [Ride]) async throws -> DDAssignment? {
        // Fetch all active DD assignments for the event
        let activeDDs = try await firestoreService.fetchActiveDDAssignments(eventId: event.id)

        // If no active DDs, return nil
        guard !activeDDs.isEmpty else {
            return nil
        }

        // Calculate wait time for each DD
        let waitTimes = await calculateWaitTimes(for: activeDDs, with: rides)

        // Find DD with minimum wait time
        let bestDD = activeDDs.min { dd1, dd2 in
            let waitTime1 = waitTimes[dd1.userId] ?? .infinity
            let waitTime2 = waitTimes[dd2.userId] ?? .infinity
            return waitTime1 < waitTime2
        }

        return bestDD
    }

    /// Find best DD for a specific ride
    ///
    /// - Parameter ride: The ride to find DD for
    /// - Returns: The best DD assignment, or nil if none available
    func findBestDD(for ride: Ride) async throws -> DDAssignment? {
        let event = try await firestoreService.fetchEvent(id: ride.eventId)
        let rides = try await firestoreService.fetchActiveRides(eventId: ride.eventId)

        return try await findBestDD(for: event, rides: rides)
    }

    // MARK: - Assign Ride

    /// Assign a ride to a DD atomically
    ///
    /// Updates:
    /// - ride.status = .assigned
    /// - ride.ddId = ddAssignment.userId
    /// - ride.assignedAt = current Date
    /// - ride.estimatedWaitTime = calculated wait time
    /// - ride.queuePosition = overall queue position
    ///
    /// - Parameters:
    ///   - ride: The ride to assign
    ///   - ddAssignment: The DD to assign to
    /// - Throws: FirestoreError if operation fails
    func assignRide(_ ride: Ride, to ddAssignment: DDAssignment) async throws {
        // Fetch DD user info
        let ddUser = try await firestoreService.fetchUser(id: ddAssignment.userId)

        // Calculate estimated wait time
        let allRides = try await firestoreService.fetchActiveRides(eventId: ride.eventId)
        let waitTimeSeconds = try await calculateWaitTime(for: ddAssignment, with: allRides)
        let waitTimeMinutes = Int(waitTimeSeconds / 60.0)

        // Calculate queue position
        let position = try await queueService.getOverallQueuePosition(rideId: ride.id, eventId: ride.eventId)

        // Update ride
        var updatedRide = ride
        updatedRide.status = .assigned
        updatedRide.ddId = ddAssignment.userId
        updatedRide.assignedAt = Date()
        updatedRide.estimatedWaitTime = waitTimeMinutes
        updatedRide.queuePosition = position

        // Save updated ride
        try await firestoreService.updateRide(updatedRide)
    }

    /// Auto-assign next ride in queue to best available DD
    ///
    /// - Parameter eventId: The event ID
    /// - Returns: The assigned ride, or nil if no rides to assign
    func assignNextRide(eventId: String) async throws -> Ride? {
        // Fetch active rides
        let rides = try await firestoreService.fetchActiveRides(eventId: eventId)

        // Filter to only queued rides (not yet assigned)
        let queuedRides = rides.filter { $0.status == .queued }

        // If no queued rides, return nil
        guard let nextRide = queuedRides.sorted(by: { $0.priority > $1.priority }).first else {
            return nil
        }

        // Find best DD
        let event = try await firestoreService.fetchEvent(id: eventId)
        guard let bestDD = try await findBestDD(for: event, rides: rides) else {
            // No available DDs
            return nil
        }

        // Assign ride
        try await assignRide(nextRide, to: bestDD)

        return nextRide
    }

    // MARK: - DD Activity Monitoring

    /// Check if DD has toggled inactive too many times
    ///
    /// Alert threshold: >5 inactive toggles in 30 minutes
    ///
    /// - Parameter ddAssignment: The DD assignment to check
    /// - Returns: AdminAlert if threshold exceeded, nil otherwise
    func checkInactiveToggles(ddAssignment: DDAssignment) async throws -> AdminAlert? {
        // Check if toggle count exceeds threshold
        guard ddAssignment.inactiveToggles > inactiveToggleThreshold else {
            return nil
        }

        // Check if last toggle was within 30 minutes
        if let lastInactive = ddAssignment.lastInactiveTimestamp {
            let minutesSinceLastToggle = Date().timeIntervalSince(lastInactive) / 60.0

            // Only alert if within 30 minutes
            guard minutesSinceLastToggle <= 30 else {
                return nil
            }
        }

        // Fetch DD user and event info
        let ddUser = try await firestoreService.fetchUser(id: ddAssignment.userId)
        let event = try await firestoreService.fetchEvent(id: ddAssignment.eventId)

        // Create admin alert
        let alert = AdminAlert(
            id: UUID().uuidString,
            chapterId: event.chapterId,
            type: .ddInactiveToggle,
            message: "\(ddUser.name) has toggled inactive \(ddAssignment.inactiveToggles) times in the last 30 minutes",
            ddId: ddAssignment.userId,
            rideId: nil,
            isRead: false,
            createdAt: Date()
        )

        return alert
    }

    /// Check if DD has been inactive for too long during their shift
    ///
    /// Alert threshold: >15 minutes inactive during shift
    ///
    /// - Parameter ddAssignment: The DD assignment to check
    /// - Returns: AdminAlert if threshold exceeded, nil otherwise
    func checkProlongedInactivity(ddAssignment: DDAssignment) async throws -> AdminAlert? {
        // Only check if DD is currently inactive
        guard !ddAssignment.isActive else {
            return nil
        }

        // Check if last inactive timestamp exists
        guard let lastInactive = ddAssignment.lastInactiveTimestamp else {
            return nil
        }

        // Calculate minutes inactive
        let minutesInactive = Date().timeIntervalSince(lastInactive) / 60.0

        // Check if exceeds threshold
        guard minutesInactive > prolongedInactivityMinutes else {
            return nil
        }

        // Fetch DD user and event info
        let ddUser = try await firestoreService.fetchUser(id: ddAssignment.userId)
        let event = try await firestoreService.fetchEvent(id: ddAssignment.eventId)

        // Create admin alert
        let alert = AdminAlert(
            id: UUID().uuidString,
            chapterId: event.chapterId,
            type: .ddProlongedInactive,
            message: "\(ddUser.name) has been inactive for \(Int(minutesInactive)) minutes during their shift",
            ddId: ddAssignment.userId,
            rideId: nil,
            isRead: false,
            createdAt: Date()
        )

        return alert
    }

    /// Monitor DD activity and create alerts if needed
    ///
    /// This should be called whenever a DD toggles inactive
    ///
    /// - Parameter ddAssignment: The DD assignment to monitor
    /// - Returns: Array of generated alerts (if any)
    func monitorDDActivity(ddAssignment: DDAssignment) async throws -> [AdminAlert] {
        var alerts: [AdminAlert] = []

        // Check for inactive toggles
        if let toggleAlert = try await checkInactiveToggles(ddAssignment: ddAssignment) {
            alerts.append(toggleAlert)
            try await firestoreService.createAdminAlert(toggleAlert)
        }

        // Check for prolonged inactivity
        if let inactivityAlert = try await checkProlongedInactivity(ddAssignment: ddAssignment) {
            alerts.append(inactivityAlert)
            try await firestoreService.createAdminAlert(inactivityAlert)
        }

        return alerts
    }

    // MARK: - DD Toggle Management

    /// Toggle DD active/inactive status
    ///
    /// Updates:
    /// - isActive flag
    /// - lastActiveTimestamp or lastInactiveTimestamp
    /// - inactiveToggles count (if toggling to inactive)
    /// - Monitors for alerts
    ///
    /// - Parameters:
    ///   - ddAssignment: The DD assignment to toggle
    ///   - isActive: New active status
    /// - Returns: Array of generated alerts (if any)
    func toggleDDStatus(ddAssignment: DDAssignment, isActive: Bool) async throws -> [AdminAlert] {
        var updatedAssignment = ddAssignment
        updatedAssignment.isActive = isActive

        if isActive {
            // Toggling to active
            updatedAssignment.lastActiveTimestamp = Date()
        } else {
            // Toggling to inactive
            updatedAssignment.lastInactiveTimestamp = Date()
            updatedAssignment.inactiveToggles += 1
        }

        // Save updated assignment
        try await firestoreService.updateDDAssignment(updatedAssignment)

        // Monitor for alerts
        return try await monitorDDActivity(ddAssignment: updatedAssignment)
    }

    // MARK: - DD Statistics

    /// Get statistics for a DD during an event
    ///
    /// - Parameters:
    ///   - ddId: The DD's user ID
    ///   - eventId: The event ID
    /// - Returns: DD statistics
    func getDDStats(ddId: String, eventId: String) async throws -> DDStats {
        let assignment = try await firestoreService.fetchDDAssignment(id: ddId)
        let rides = try await firestoreService.fetchDDRides(ddId: ddId, eventId: eventId)

        let completedRides = rides.filter { $0.status == .completed }
        let activeRides = rides.filter {
            $0.status == .queued || $0.status == .assigned || $0.status == .enroute
        }

        let avgCompletionTime: Double
        if !completedRides.isEmpty {
            let totalTime = completedRides.compactMap { ride -> TimeInterval? in
                guard let assigned = ride.assignedAt,
                      let completed = ride.completedAt else {
                    return nil
                }
                return completed.timeIntervalSince(assigned)
            }.reduce(0, +)

            avgCompletionTime = totalTime / Double(completedRides.count) / 60.0 // Convert to minutes
        } else {
            avgCompletionTime = 0
        }

        return DDStats(
            totalRidesCompleted: assignment.totalRidesCompleted,
            currentActiveRides: activeRides.count,
            isActive: assignment.isActive,
            inactiveToggles: assignment.inactiveToggles,
            averageCompletionMinutes: Int(avgCompletionTime)
        )
    }

    // MARK: - Batch DD Updates

    /// Reset inactive toggle counts for all DDs in an event
    ///
    /// This should be called periodically (e.g., every 30 minutes)
    ///
    /// - Parameter eventId: The event ID
    func resetInactiveToggles(eventId: String) async throws {
        let assignments = try await firestoreService.fetchAllDDAssignments(eventId: eventId)

        for assignment in assignments {
            var updated = assignment
            updated.inactiveToggles = 0
            try await firestoreService.updateDDAssignment(updated)
        }
    }
}

// MARK: - Supporting Types

/// Statistics for a DD during an event
struct DDStats {
    let totalRidesCompleted: Int
    let currentActiveRides: Int
    let isActive: Bool
    let inactiveToggles: Int
    let averageCompletionMinutes: Int
}

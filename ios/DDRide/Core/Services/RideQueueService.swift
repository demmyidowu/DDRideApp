//
//  RideQueueService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import Combine

/// Service for managing ride queue operations and priority calculations
///
/// This service implements the critical business logic for:
/// - Priority calculation using the formula: (classYear × 10) + (waitMinutes × 0.5)
/// - Emergency rides get priority 9999
/// - Overall queue position across all DDs (not per-DD)
/// - Estimated wait time calculations
///
/// Example Usage:
/// ```swift
/// let service = RideQueueService.shared
///
/// // Calculate priority for a ride
/// let priority = service.calculatePriority(classYear: 4, waitMinutes: 5, isEmergency: false)
/// // Result: (4 × 10) + (5 × 0.5) = 42.5
///
/// // Get overall queue position
/// let position = try await service.getOverallQueuePosition(rideId: "ride123", eventId: "event456")
/// // Result: 3 (3rd in line overall, not per-DD)
/// ```
@MainActor
class RideQueueService: ObservableObject {
    static let shared = RideQueueService()

    private let firestoreService = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()

    // Constants
    private let emergencyPriority: Double = 9999.0
    private let classYearWeight: Double = 10.0
    private let waitTimeWeight: Double = 0.5
    private let averageRideTimeMinutes: Double = 15.0

    private init() {}

    // MARK: - Priority Calculation

    /// Calculate priority for a ride based on class year, wait time, and emergency status
    ///
    /// Algorithm: (classYear × 10) + (waitMinutes × 0.5)
    /// Emergency rides always get priority 9999
    ///
    /// Examples:
    /// - Senior (4) waiting 5 min: (4×10) + (5×0.5) = 42.5
    /// - Junior (3) waiting 10 min: (3×10) + (10×0.5) = 35.0
    /// - Sophomore (2) waiting 20 min: (2×10) + (20×0.5) = 30.0
    /// - Freshman (1) waiting 15 min: (1×10) + (15×0.5) = 17.5
    /// - Emergency (any): 9999
    ///
    /// - Parameters:
    ///   - classYear: Student's class year (1=freshman, 2=sophomore, 3=junior, 4=senior)
    ///   - waitMinutes: How many minutes the rider has been waiting
    ///   - isEmergency: Whether this is an emergency ride request
    /// - Returns: The calculated priority (higher = more priority)
    func calculatePriority(classYear: Int, waitMinutes: Double, isEmergency: Bool) -> Double {
        if isEmergency {
            return emergencyPriority
        }

        let classYearPriority = Double(classYear) * classYearWeight
        let waitTimePriority = waitMinutes * waitTimeWeight

        return classYearPriority + waitTimePriority
    }

    /// Calculate priority for an existing ride based on current time
    ///
    /// - Parameter ride: The ride to calculate priority for
    /// - Returns: The calculated priority
    func calculateCurrentPriority(for ride: Ride) -> Double {
        let waitMinutes = Date().timeIntervalSince(ride.requestedAt) / 60.0
        return calculatePriority(
            classYear: 0, // Will need to fetch user's classYear separately
            waitMinutes: waitMinutes,
            isEmergency: ride.isEmergency
        )
    }

    /// Update ride priority based on current wait time
    ///
    /// - Parameters:
    ///   - ride: The ride to update
    ///   - classYear: The rider's class year
    func updateRidePriority(_ ride: inout Ride, classYear: Int) {
        let waitMinutes = Date().timeIntervalSince(ride.requestedAt) / 60.0
        ride.priority = calculatePriority(
            classYear: classYear,
            waitMinutes: waitMinutes,
            isEmergency: ride.isEmergency
        )
    }

    // MARK: - Queue Position

    /// Get the overall queue position for a ride across ALL DDs
    ///
    /// This returns the rider's position in the OVERALL queue, not per-DD.
    /// For example, if there are 10 total active rides across 3 DDs,
    /// and this ride has the 4th highest priority, it returns 4.
    ///
    /// - Parameters:
    ///   - rideId: The ride ID to get position for
    ///   - eventId: The event ID
    /// - Returns: Queue position (1-indexed, 1 = first in line)
    /// - Throws: FirestoreError if operation fails
    func getOverallQueuePosition(rideId: String, eventId: String) async throws -> Int {
        // Fetch all active rides for the event
        let allRides = try await firestoreService.fetchActiveRides(eventId: eventId)

        // Sort by priority (descending - higher priority first)
        let sortedRides = allRides.sorted { $0.priority > $1.priority }

        // Find the position of this ride (1-indexed)
        if let index = sortedRides.firstIndex(where: { $0.id == rideId }) {
            return index + 1 // Convert 0-indexed to 1-indexed
        }

        // If ride not found in active rides, it might be completed/cancelled
        throw FirestoreError.documentNotFound
    }

    /// Get queue positions for multiple rides at once
    ///
    /// - Parameter eventId: The event ID
    /// - Returns: Dictionary mapping ride ID to queue position
    func getQueuePositions(eventId: String) async throws -> [String: Int] {
        let allRides = try await firestoreService.fetchActiveRides(eventId: eventId)
        let sortedRides = allRides.sorted { $0.priority > $1.priority }

        var positions: [String: Int] = [:]
        for (index, ride) in sortedRides.enumerated() {
            positions[ride.id] = index + 1
        }

        return positions
    }

    // MARK: - Estimated Wait Time

    /// Get estimated wait time for a ride
    ///
    /// Calculation logic:
    /// 1. If ride is not yet assigned → estimate based on average DD availability
    /// 2. If ride is assigned → calculate based on DD's current queue
    ///
    /// - Parameters:
    ///   - rideId: The ride ID
    ///   - eventId: The event ID
    /// - Returns: Estimated wait time in minutes
    /// - Throws: FirestoreError if operation fails
    func getEstimatedWaitTime(rideId: String, eventId: String) async throws -> Int {
        let ride = try await firestoreService.fetchRide(id: rideId)

        if let ddId = ride.ddId {
            // Ride is assigned - calculate based on DD's queue
            return try await calculateWaitTimeForAssignedDD(ddId: ddId, eventId: eventId, currentRideId: rideId)
        } else {
            // Ride not assigned - estimate based on average availability
            return try await estimateWaitTimeForUnassignedRide(eventId: eventId, rideId: rideId)
        }
    }

    /// Calculate wait time for a ride assigned to a specific DD
    ///
    /// - Parameters:
    ///   - ddId: The DD's user ID
    ///   - eventId: The event ID
    ///   - currentRideId: The ride we're calculating for
    /// - Returns: Estimated wait time in minutes
    private func calculateWaitTimeForAssignedDD(ddId: String, eventId: String, currentRideId: String) async throws -> Int {
        // Get all rides assigned to this DD
        let ddRides = try await firestoreService.fetchDDRides(ddId: ddId, eventId: eventId)

        // Filter to only active rides (queued, assigned, enroute)
        let activeRides = ddRides.filter {
            $0.status == .queued || $0.status == .assigned || $0.status == .enroute
        }

        // Sort by priority to determine order
        let sortedRides = activeRides.sorted { $0.priority > $1.priority }

        // Find position of current ride in DD's queue
        guard let rideIndex = sortedRides.firstIndex(where: { $0.id == currentRideId }) else {
            return 0
        }

        // Calculate wait time: number of rides ahead × average ride time
        let ridesAhead = rideIndex
        let estimatedMinutes = Int(Double(ridesAhead) * averageRideTimeMinutes)

        return estimatedMinutes
    }

    /// Estimate wait time for an unassigned ride
    ///
    /// - Parameters:
    ///   - eventId: The event ID
    ///   - rideId: The ride ID
    /// - Returns: Estimated wait time in minutes
    private func estimateWaitTimeForUnassignedRide(eventId: String, rideId: String) async throws -> Int {
        // Get overall queue position
        let position = try await getOverallQueuePosition(rideId: rideId, eventId: eventId)

        // Get number of active DDs
        let activeDDs = try await firestoreService.fetchActiveDDAssignments(eventId: eventId)
        let ddCount = max(activeDDs.count, 1) // Avoid division by zero

        // Estimate: (position / number of DDs) × average ride time
        // This assumes rides are distributed evenly across DDs
        let estimatedRidesAhead = Double(position - 1) / Double(ddCount)
        let estimatedMinutes = Int(estimatedRidesAhead * averageRideTimeMinutes)

        return estimatedMinutes
    }

    // MARK: - Real-time Queue Updates

    /// Observe queue updates for an event in real-time
    ///
    /// This publisher emits the current queue (sorted by priority) whenever it changes
    ///
    /// Example usage:
    /// ```swift
    /// RideQueueService.shared.observeQueueUpdates(eventId: "event123")
    ///     .sink(receiveCompletion: { completion in
    ///         // Handle completion
    ///     }, receiveValue: { rides in
    ///         // Handle updated queue
    ///     })
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Parameter eventId: The event ID to observe
    /// - Returns: Publisher that emits sorted ride arrays
    func observeQueueUpdates(eventId: String) -> AnyPublisher<[Ride], Error> {
        firestoreService.observeActiveRides(eventId: eventId)
            .map { rides in
                // Sort by priority descending (higher priority first)
                rides.sorted { $0.priority > $1.priority }
            }
            .eraseToAnyPublisher()
    }

    /// Observe queue position for a specific ride
    ///
    /// - Parameters:
    ///   - rideId: The ride ID to observe
    ///   - eventId: The event ID
    /// - Returns: Publisher that emits queue position updates
    func observeRidePosition(rideId: String, eventId: String) -> AnyPublisher<Int?, Error> {
        observeQueueUpdates(eventId: eventId)
            .map { rides in
                // Find position in sorted array
                if let index = rides.firstIndex(where: { $0.id == rideId }) {
                    return index + 1 // 1-indexed
                }
                return nil
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Batch Priority Updates

    /// Update priorities for all active rides in an event
    ///
    /// This should be called periodically (e.g., every minute) to update
    /// priorities based on increasing wait times
    ///
    /// - Parameter eventId: The event ID
    /// - Throws: FirestoreError if operation fails
    func updateAllPriorities(eventId: String) async throws {
        let rides = try await firestoreService.fetchActiveRides(eventId: eventId)

        for ride in rides {
            // Fetch rider to get class year
            let rider = try await firestoreService.fetchUser(id: ride.riderId)

            var updatedRide = ride
            updateRidePriority(&updatedRide, classYear: rider.classYear)

            // Only update if priority changed
            if updatedRide.priority != ride.priority {
                try await firestoreService.updateRide(updatedRide)
            }
        }
    }

    // MARK: - Queue Statistics

    /// Get queue statistics for an event
    ///
    /// - Parameter eventId: The event ID
    /// - Returns: Queue statistics
    func getQueueStats(eventId: String) async throws -> QueueStats {
        let rides = try await firestoreService.fetchActiveRides(eventId: eventId)
        let activeDDs = try await firestoreService.fetchActiveDDAssignments(eventId: eventId)

        let queuedCount = rides.filter { $0.status == .queued }.count
        let assignedCount = rides.filter { $0.status == .assigned }.count
        let enrouteCount = rides.filter { $0.status == .enroute }.count
        let emergencyCount = rides.filter { $0.isEmergency }.count

        let avgWaitTime: Double
        if !rides.isEmpty {
            let totalWaitMinutes = rides.reduce(0.0) { sum, ride in
                sum + Date().timeIntervalSince(ride.requestedAt) / 60.0
            }
            avgWaitTime = totalWaitMinutes / Double(rides.count)
        } else {
            avgWaitTime = 0
        }

        return QueueStats(
            totalActive: rides.count,
            queued: queuedCount,
            assigned: assignedCount,
            enroute: enrouteCount,
            emergency: emergencyCount,
            activeDDs: activeDDs.count,
            averageWaitMinutes: Int(avgWaitTime)
        )
    }
}

// MARK: - Supporting Types

/// Queue statistics for an event
struct QueueStats {
    let totalActive: Int
    let queued: Int
    let assigned: Int
    let enroute: Int
    let emergency: Int
    let activeDDs: Int
    let averageWaitMinutes: Int
}

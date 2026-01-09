//
//  RideRequestService.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import CoreLocation
import FirebaseFirestore

/// Custom error types for ride request operations
enum RideRequestError: LocalizedError {
    case userNotFound
    case locationCaptureFailed(Error)
    case geocodingFailed(Error)
    case saveFailed(Error)
    case invalidEventId
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User profile could not be found."
        case .locationCaptureFailed(let error):
            return "Failed to capture location: \(error.localizedDescription)"
        case .geocodingFailed(let error):
            return "Failed to determine address: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save ride request: \(error.localizedDescription)"
        case .invalidEventId:
            return "Invalid event selected."
        case .unauthorized:
            return "You must be signed in to request a ride."
        }
    }
}

/// High-level ride request service that orchestrates the full ride request flow
///
/// This service coordinates between LocationService, RideQueueService, and FirestoreService
/// to handle the complete ride request process:
///
/// 1. Fetch user details (classYear, chapterId)
/// 2. Capture rider's location once
/// 3. Geocode location to human-readable address
/// 4. Calculate initial priority (waitMinutes = 0)
/// 5. Create and save Ride object to Firestore
/// 6. Calculate queue position
/// 7. Return complete Ride object
///
/// Example Usage:
/// ```swift
/// // Request a ride
/// let ride = try await RideRequestService.shared.requestRide(
///     userId: currentUser.id,
///     eventId: currentEvent.id,
///     isEmergency: false,
///     notes: "Outside the main entrance"
/// )
///
/// print("Ride requested! Queue position: \(ride.queuePosition ?? 0)")
/// ```
@MainActor
class RideRequestService: ObservableObject {
    static let shared = RideRequestService()

    private let locationService = LocationService.shared
    private let queueService = RideQueueService.shared
    private let firestoreService = FirestoreService.shared
    private let etaService = ETAService.shared

    @Published var isRequesting: Bool = false
    @Published var lastError: Error?

    private init() {}

    // MARK: - Request Ride

    /// Request a ride with automatic location capture and geocoding
    ///
    /// Full flow:
    /// 1. Fetch user from Firestore to get classYear and chapterId
    /// 2. Capture location once using LocationService
    /// 3. Geocode location to address using LocationService
    /// 4. Calculate initial priority using RideQueueService (waitMinutes = 0)
    /// 5. Create Ride object with all required fields
    /// 6. Save ride to Firestore using FirestoreService
    /// 7. Get queue position using RideQueueService
    /// 8. Update ride with queuePosition
    /// 9. Return the complete Ride object
    ///
    /// - Parameters:
    ///   - userId: The user requesting the ride
    ///   - eventId: The event ID for this ride
    ///   - isEmergency: Whether this is an emergency ride (default: false)
    ///   - notes: Optional notes for the DD (e.g., "Outside main entrance")
    /// - Returns: The created Ride object with queue position
    /// - Throws: RideRequestError if any step fails
    func requestRide(
        userId: String,
        eventId: String,
        isEmergency: Bool = false,
        notes: String? = nil
    ) async throws -> Ride {
        isRequesting = true
        lastError = nil

        defer {
            isRequesting = false
        }

        do {
            // Step 1: Fetch user details
            let user: User
            do {
                user = try await firestoreService.fetchUser(id: userId)
            } catch {
                throw RideRequestError.userNotFound
            }

            // Step 2: Capture location once (FIRST location capture of the ride)
            let coordinate: CLLocationCoordinate2D
            do {
                coordinate = try await locationService.captureLocationOnce()
            } catch {
                throw RideRequestError.locationCaptureFailed(error)
            }

            // Step 3: Geocode location to address
            let address: String
            do {
                address = try await locationService.geocodeAddress(coordinate: coordinate)
            } catch {
                throw RideRequestError.geocodingFailed(error)
            }

            // Step 3.5: Fetch event to determine chapter relationship
            let event: Event
            do {
                event = try await firestoreService.fetchEvent(id: eventId)
            } catch {
                throw RideRequestError.invalidEventId
            }

            // Step 4: Determine if same chapter or cross-chapter
            let isSameChapter = (user.chapterId == event.chapterId)

            // Step 5: Calculate initial priority (waitMinutes = 0 for new request)
            // Uses cross-chapter logic if rider is from different chapter than event
            let priority = queueService.calculatePriority(
                classYear: user.classYear,
                waitMinutes: 0.0,
                isEmergency: isEmergency,
                isSameChapter: isSameChapter
            )

            // Step 5: Create Ride object
            let rideId = UUID().uuidString
            let now = Date()

            var ride = Ride(
                id: rideId,
                riderId: user.id,
                ddId: nil,
                chapterId: user.chapterId,
                eventId: eventId,
                pickupLocation: coordinate.geoPoint,
                pickupAddress: address,
                dropoffAddress: nil,
                status: .queued,
                priority: priority,
                isEmergency: isEmergency,
                estimatedWaitTime: nil,
                queuePosition: nil,
                requestedAt: now,
                assignedAt: nil,
                enrouteAt: nil,
                completedAt: nil,
                cancelledAt: nil,
                cancellationReason: nil,
                notes: notes
            )

            // Step 6: Save ride to Firestore
            do {
                try await firestoreService.createRide(ride)
            } catch {
                throw RideRequestError.saveFailed(error)
            }

            // Step 7: Get queue position
            let queuePosition: Int
            do {
                queuePosition = try await queueService.getOverallQueuePosition(
                    rideId: ride.id,
                    eventId: eventId
                )
            } catch {
                // If queue position fails, don't fail the whole request
                queuePosition = 1
            }

            // Step 8: Update ride with queue position
            ride.queuePosition = queuePosition

            // Update in Firestore
            do {
                try await firestoreService.updateRide(ride)
            } catch {
                // Log but don't fail if queue position update fails
                print("Failed to update queue position: \(error.localizedDescription)")
            }

            // Step 9: Return complete ride
            return ride

        } catch let error as RideRequestError {
            lastError = error
            throw error
        } catch {
            let wrappedError = RideRequestError.saveFailed(error)
            lastError = wrappedError
            throw wrappedError
        }
    }

    // MARK: - DD En Route Location Capture

    /// Capture DD's location when marking ride as "en route"
    ///
    /// This is the SECOND (and final) location capture per ride.
    /// Used to calculate ETA from DD's current location to rider's pickup location.
    ///
    /// - Parameter ride: The ride being marked as en route
    /// - Returns: Tuple of (DD's coordinate, DD's address)
    /// - Throws: RideRequestError if location capture or geocoding fails
    func captureEnrouteLocation(for ride: Ride) async throws -> (coordinate: CLLocationCoordinate2D, address: String) {
        do {
            // Capture DD's location once (SECOND location capture)
            let coordinate = try await locationService.captureLocationOnce()

            // Geocode DD's location to address
            let address = try await locationService.geocodeAddress(coordinate: coordinate)

            return (coordinate, address)
        } catch {
            throw RideRequestError.locationCaptureFailed(error)
        }
    }

    // MARK: - Cancel Ride

    /// Cancel a ride request
    ///
    /// - Parameters:
    ///   - rideId: The ride ID to cancel
    ///   - reason: Cancellation reason
    /// - Throws: FirestoreError if update fails
    func cancelRide(rideId: String, reason: String) async throws {
        // Fetch current ride
        var ride = try await firestoreService.fetchRide(id: rideId)

        // Update status
        ride.status = .cancelled
        ride.cancelledAt = Date()
        ride.cancellationReason = reason

        // Save to Firestore
        try await firestoreService.updateRide(ride)
    }

    // MARK: - Helper Methods

    /// Check if user can request a ride
    ///
    /// Checks:
    /// - User has no active rides (queued, assigned, or enroute)
    /// - Location permission is granted
    ///
    /// - Parameter userId: The user ID
    /// - Returns: True if user can request a ride, false otherwise
    func canRequestRide(userId: String) async -> Bool {
        // Check location permission
        guard locationService.isAuthorized else {
            return false
        }

        // Check for active rides
        do {
            let rides = try await firestoreService.fetchRiderRides(riderId: userId)

            // Check if any rides are active
            let hasActiveRide = rides.contains { ride in
                ride.status == .queued || ride.status == .assigned || ride.status == .enroute
            }

            return !hasActiveRide
        } catch {
            // If we can't fetch rides, assume user can request (fail open)
            return true
        }
    }

    /// Get active ride for user (if any)
    ///
    /// - Parameter userId: The user ID
    /// - Returns: Active ride if found, nil otherwise
    func getActiveRide(userId: String) async -> Ride? {
        do {
            let rides = try await firestoreService.fetchRiderRides(riderId: userId)

            // Return first active ride
            return rides.first { ride in
                ride.status == .queued || ride.status == .assigned || ride.status == .enroute
            }
        } catch {
            return nil
        }
    }
}

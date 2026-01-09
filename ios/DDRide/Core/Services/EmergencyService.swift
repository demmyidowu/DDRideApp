//
//  EmergencyService.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import FirebaseFirestore

/// Service for handling emergency ride requests
///
/// This service implements critical business logic for:
/// - Creating emergency rides with maximum priority (9999)
/// - Generating immediate admin alerts
/// - Logging emergency events for audit trail
///
/// Emergency Priority:
/// - All emergency rides receive hardcoded priority of 9999
/// - They bypass normal priority queue calculation (including same-chapter vs cross-chapter logic)
/// - Emergency rides always have the highest priority regardless of chapter relationship
/// - Admin is notified immediately via AdminAlert
///
/// Example Usage:
/// ```swift
/// let service = EmergencyService.shared
///
/// // Handle emergency ride request
/// let ride = try await service.handleEmergencyRequest(
///     riderId: "user123",
///     eventId: "event456",
///     location: GeoPoint(latitude: 39.1836, longitude: -96.5717),
///     address: "123 Main St",
///     reason: "Safety concern - need immediate pickup"
/// )
/// ```
@MainActor
class EmergencyService: ObservableObject {
    static let shared = EmergencyService()

    private let firestoreService = FirestoreService.shared
    private let rideQueueService = RideQueueService.shared

    // Emergency priority constant - always highest priority
    private let emergencyPriority: Double = 9999.0

    private init() {}

    // MARK: - Emergency Request Handling

    /// Handle emergency ride request with highest priority and admin notification
    ///
    /// Process:
    /// 1. Fetch user to get classYear and chapterId
    /// 2. Create ride with priority 9999 (hardcoded, not calculated)
    /// 3. Save ride to Firestore
    /// 4. Create AdminAlert for immediate notification
    /// 5. Save AdminAlert to Firestore
    /// 6. TODO: Send push notification to all admins (future implementation)
    ///
    /// - Parameters:
    ///   - riderId: The rider's user ID
    ///   - eventId: The event ID
    ///   - location: Pickup location as GeoPoint
    ///   - address: Human-readable pickup address
    ///   - reason: Reason for emergency request
    /// - Returns: The created emergency ride
    /// - Throws: EmergencyError if any step fails
    func handleEmergencyRequest(
        riderId: String,
        eventId: String,
        location: GeoPoint,
        address: String,
        reason: String
    ) async throws -> Ride {
        do {
            // Step 1: Fetch user to get classYear and chapterId
            let user = try await firestoreService.fetchUser(id: riderId)

            // Validate user exists and has required data
            guard !user.chapterId.isEmpty else {
                throw EmergencyError.invalidUserData("User has no chapter assigned")
            }

            // Step 2: Create emergency ride with priority 9999
            let ride = Ride(
                id: UUID().uuidString,
                riderId: riderId,
                ddId: nil, // Not yet assigned
                chapterId: user.chapterId,
                eventId: eventId,
                pickupLocation: location,
                pickupAddress: address,
                dropoffAddress: nil,
                status: .queued,
                priority: emergencyPriority, // HARDCODED: Always 9999 for emergencies
                isEmergency: true,
                estimatedWaitTime: nil,
                queuePosition: nil,
                requestedAt: Date(),
                assignedAt: nil,
                enrouteAt: nil,
                completedAt: nil,
                cancelledAt: nil,
                cancellationReason: nil,
                notes: "EMERGENCY: \(reason)"
            )

            // Step 3: Save ride to Firestore
            try await firestoreService.createRide(ride)

            print("✅ Emergency ride created: \(ride.id) for user \(user.name)")

            // Step 4: Create AdminAlert for immediate notification
            let alert = AdminAlert(
                id: UUID().uuidString,
                chapterId: user.chapterId,
                type: .emergencyRide,
                message: "🚨 EMERGENCY RIDE REQUESTED\n\nRider: \(user.name)\nReason: \(reason)\nLocation: \(address)\n\nThis ride has been given highest priority.",
                ddId: nil,
                rideId: ride.id,
                isRead: false,
                createdAt: Date()
            )

            // Step 5: Save AdminAlert to Firestore
            try await firestoreService.createAdminAlert(alert)

            print("✅ Emergency alert created: \(alert.id)")

            // Step 6: TODO - Send push notification to all admins
            // This will be implemented when FCM push notification service is added
            // await sendEmergencyPushNotification(to: user.chapterId, ride: ride, reason: reason)

            return ride

        } catch let error as EmergencyError {
            // Re-throw EmergencyError as-is
            throw error
        } catch let error as FirestoreError {
            // Map FirestoreError to EmergencyError
            switch error {
            case .documentNotFound:
                throw EmergencyError.userNotFound
            default:
                throw EmergencyError.rideSaveFailed(error.localizedDescription ?? "Unknown Firestore error")
            }
        } catch {
            // Catch all other errors
            throw EmergencyError.unknownError(error.localizedDescription)
        }
    }

    /// Get all emergency rides for an event (for admin monitoring)
    ///
    /// - Parameter eventId: The event ID
    /// - Returns: Array of emergency rides
    func fetchEmergencyRides(eventId: String) async throws -> [Ride] {
        let allRides = try await firestoreService.fetchActiveRides(eventId: eventId)
        return allRides.filter { $0.isEmergency }
    }

    /// Get emergency ride count for an event
    ///
    /// - Parameter eventId: The event ID
    /// - Returns: Count of active emergency rides
    func getEmergencyRideCount(eventId: String) async throws -> Int {
        let emergencyRides = try await fetchEmergencyRides(eventId: eventId)
        return emergencyRides.count
    }

    // MARK: - Future: Push Notification Support

    /// Send emergency push notification to all chapter admins
    ///
    /// TODO: Implement when FCM service is added
    /// This should:
    /// 1. Fetch all admins for the chapter
    /// 2. Get their FCM tokens
    /// 3. Send high-priority push notification
    /// 4. Include ride ID in notification data for deep linking
    ///
    /// - Parameters:
    ///   - chapterId: The chapter ID
    ///   - ride: The emergency ride
    ///   - reason: The emergency reason
    private func sendEmergencyPushNotification(to chapterId: String, ride: Ride, reason: String) async {
        // Placeholder for future implementation
        print("📱 TODO: Send emergency push notification to chapter \(chapterId)")
        print("   Ride ID: \(ride.id)")
        print("   Reason: \(reason)")
    }
}

// MARK: - Error Types

/// Custom errors for emergency service operations
enum EmergencyError: LocalizedError {
    case userNotFound
    case invalidUserData(String)
    case rideSaveFailed(String)
    case alertCreationFailed(String)
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "Could not find user account. Please ensure you are logged in."
        case .invalidUserData(let message):
            return "Invalid user data: \(message)"
        case .rideSaveFailed(let message):
            return "Failed to create emergency ride: \(message). Please try again or contact support."
        case .alertCreationFailed(let message):
            return "Emergency ride created but failed to notify admin: \(message)"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .userNotFound:
            return "Try logging out and logging back in. If the problem persists, contact support."
        case .invalidUserData:
            return "Contact your chapter admin to verify your account setup."
        case .rideSaveFailed:
            return "Check your internet connection and try again. If urgent, call emergency services directly."
        case .alertCreationFailed:
            return "Your emergency ride was created successfully. Consider calling your chapter admin directly."
        case .unknownError:
            return "Please try again. If the problem persists, contact support."
        }
    }
}

// MARK: - Test Cases and Examples

/*
 Test Case 1: Emergency ride creation
 =====================================
 Input:
   - riderId: "user123"
   - eventId: "event456"
   - location: GeoPoint(latitude: 39.1836, longitude: -96.5717)
   - address: "123 Main St, Manhattan, KS"
   - reason: "Safety concern - need immediate pickup"

 Expected Output:
   - Ride created with:
     * id: UUID().uuidString
     * priority: 9999 (hardcoded)
     * isEmergency: true
     * status: .queued
     * notes: "EMERGENCY: Safety concern - need immediate pickup"
   - AdminAlert created with:
     * type: .emergencyRide
     * message contains rider name, reason, and location
     * rideId: matches created ride

 Test Case 2: Emergency priority in queue
 =========================================
 Scenario:
   - Queue has 5 normal rides with priorities: 45.5, 42.0, 35.5, 28.0, 20.5
   - Emergency ride is created with priority 9999

 Expected Result:
   - Emergency ride is first in queue (position 1)
   - All other rides shift down
   - Emergency ride gets assigned to next available DD

 Test Case 3: Multiple emergencies
 ==================================
 Scenario:
   - Two emergency rides created 5 minutes apart
   - Both have priority 9999

 Expected Result:
   - Both have same priority (9999)
   - Queue position determined by requestedAt timestamp (FIFO)
   - First emergency ride gets position 1
   - Second emergency ride gets position 2

 Test Case 4: Error handling - User not found
 =============================================
 Input:
   - riderId: "nonexistent_user"
   - Other fields valid

 Expected Result:
   - Throws EmergencyError.userNotFound
   - No ride created
   - No alert created
   - User-friendly error message displayed

 Test Case 5: Error handling - Network failure
 ==============================================
 Input:
   - Valid inputs but network is down

 Expected Result:
   - Throws EmergencyError.rideSaveFailed
   - User sees retry suggestion
   - No partial data left in Firestore
 */

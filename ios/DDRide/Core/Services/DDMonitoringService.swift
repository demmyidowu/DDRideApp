//
//  DDMonitoringService.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import Combine

/// Service for monitoring DD activity and detecting problematic behavior
///
/// This service implements critical business logic for:
/// - Detecting excessive inactive toggles (>5 in 30 minutes)
/// - Detecting prolonged inactivity (>15 minutes during shift)
/// - Auto-resetting toggle counters after 30 minutes
/// - Generating admin alerts for DD issues
///
/// Monitoring Rules:
/// - Inactive Toggle Abuse: Alert if DD toggles inactive >5 times in 30 minutes
/// - Prolonged Inactivity: Alert if DD is inactive >15 minutes during active event
/// - Auto-reset: Reset toggle counter every 30 minutes
///
/// Example Usage:
/// ```swift
/// let service = DDMonitoringService.shared
///
/// // Monitor DD after toggle
/// let alerts = try await service.monitorDD(ddAssignment)
/// if !alerts.isEmpty {
///     // Handle alerts (already saved to Firestore)
///     print("Generated \(alerts.count) alerts for DD monitoring")
/// }
///
/// // Check specific conditions
/// if let alert = try await service.checkInactivityAbuse(for: ddAssignment) {
///     // Handle abuse alert
/// }
/// ```
@MainActor
class DDMonitoringService: ObservableObject {
    static let shared = DDMonitoringService()

    private let firestoreService = FirestoreService.shared

    // Monitoring thresholds
    private let inactiveToggleThreshold = 5 // Alert if >5 toggles
    private let toggleResetIntervalMinutes: TimeInterval = 30 // Reset counter every 30 min
    private let prolongedInactivityMinutes: TimeInterval = 15 // Alert if inactive >15 min

    // Track when toggle counters were last reset for each DD
    private var lastResetTimes: [String: Date] = [:]

    private init() {}

    // MARK: - Comprehensive DD Monitoring

    /// Monitor DD activity and create alerts if needed
    ///
    /// This is the main entry point for DD monitoring. Call this after:
    /// - DD toggles inactive
    /// - Periodic checks (e.g., every 5 minutes)
    ///
    /// Process:
    /// 1. Check if 30 min passed since last reset, auto-reset counter if needed
    /// 2. Check for excessive inactive toggles
    /// 3. Check for prolonged inactivity during shift
    /// 4. Return all generated alerts (alerts are already saved to Firestore)
    ///
    /// - Parameter ddAssignment: The DD assignment to monitor
    /// - Returns: Array of generated alerts (may be empty)
    /// - Throws: FirestoreError if operation fails
    func monitorDD(_ ddAssignment: DDAssignment) async throws -> [AdminAlert] {
        var alerts: [AdminAlert] = []

        // Step 1: Auto-reset toggle counter if 30 minutes passed
        try await autoResetToggleCounterIfNeeded(for: ddAssignment)

        // Step 2: Check for inactive toggle abuse
        if let toggleAlert = try await checkInactivityAbuse(for: ddAssignment) {
            alerts.append(toggleAlert)
        }

        // Step 3: Check for prolonged inactivity
        if let inactivityAlert = try await checkProlongedInactivity(for: ddAssignment) {
            alerts.append(inactivityAlert)
        }

        return alerts
    }

    // MARK: - Inactive Toggle Abuse Detection

    /// Check if DD has toggled inactive too many times
    ///
    /// Alert Criteria:
    /// - DD has toggled inactive >5 times
    /// - Last inactive toggle was within 30 minutes
    ///
    /// If criteria met:
    /// - Creates AdminAlert with type .ddInactiveToggle
    /// - Saves alert to Firestore
    /// - Returns the alert
    ///
    /// - Parameter ddAssignment: The DD assignment to check
    /// - Returns: AdminAlert if threshold exceeded, nil otherwise
    /// - Throws: FirestoreError if operation fails
    func checkInactivityAbuse(for ddAssignment: DDAssignment) async throws -> AdminAlert? {
        // Check if toggle count exceeds threshold
        guard ddAssignment.inactiveToggles > inactiveToggleThreshold else {
            return nil
        }

        // Check if last toggle was within 30 minutes
        if let lastInactive = ddAssignment.lastInactiveTimestamp {
            let minutesSinceLastToggle = Date().timeIntervalSince(lastInactive) / 60.0

            // Only alert if within 30 minutes (if older, counter should have been reset)
            guard minutesSinceLastToggle <= toggleResetIntervalMinutes else {
                return nil
            }
        } else {
            // No lastInactiveTimestamp but high toggle count - this shouldn't happen
            // but we'll alert anyway to be safe
        }

        // Fetch DD user info for alert message
        let ddUser = try await firestoreService.fetchUser(id: ddAssignment.userId)

        // Fetch event to get chapterId
        let event = try await firestoreService.fetchEvent(id: ddAssignment.eventId)

        // Create admin alert
        let alert = AdminAlert(
            id: UUID().uuidString,
            chapterId: event.chapterId,
            type: .ddInactiveToggle,
            message: "⚠️ DD Inactive Toggle Alert\n\n\(ddUser.name) has toggled inactive \(ddAssignment.inactiveToggles) times in the last 30 minutes. This may indicate:\n\n• Availability issues\n• Technical problems\n• Need for communication\n\nPlease check in with this DD to ensure they're able to continue their shift.",
            ddId: ddAssignment.userId,
            rideId: nil,
            isRead: false,
            createdAt: Date()
        )

        // Save alert to Firestore
        try await firestoreService.createAdminAlert(alert)

        print("⚠️ Inactive toggle alert created for DD \(ddUser.name) (\(ddAssignment.inactiveToggles) toggles)")

        return alert
    }

    // MARK: - Prolonged Inactivity Detection

    /// Check if DD has been inactive for too long during their shift
    ///
    /// Alert Criteria:
    /// - DD is currently inactive (isActive == false)
    /// - Event is still active (status == .active)
    /// - DD has been inactive >15 minutes
    ///
    /// If criteria met:
    /// - Creates AdminAlert with type .ddProlongedInactive
    /// - Saves alert to Firestore
    /// - Returns the alert
    /// - TODO: Send push notification to DD (future implementation)
    ///
    /// - Parameter ddAssignment: The DD assignment to check
    /// - Returns: AdminAlert if threshold exceeded, nil otherwise
    /// - Throws: FirestoreError if operation fails
    func checkProlongedInactivity(for ddAssignment: DDAssignment) async throws -> AdminAlert? {
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

        // Verify event is still active (don't alert if event is over)
        let event = try await firestoreService.fetchEvent(id: ddAssignment.eventId)
        guard event.status == .active else {
            // Event is no longer active, don't alert
            return nil
        }

        // Fetch DD user info for alert message
        let ddUser = try await firestoreService.fetchUser(id: ddAssignment.userId)

        // Create admin alert
        let alert = AdminAlert(
            id: UUID().uuidString,
            chapterId: event.chapterId,
            type: .ddProlongedInactive,
            message: "⏰ DD Prolonged Inactive Alert\n\n\(ddUser.name) has been inactive for \(Int(minutesInactive)) minutes during their shift.\n\nPossible actions:\n\n• Contact DD to check their status\n• Ask if they need to end their shift\n• Verify they're not experiencing issues\n\nDD may have forgotten to toggle back to active or may be unavailable.",
            ddId: ddAssignment.userId,
            rideId: nil,
            isRead: false,
            createdAt: Date()
        )

        // Save alert to Firestore
        try await firestoreService.createAdminAlert(alert)

        print("⏰ Prolonged inactivity alert created for DD \(ddUser.name) (\(Int(minutesInactive)) minutes)")

        // TODO: Send push notification to DD
        // await sendInactivityReminder(to: ddAssignment.userId, minutesInactive: Int(minutesInactive))

        return alert
    }

    // MARK: - Auto-Reset Toggle Counter

    /// Auto-reset toggle counter if 30 minutes have passed
    ///
    /// This should be called before checking for abuse to ensure
    /// we're not alerting on old toggle counts.
    ///
    /// Logic:
    /// 1. Check if 30 minutes passed since last reset (or last toggle)
    /// 2. If yes, reset inactiveToggles to 0
    /// 3. Update lastResetTimes tracking dictionary
    /// 4. Save updated assignment to Firestore
    ///
    /// - Parameter ddAssignment: The DD assignment to check
    /// - Throws: FirestoreError if update fails
    func autoResetToggleCounterIfNeeded(for ddAssignment: DDAssignment) async throws {
        // Determine reference time (last toggle or last reset)
        let referenceTime: Date
        if let lastReset = lastResetTimes[ddAssignment.userId] {
            referenceTime = lastReset
        } else if let lastInactive = ddAssignment.lastInactiveTimestamp {
            referenceTime = lastInactive
        } else {
            // No reference time, nothing to reset
            return
        }

        // Check if 30 minutes have passed
        let minutesSinceReference = Date().timeIntervalSince(referenceTime) / 60.0

        guard minutesSinceReference >= toggleResetIntervalMinutes else {
            // Not time to reset yet
            return
        }

        // Reset toggle counter
        var updatedAssignment = ddAssignment
        updatedAssignment.inactiveToggles = 0

        // Update in Firestore
        try await firestoreService.updateDDAssignment(updatedAssignment)

        // Update tracking dictionary
        lastResetTimes[ddAssignment.userId] = Date()

        print("🔄 Auto-reset toggle counter for DD \(ddAssignment.userId)")
    }

    /// Manually reset toggle counter for a DD
    ///
    /// Use this when admin wants to reset the counter manually
    /// (e.g., after talking to DD about the issue)
    ///
    /// - Parameter ddAssignment: The DD assignment to reset
    /// - Throws: FirestoreError if update fails
    func resetToggleCounter(for ddAssignment: DDAssignment) async throws {
        var updatedAssignment = ddAssignment
        updatedAssignment.inactiveToggles = 0

        try await firestoreService.updateDDAssignment(updatedAssignment)

        lastResetTimes[ddAssignment.userId] = Date()

        print("🔄 Manually reset toggle counter for DD \(ddAssignment.userId)")
    }

    /// Reset all toggle counters for an event
    ///
    /// Call this periodically (e.g., every 30 minutes) or when event ends
    ///
    /// - Parameter eventId: The event ID
    /// - Throws: FirestoreError if operation fails
    func resetAllToggleCounters(eventId: String) async throws {
        let assignments = try await firestoreService.fetchAllDDAssignments(eventId: eventId)

        for assignment in assignments {
            var updated = assignment
            updated.inactiveToggles = 0
            try await firestoreService.updateDDAssignment(updated)

            lastResetTimes[assignment.userId] = Date()
        }

        print("🔄 Reset all toggle counters for event \(eventId) (\(assignments.count) DDs)")
    }

    // MARK: - Monitoring Statistics

    /// Get monitoring statistics for a DD
    ///
    /// - Parameter ddAssignment: The DD assignment
    /// - Returns: Monitoring statistics
    func getMonitoringStats(for ddAssignment: DDAssignment) -> DDMonitoringStats {
        let minutesInactive: Int
        if let lastInactive = ddAssignment.lastInactiveTimestamp, !ddAssignment.isActive {
            minutesInactive = Int(Date().timeIntervalSince(lastInactive) / 60.0)
        } else {
            minutesInactive = 0
        }

        let isAboveToogleThreshold = ddAssignment.inactiveToggles > inactiveToggleThreshold
        let isAboveInactivityThreshold = TimeInterval(minutesInactive) > prolongedInactivityMinutes

        return DDMonitoringStats(
            inactiveToggles: ddAssignment.inactiveToggles,
            minutesInactive: minutesInactive,
            isAboveToggleThreshold: isAboveToogleThreshold,
            isAboveInactivityThreshold: isAboveInactivityThreshold,
            lastResetTime: lastResetTimes[ddAssignment.userId]
        )
    }

    // MARK: - Future: Push Notification Support

    /// Send push notification reminder to DD about prolonged inactivity
    ///
    /// TODO: Implement when FCM service is added
    ///
    /// - Parameters:
    ///   - userId: DD's user ID
    ///   - minutesInactive: How many minutes they've been inactive
    private func sendInactivityReminder(to userId: String, minutesInactive: Int) async {
        // Placeholder for future implementation
        print("📱 TODO: Send inactivity reminder push notification to DD \(userId)")
        print("   Message: You've been inactive for \(minutesInactive) minutes. Please toggle active or end your shift.")
    }
}

// MARK: - Supporting Types

/// Monitoring statistics for a DD
struct DDMonitoringStats {
    /// Number of inactive toggles in current 30-minute window
    let inactiveToggles: Int

    /// Minutes currently inactive (0 if active)
    let minutesInactive: Int

    /// Whether DD is above the toggle threshold (>5)
    let isAboveToggleThreshold: Bool

    /// Whether DD is above the inactivity threshold (>15 min)
    let isAboveInactivityThreshold: Bool

    /// When the toggle counter was last reset
    let lastResetTime: Date?
}

// MARK: - Test Cases and Examples

/*
 Test Case 1: Normal DD activity (no alerts)
 ============================================
 Scenario:
   - DD toggles inactive 3 times in 20 minutes
   - Each inactive period is 5 minutes

 Expected Result:
   - No alerts generated
   - inactiveToggles = 3 (below threshold)
   - No prolonged inactivity (each period < 15 min)

 Test Case 2: Excessive inactive toggles
 ========================================
 Scenario:
   - DD toggles inactive 6 times in 25 minutes
   - Last toggle was 5 minutes ago

 Expected Result:
   - Alert generated with type .ddInactiveToggle
   - Alert message includes DD name and toggle count
   - Alert saved to Firestore
   - Admin notified

 Test Case 3: Prolonged inactivity
 ==================================
 Scenario:
   - DD toggles inactive
   - 20 minutes pass without toggling back active
   - Event is still active

 Expected Result:
   - Alert generated with type .ddProlongedInactive
   - Alert message includes DD name and inactive duration
   - Alert saved to Firestore
   - TODO: Push notification sent to DD

 Test Case 4: Auto-reset toggle counter
 =======================================
 Scenario:
   - DD has 4 inactive toggles at time T
   - 35 minutes pass
   - DD toggles inactive again

 Expected Result:
   - At T+35min, toggle counter auto-resets to 0
   - New toggle increases counter to 1
   - No alert generated (below threshold)

 Test Case 5: Event ended (no prolonged inactivity alert)
 =========================================================
 Scenario:
   - DD is inactive for 20 minutes
   - Event status changes to .completed

 Expected Result:
   - No prolonged inactivity alert generated
   - Event is no longer active, so inactivity is expected

 Test Case 6: Combined monitoring
 =================================
 Scenario:
   - DD has 6 toggles in 20 minutes
   - Currently inactive for 18 minutes
   - Event is active

 Expected Result:
   - Two alerts generated:
     1. ddInactiveToggle (6 toggles > threshold)
     2. ddProlongedInactive (18 min > threshold)
   - Both saved to Firestore
   - Admin sees both in alert list

 Test Case 7: Manual reset
 ==========================
 Scenario:
   - Admin sees alert for DD with 7 toggles
   - Admin talks to DD, resolves issue
   - Admin manually resets toggle counter

 Expected Result:
   - resetToggleCounter() sets inactiveToggles = 0
   - Updated assignment saved to Firestore
   - Future toggles start fresh from 0
 */

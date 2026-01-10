//
//  DDMonitoringTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
import FirebaseFirestore
@testable import DDRide

/// Integration tests for DD monitoring and alert system
///
/// Tests the complete DD monitoring workflow:
/// 1. Excessive inactive toggles detection (>5 in 30 minutes)
/// 2. Prolonged inactivity detection (>15 minutes during shift)
/// 3. Auto-reset toggle counter after 30 minutes
/// 4. Admin alert generation for DD issues
///
/// This tests integration between:
/// - DDMonitoringService
/// - DDAssignment model
/// - AdminAlert system
/// - Firestore persistence
final class DDMonitoringTests: DDRideTestCase {

    var monitoringService: DDMonitoringService!

    var chapter: Chapter!
    var event: Event!
    var admin: User!
    var dd: User!
    var ddAssignment: DDAssignment!

    override func setUp() async throws {
        try await super.setUp()

        monitoringService = DDMonitoringService.shared

        // Create test data
        chapter = TestDataFactory.createTestChapter(id: "test-chapter")
        try await saveChapter(chapter)

        event = TestDataFactory.createTestEvent(chapterId: chapter.id, status: .active)
        try await saveEvent(event)

        admin = TestDataFactory.createTestUser(id: "admin-1", classYear: 4, role: .admin, chapterId: chapter.id)
        try await saveUser(admin)

        dd = TestDataFactory.createTestUser(id: "dd-1", classYear: 3, chapterId: chapter.id)
        try await saveUser(dd)

        ddAssignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id, isActive: true)
        try await saveDDAssignment(ddAssignment)
    }

    // MARK: - Frequent Toggle Tests

    /// Test Case 1: Excessive toggles create admin alert
    func testFrequentTogglesCreatesAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!

        // ACT - Toggle DD inactive 6 times (exceeds threshold of 5)
        for i in 1...6 {
            currentAssignment.inactiveToggles = i
            currentAssignment.isActive = i % 2 == 0

            if i % 2 == 0 {
                currentAssignment.lastActiveTimestamp = Date()
                currentAssignment.lastInactiveTimestamp = nil
            } else {
                currentAssignment.lastActiveTimestamp = nil
                currentAssignment.lastInactiveTimestamp = Date()
            }

            try await saveDDAssignment(currentAssignment)

            // Check for alert after each toggle
            _ = try await monitoringService.checkInactivityAbuse(for: currentAssignment)
        }

        // ASSERT - Alert should be created after 6th toggle
        let alerts = try await fetchAdminAlerts(chapterId: chapter.id)

        let toggleAlert = alerts.first { $0.type == .ddInactiveToggle }
        XCTAssertNotNil(toggleAlert, "Alert should be created for excessive toggling")
        XCTAssertEqual(toggleAlert?.ddId, dd.id)
        XCTAssertFalse(toggleAlert?.isRead ?? true)
        XCTAssertTrue(toggleAlert?.message.contains("6") ?? false, "Message should mention toggle count")
        XCTAssertTrue(toggleAlert?.message.contains(dd.name) ?? false, "Message should mention DD name")
    }

    /// Test Case 2: Under-threshold toggles do not create alert
    func testInactiveTogglesDoNotAlertBeforeThreshold() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!

        // ACT - Toggle only 5 times (at threshold, not exceeding)
        for i in 1...5 {
            currentAssignment.inactiveToggles = i
            currentAssignment.lastInactiveTimestamp = Date()
            try await saveDDAssignment(currentAssignment)

            _ = try await monitoringService.checkInactivityAbuse(for: currentAssignment)
        }

        // ASSERT - No alert should be created
        let alerts = try await fetchAdminAlerts(chapterId: chapter.id)
        let toggleAlerts = alerts.filter { $0.type == .ddInactiveToggle }

        XCTAssertEqual(toggleAlerts.count, 0, "No alert should be created for 5 toggles (threshold)")
    }

    /// Test Case 3: Toggle counter auto-resets after 30 minutes
    func testToggleCounterAutoResets() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.inactiveToggles = 8
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-35 * 60) // 35 minutes ago

        try await saveDDAssignment(currentAssignment)

        // ACT - Auto-reset after 30 minutes
        try await monitoringService.autoResetToggleCounterIfNeeded(for: currentAssignment)

        // ASSERT - Counter should be reset
        let updatedAssignment = try await fetchDDAssignment(id: ddAssignment.id)
        XCTAssertEqual(updatedAssignment.inactiveToggles, 0, "Toggle counter should be reset after 30 minutes")
    }

    /// Test Case 4: Manual reset toggle counter
    func testManualResetToggleCounter() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.inactiveToggles = 7
        try await saveDDAssignment(currentAssignment)

        // ACT - Admin manually resets
        try await monitoringService.resetToggleCounter(for: currentAssignment)

        // ASSERT
        let updatedAssignment = try await fetchDDAssignment(id: ddAssignment.id)
        XCTAssertEqual(updatedAssignment.inactiveToggles, 0, "Toggle counter should be manually reset")
    }

    // MARK: - Prolonged Inactivity Tests

    /// Test Case 5: Prolonged inactivity creates alert
    func testProlongedInactivityCreatesAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!

        // Set DD as inactive for 20 minutes (exceeds 15 minute threshold)
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-20 * 60)

        try await saveDDAssignment(currentAssignment)

        // ACT
        let alert = try await monitoringService.checkProlongedInactivity(for: currentAssignment)

        // ASSERT
        XCTAssertNotNil(alert, "Alert should be created for prolonged inactivity")
        XCTAssertEqual(alert?.type, .ddProlongedInactive)
        XCTAssertEqual(alert?.ddId, dd.id)
        XCTAssertTrue(alert?.message.contains("20 minutes") ?? false, "Should mention duration")
        XCTAssertTrue(alert?.message.contains(dd.name) ?? false, "Should mention DD name")

        // Verify alert was saved
        let savedAlerts = try await fetchAdminAlerts(chapterId: chapter.id, type: .ddProlongedInactive)
        XCTAssertEqual(savedAlerts.count, 1)
    }

    /// Test Case 6: Inactivity under 15 minutes does not alert
    func testInactivityUnder15MinutesNoAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!

        // Set DD as inactive for only 10 minutes
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-10 * 60)

        try await saveDDAssignment(currentAssignment)

        // ACT
        let alert = try await monitoringService.checkProlongedInactivity(for: currentAssignment)

        // ASSERT
        XCTAssertNil(alert, "No alert should be created for inactivity under 15 minutes")
    }

    /// Test Case 7: Active DD does not trigger inactivity alert
    func testActiveDDNoInactivityAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!

        // DD is active
        currentAssignment.isActive = true
        currentAssignment.lastActiveTimestamp = Date()
        currentAssignment.lastInactiveTimestamp = nil

        try await saveDDAssignment(currentAssignment)

        // ACT
        let alert = try await monitoringService.checkProlongedInactivity(for: currentAssignment)

        // ASSERT
        XCTAssertNil(alert, "No inactivity alert for active DD")
    }

    /// Test Case 8: Combined monitoring detects both issues
    func testMonitorDDCombinedChecks() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!

        // Set up DD with both issues:
        // 1. 7 toggles in last 30 minutes
        // 2. Currently inactive for 20 minutes
        currentAssignment.inactiveToggles = 7
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-20 * 60)

        try await saveDDAssignment(currentAssignment)

        // ACT - Run combined monitoring
        let alerts = try await monitoringService.monitorDD(currentAssignment)

        // ASSERT - Both alerts should be created
        XCTAssertEqual(alerts.count, 2, "Should create both toggle and inactivity alerts")

        let toggleAlert = alerts.first { $0.type == .ddInactiveToggle }
        let inactivityAlert = alerts.first { $0.type == .ddProlongedInactive }

        XCTAssertNotNil(toggleAlert, "Should have toggle alert")
        XCTAssertNotNil(inactivityAlert, "Should have inactivity alert")

        // Verify both were saved to Firestore
        let savedAlerts = try await fetchAdminAlerts(chapterId: chapter.id)
        XCTAssertGreaterThanOrEqual(savedAlerts.count, 2)
    }

    // MARK: - Edge Cases

    /// Test Case 9: No alert when event is not active
    func testNoAlertWhenEventInactive() async throws {
        // ARRANGE - Make event inactive
        var inactiveEvent = event!
        inactiveEvent.status = .completed
        try await saveEvent(inactiveEvent)

        var currentAssignment = ddAssignment!
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-20 * 60)

        try await saveDDAssignment(currentAssignment)

        // ACT
        let alert = try await monitoringService.checkProlongedInactivity(for: currentAssignment)

        // ASSERT - No alert when event is not active
        XCTAssertNil(alert, "No alert should be created when event is not active")
    }

    /// Test Case 10: Monitoring statistics are accurate
    func testMonitoringStatistics() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.inactiveToggles = 6
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-18 * 60) // 18 minutes ago

        try await saveDDAssignment(currentAssignment)

        // ACT
        let stats = monitoringService.getMonitoringStats(for: currentAssignment)

        // ASSERT
        XCTAssertEqual(stats.inactiveToggles, 6)
        XCTAssertEqual(stats.minutesInactive, 18)
        XCTAssertTrue(stats.isAboveToggleThreshold, "6 toggles > 5 threshold")
        XCTAssertTrue(stats.isAboveInactivityThreshold, "18 minutes > 15 threshold")
    }

    /// Test Case 11: Active DD has zero minutes inactive
    func testActiveDDHasZeroMinutesInactive() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.isActive = true
        currentAssignment.lastActiveTimestamp = Date()
        currentAssignment.lastInactiveTimestamp = nil

        try await saveDDAssignment(currentAssignment)

        // ACT
        let stats = monitoringService.getMonitoringStats(for: currentAssignment)

        // ASSERT
        XCTAssertEqual(stats.minutesInactive, 0, "Active DD should have 0 minutes inactive")
        XCTAssertFalse(stats.isAboveInactivityThreshold)
    }

    /// Test Case 12: Reset all toggle counters for event
    func testResetAllToggleCountersForEvent() async throws {
        // ARRANGE - Create multiple DDs with high toggle counts
        let dd2 = TestDataFactory.createTestUser(id: "dd-2", classYear: 3, chapterId: chapter.id)
        let dd3 = TestDataFactory.createTestUser(id: "dd-3", classYear: 4, chapterId: chapter.id)
        try await saveUser(dd2)
        try await saveUser(dd3)

        var assignment2 = TestDataFactory.createTestDDAssignment(userId: dd2.id, eventId: event.id)
        assignment2.inactiveToggles = 7
        var assignment3 = TestDataFactory.createTestDDAssignment(userId: dd3.id, eventId: event.id)
        assignment3.inactiveToggles = 5

        try await saveDDAssignment(assignment2)
        try await saveDDAssignment(assignment3)

        // Also update original assignment
        var currentAssignment = ddAssignment!
        currentAssignment.inactiveToggles = 6
        try await saveDDAssignment(currentAssignment)

        // ACT - Reset all
        try await monitoringService.resetAllToggleCounters(eventId: event.id)

        // ASSERT - All should be reset
        let updated1 = try await fetchDDAssignment(id: ddAssignment.id)
        let updated2 = try await fetchDDAssignment(id: assignment2.id)
        let updated3 = try await fetchDDAssignment(id: assignment3.id)

        XCTAssertEqual(updated1.inactiveToggles, 0)
        XCTAssertEqual(updated2.inactiveToggles, 0)
        XCTAssertEqual(updated3.inactiveToggles, 0)
    }

    /// Test Case 13: Old toggle timestamp doesn't trigger alert
    func testOldToggleTimestampNoAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.inactiveToggles = 8
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-40 * 60) // 40 minutes ago

        try await saveDDAssignment(currentAssignment)

        // ACT - Should not alert because timestamp is too old (>30 min)
        let alert = try await monitoringService.checkInactivityAbuse(for: currentAssignment)

        // ASSERT
        XCTAssertNil(alert, "Should not alert for old toggle timestamps beyond 30 minutes")
    }

    /// Test Case 14: Exactly 15 minutes inactive does not alert
    func testExactly15MinutesInactiveNoAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-15 * 60) // Exactly 15 minutes

        try await saveDDAssignment(currentAssignment)

        // ACT
        let alert = try await monitoringService.checkProlongedInactivity(for: currentAssignment)

        // ASSERT - Should not alert at exactly threshold (only when exceeding)
        XCTAssertNil(alert, "Should not alert at exactly 15 minutes (must exceed threshold)")
    }

    /// Test Case 15: 16 minutes inactive triggers alert
    func testJustOver15MinutesTriggersAlert() async throws {
        // ARRANGE
        var currentAssignment = ddAssignment!
        currentAssignment.isActive = false
        currentAssignment.lastInactiveTimestamp = Date().addingTimeInterval(-16 * 60) // 16 minutes

        try await saveDDAssignment(currentAssignment)

        // ACT
        let alert = try await monitoringService.checkProlongedInactivity(for: currentAssignment)

        // ASSERT
        XCTAssertNotNil(alert, "Should alert when just over 15 minutes")
        XCTAssertTrue(alert?.message.contains("16 minutes") ?? false)
    }
}

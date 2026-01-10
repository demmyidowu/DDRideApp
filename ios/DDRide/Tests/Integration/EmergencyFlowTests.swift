//
//  EmergencyFlowTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
import CoreLocation
import FirebaseFirestore
@testable import DDRide

/// Integration tests for emergency ride request workflow
///
/// Tests the complete emergency flow:
/// 1. Emergency ride creation with priority 9999
/// 2. Admin alert generation
/// 3. Emergency rides get immediate priority over normal rides
/// 4. Multiple emergency rides ordered by time
///
/// This tests integration between:
/// - EmergencyService
/// - RideQueueService
/// - DDAssignmentService
/// - AdminAlert system
final class EmergencyFlowTests: DDRideTestCase {

    var emergencyService: EmergencyService!
    var queueService: RideQueueService!
    var ddAssignmentService: DDAssignmentService!

    var chapter: Chapter!
    var event: Event!
    var admin: User!
    var rider: User!
    var dd: User!
    var ddAssignment: DDAssignment!

    override func setUp() async throws {
        try await super.setUp()

        emergencyService = EmergencyService.shared
        queueService = RideQueueService.shared
        ddAssignmentService = DDAssignmentService.shared

        // Create test data
        chapter = TestDataFactory.createTestChapter(id: "test-chapter")
        try await saveChapter(chapter)

        event = TestDataFactory.createTestEvent(chapterId: chapter.id, status: .active)
        try await saveEvent(event)

        admin = TestDataFactory.createTestUser(id: "admin-1", classYear: 4, role: .admin, chapterId: chapter.id)
        try await saveUser(admin)

        rider = TestDataFactory.createTestUser(id: "rider-1", classYear: 2, chapterId: chapter.id)
        try await saveUser(rider)

        dd = TestDataFactory.createTestUser(id: "dd-1", classYear: 3, chapterId: chapter.id)
        try await saveUser(dd)

        ddAssignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id, isActive: true)
        try await saveDDAssignment(ddAssignment)
    }

    // MARK: - Emergency Request Flow

    /// Test Case 1: Emergency ride is created with priority 9999
    func testEmergencyRequestFlow() async throws {
        // ARRANGE
        let location = GeoPoint(latitude: 39.1836, longitude: -96.5717)
        let address = "123 Emergency St, Manhattan, KS 66502"
        let reason = "Safety Concern"

        // ACT - Request emergency ride
        let ride = try await emergencyService.handleEmergencyRequest(
            riderId: rider.id,
            eventId: event.id,
            location: location,
            address: address,
            reason: reason
        )

        // ASSERT
        XCTAssertNotNil(ride, "Emergency ride should be created")
        XCTAssertEqual(ride.priority, 9999, "Emergency ride must have priority 9999")
        XCTAssertTrue(ride.isEmergency, "Ride should be marked as emergency")
        XCTAssertEqual(ride.status, .queued, "Emergency ride should start as queued")
        XCTAssertEqual(ride.notes, "EMERGENCY: \(reason)", "Ride should include emergency reason in notes")
        XCTAssertEqual(ride.pickupAddress, address)
        XCTAssertEqual(ride.riderId, rider.id)
        XCTAssertEqual(ride.eventId, event.id)
        XCTAssertNil(ride.ddId, "Emergency ride should not be assigned yet")

        // Verify ride was saved to Firestore
        let savedRide = try await fetchRide(id: ride.id)
        XCTAssertEqual(savedRide.priority, 9999)
        XCTAssertTrue(savedRide.isEmergency)
    }

    /// Test Case 2: Admin alert is created when emergency is requested
    func testAdminNotificationOnEmergency() async throws {
        // ARRANGE
        let location = GeoPoint(latitude: 39.1836, longitude: -96.5717)
        let address = "456 Danger Ave, Manhattan, KS 66502"
        let reason = "Medical Emergency"

        // ACT - Request emergency ride
        let ride = try await emergencyService.handleEmergencyRequest(
            riderId: rider.id,
            eventId: event.id,
            location: location,
            address: address,
            reason: reason
        )

        // ASSERT - Admin alert was created
        let alerts = try await fetchAdminAlerts(chapterId: chapter.id)

        XCTAssertGreaterThan(alerts.count, 0, "Admin alert should be created")

        let emergencyAlert = alerts.first { $0.type == .emergencyRide }
        XCTAssertNotNil(emergencyAlert, "Emergency alert should exist")
        XCTAssertEqual(emergencyAlert?.rideId, ride.id, "Alert should reference the ride")
        XCTAssertEqual(emergencyAlert?.chapterId, chapter.id)
        XCTAssertFalse(emergencyAlert?.isRead ?? true, "Alert should be unread")
        XCTAssertTrue(emergencyAlert?.message.contains(reason) ?? false, "Alert should mention the emergency reason")
        XCTAssertTrue(emergencyAlert?.message.contains(rider.name) ?? false, "Alert should mention rider name")
        XCTAssertTrue(emergencyAlert?.message.contains(address) ?? false, "Alert should mention location")
    }

    /// Test Case 3: Emergency ride has higher priority than all normal rides
    func testEmergencyHasImmediatePriority() async throws {
        // ARRANGE - Create several normal rides first
        let normalRides = try await createMultipleRides(count: 5, isEmergency: false)

        // All normal rides should have priority < 100
        for normalRide in normalRides {
            XCTAssertLessThan(normalRide.priority, 100, "Normal rides should have priority < 100")
        }

        // ACT - Request emergency ride
        let emergencyRide = try await emergencyService.handleEmergencyRequest(
            riderId: rider.id,
            eventId: event.id,
            location: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            address: "Emergency Location",
            reason: "Stranded Alone"
        )

        // ASSERT - Emergency ride has highest priority
        let allRides = normalRides + [emergencyRide]
        let sortedByPriority = allRides.sorted { $0.priority > $1.priority }

        XCTAssertEqual(sortedByPriority.first?.id, emergencyRide.id, "Emergency ride should be first in queue")
        XCTAssertEqual(emergencyRide.priority, 9999)

        // Verify queue position
        let queuePosition = try await queueService.getOverallQueuePosition(
            rideId: emergencyRide.id,
            eventId: event.id
        )
        XCTAssertEqual(queuePosition, 1, "Emergency should be position 1 in queue")
    }

    /// Test Case 4: Emergency ride gets assigned to available DD
    func testEmergencyGetsAssignedImmediately() async throws {
        // ARRANGE - Create emergency ride
        let emergencyRide = try await emergencyService.handleEmergencyRequest(
            riderId: rider.id,
            eventId: event.id,
            location: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            address: "Emergency Location",
            reason: "Medical Emergency"
        )

        // ACT - Find best DD
        let allRides = try await fetchRidesForEvent(event.id)
        let bestDD = try await ddAssignmentService.findBestDD(for: event, rides: allRides)

        // ASSERT
        XCTAssertNotNil(bestDD, "Emergency should be assigned to available DD")
        XCTAssertEqual(bestDD?.userId, dd.id)
        XCTAssertTrue(bestDD?.isActive ?? false)

        // Verify DD can be assigned
        XCTAssertNotNil(bestDD)
    }

    /// Test Case 5: Multiple emergencies are ordered by request time (FIFO)
    func testMultipleEmergenciesOrderedByTime() async throws {
        // ARRANGE - Create multiple emergency rides with time gaps
        let emergency1 = try await createEmergencyRide(riderId: "rider-emerg-1", reason: "Emergency 1")

        // Wait 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let emergency2 = try await createEmergencyRide(riderId: "rider-emerg-2", reason: "Emergency 2")

        try await Task.sleep(nanoseconds: 1_000_000_000)

        let emergency3 = try await createEmergencyRide(riderId: "rider-emerg-3", reason: "Emergency 3")

        // ASSERT - All have same priority but ordered by time
        XCTAssertEqual(emergency1.priority, 9999)
        XCTAssertEqual(emergency2.priority, 9999)
        XCTAssertEqual(emergency3.priority, 9999)

        // First requested should be first in line
        XCTAssertLessThan(emergency1.requestedAt, emergency2.requestedAt)
        XCTAssertLessThan(emergency2.requestedAt, emergency3.requestedAt)

        // Verify queue positions
        let pos1 = try await queueService.getOverallQueuePosition(rideId: emergency1.id, eventId: event.id)
        let pos2 = try await queueService.getOverallQueuePosition(rideId: emergency2.id, eventId: event.id)
        let pos3 = try await queueService.getOverallQueuePosition(rideId: emergency3.id, eventId: event.id)

        XCTAssertEqual(pos1, 1, "First emergency should be position 1")
        XCTAssertEqual(pos2, 2, "Second emergency should be position 2")
        XCTAssertEqual(pos3, 3, "Third emergency should be position 3")
    }

    /// Test Case 6: Emergency bypasses even senior riders
    func testEmergencyBypassesSeniorRiders() async throws {
        // ARRANGE - Create a senior's normal ride
        let senior = TestDataFactory.createTestUser(id: "senior-rider", classYear: 4, chapterId: chapter.id)
        try await saveUser(senior)

        let seniorRide = TestDataFactory.createTestRide(
            riderId: senior.id,
            chapterId: chapter.id,
            eventId: event.id,
            classYear: 4,
            waitMinutes: 10.0,
            isEmergency: false
        )
        try await saveRide(seniorRide)

        // Senior priority should be: (4 × 10) + (10 × 0.5) = 45
        XCTAssertEqual(seniorRide.priority, 45.0, accuracy: 0.1)

        // ACT - Freshman requests emergency
        let freshman = TestDataFactory.createTestUser(id: "freshman-emerg", classYear: 1, chapterId: chapter.id)
        try await saveUser(freshman)

        let emergencyRide = try await emergencyService.handleEmergencyRequest(
            riderId: freshman.id,
            eventId: event.id,
            location: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            address: "Emergency Location",
            reason: "Safety Concern"
        )

        // ASSERT - Emergency has higher priority than senior
        XCTAssertGreaterThan(emergencyRide.priority, seniorRide.priority)
        XCTAssertEqual(emergencyRide.priority, 9999)

        // Queue positions
        let emergencyPos = try await queueService.getOverallQueuePosition(rideId: emergencyRide.id, eventId: event.id)
        let seniorPos = try await queueService.getOverallQueuePosition(rideId: seniorRide.id, eventId: event.id)

        XCTAssertEqual(emergencyPos, 1)
        XCTAssertEqual(seniorPos, 2)
    }

    /// Test Case 7: Emergency ride count tracking
    func testEmergencyRideCount() async throws {
        // ARRANGE - No emergencies initially
        let initialCount = try await emergencyService.getEmergencyRideCount(eventId: event.id)
        XCTAssertEqual(initialCount, 0)

        // ACT - Create 3 emergency rides
        _ = try await createEmergencyRide(riderId: "rider-e1", reason: "Emergency 1")
        _ = try await createEmergencyRide(riderId: "rider-e2", reason: "Emergency 2")
        _ = try await createEmergencyRide(riderId: "rider-e3", reason: "Emergency 3")

        // ASSERT - Count should be 3
        let finalCount = try await emergencyService.getEmergencyRideCount(eventId: event.id)
        XCTAssertEqual(finalCount, 3)

        // Fetch emergency rides
        let emergencyRides = try await emergencyService.fetchEmergencyRides(eventId: event.id)
        XCTAssertEqual(emergencyRides.count, 3)

        // All should be emergency rides
        for ride in emergencyRides {
            XCTAssertTrue(ride.isEmergency)
            XCTAssertEqual(ride.priority, 9999)
        }
    }

    /// Test Case 8: Error handling - User not found
    func testEmergencyRequestWithInvalidUser() async throws {
        // ARRANGE - Invalid user ID
        let invalidUserId = "nonexistent-user-123"

        // ACT & ASSERT - Should throw error
        do {
            _ = try await emergencyService.handleEmergencyRequest(
                riderId: invalidUserId,
                eventId: event.id,
                location: GeoPoint(latitude: 39.1836, longitude: -96.5717),
                address: "Test Address",
                reason: "Test Emergency"
            )
            XCTFail("Should throw error for invalid user")
        } catch EmergencyError.userNotFound {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Create multiple test rides
    private func createMultipleRides(count: Int, isEmergency: Bool) async throws -> [Ride] {
        var rides: [Ride] = []

        for i in 0..<count {
            let testRider = TestDataFactory.createTestUser(
                id: "rider-\(i)",
                classYear: (i % 4) + 1,
                chapterId: chapter.id
            )
            try await saveUser(testRider)

            let ride = TestDataFactory.createTestRide(
                riderId: testRider.id,
                chapterId: chapter.id,
                eventId: event.id,
                classYear: testRider.classYear,
                waitMinutes: Double(i * 5),
                isEmergency: isEmergency
            )
            try await saveRide(ride)
            rides.append(ride)
        }

        return rides
    }

    /// Create an emergency ride for testing
    private func createEmergencyRide(riderId: String, reason: String) async throws -> Ride {
        let testRider = TestDataFactory.createTestUser(id: riderId, classYear: 2, chapterId: chapter.id)
        try await saveUser(testRider)

        return try await emergencyService.handleEmergencyRequest(
            riderId: testRider.id,
            eventId: event.id,
            location: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            address: "Emergency Location - \(reason)",
            reason: reason
        )
    }
}

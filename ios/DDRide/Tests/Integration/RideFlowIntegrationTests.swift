//
//  RideFlowIntegrationTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
import CoreLocation
@testable import DDRide

/// Integration tests for complete ride request flow
///
/// Tests the end-to-end ride lifecycle:
/// 1. Rider requests ride → queued
/// 2. System assigns to best DD → assigned
/// 3. DD marks en route → enroute
/// 4. DD completes ride → completed
///
/// This tests integration between:
/// - RideRequestService
/// - DDAssignmentService
/// - RideQueueService
/// - NotificationService (mocked)
final class RideFlowIntegrationTests: DDRideTestCase {

    var rideRequestService: RideRequestService!
    var ddAssignmentService: DDAssignmentService!
    var queueService: RideQueueService!

    var chapter: Chapter!
    var event: Event!
    var rider: User!
    var dd: User!

    override func setUp() async throws {
        try await super.setUp()

        rideRequestService = RideRequestService.shared
        ddAssignmentService = DDAssignmentService.shared
        queueService = RideQueueService.shared

        // Setup test data
        chapter = TestDataFactory.createTestChapter(id: "test-chapter")
        event = TestDataFactory.createTestEvent(chapterId: chapter.id)
        rider = TestDataFactory.createTestUser(id: "rider-1", classYear: 3, chapterId: chapter.id)
        dd = TestDataFactory.createTestUser(id: "dd-1", classYear: 4, chapterId: chapter.id)

        try await saveChapter(chapter)
        try await saveEvent(event)
        try await saveUser(rider)
        try await saveUser(dd)

        // Create DD assignment
        let ddAssignment = TestDataFactory.createTestDDAssignment(
            userId: dd.id,
            eventId: event.id,
            isActive: true
        )
        try await saveDDAssignment(ddAssignment)
    }

    // MARK: - Complete Ride Flow

    /// Test Case 1: Complete ride flow from request to completion
    func testCompleteRideFlow() async throws {
        // Step 1: Rider requests ride
        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

        let ride = try await rideRequestService.requestRide(
            userId: rider.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        // Verify ride is queued
        XCTAssertEqual(ride.status, .queued, "Ride should start as queued")
        XCTAssertEqual(ride.riderId, rider.id)
        XCTAssertEqual(ride.eventId, event.id)
        XCTAssertNil(ride.ddId, "Ride should not have DD assigned yet")
        XCTAssertNotNil(ride.requestedAt)
        XCTAssertNil(ride.assignedAt)

        // Verify priority is calculated correctly (junior with 0 wait)
        // (3 × 10) + (0 × 0.5) = 30.0
        XCTAssertEqual(ride.priority, 30.0, accuracy: 0.1)

        // Step 2: System assigns ride to DD
        let allRides = try await fetchRidesForEvent(event.id)
        guard let bestDD = try await ddAssignmentService.findBestDD(for: event, rides: allRides) else {
            XCTFail("Should find available DD")
            return
        }

        var assignedRide = ride
        try await ddAssignmentService.assignRide(assignedRide, to: bestDD)

        // Fetch updated ride
        assignedRide = try await fetchRide(id: ride.id)

        // Verify ride is assigned
        XCTAssertEqual(assignedRide.status, .assigned, "Ride should be assigned")
        XCTAssertEqual(assignedRide.ddId, dd.id, "Ride should be assigned to DD")
        XCTAssertNotNil(assignedRide.assignedAt, "Assignment time should be set")
        XCTAssertNotNil(assignedRide.estimatedWaitTime, "Wait time should be calculated")
        XCTAssertNotNil(assignedRide.queuePosition, "Queue position should be set")

        // Step 3: DD marks en route
        assignedRide.status = .enroute
        assignedRide.enrouteAt = Date()
        assignedRide.estimatedWaitTime = 10 // 10 minutes ETA
        try await saveRide(assignedRide)

        // Fetch updated ride
        let enrouteRide = try await fetchRide(id: ride.id)

        // Verify ride is en route
        XCTAssertEqual(enrouteRide.status, .enroute, "Ride should be en route")
        XCTAssertNotNil(enrouteRide.enrouteAt, "En route time should be set")
        XCTAssertNotNil(enrouteRide.estimatedWaitTime, "ETA should be set")

        // Step 4: DD completes ride
        var completedRide = enrouteRide
        completedRide.status = .completed
        completedRide.completedAt = Date()
        try await saveRide(completedRide)

        // Fetch final ride state
        let finalRide = try await fetchRide(id: ride.id)

        // Verify ride is completed
        XCTAssertEqual(finalRide.status, .completed, "Ride should be completed")
        XCTAssertNotNil(finalRide.completedAt, "Completion time should be set")

        // Verify all timestamps are present
        XCTAssertNotNil(finalRide.requestedAt)
        XCTAssertNotNil(finalRide.assignedAt)
        XCTAssertNotNil(finalRide.enrouteAt)
        XCTAssertNotNil(finalRide.completedAt)

        // Verify timeline order
        XCTAssertLessThan(finalRide.requestedAt, finalRide.assignedAt!)
        XCTAssertLessThan(finalRide.assignedAt!, finalRide.enrouteAt!)
        XCTAssertLessThan(finalRide.enrouteAt!, finalRide.completedAt!)
    }

    // MARK: - Multiple Riders

    /// Test Case 2: Multiple riders with priority-based assignment
    func testMultipleRidersQueueCorrectly() async throws {
        // Given: 4 riders with different priorities
        let freshman = TestDataFactory.createTestUser(id: "freshman", classYear: 1, chapterId: chapter.id)
        let sophomore = TestDataFactory.createTestUser(id: "sophomore", classYear: 2, chapterId: chapter.id)
        let junior = TestDataFactory.createTestUser(id: "junior", classYear: 3, chapterId: chapter.id)
        let senior = TestDataFactory.createTestUser(id: "senior", classYear: 4, chapterId: chapter.id)

        try await saveUsers([freshman, sophomore, junior, senior])

        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

        // When: All request rides at same time
        let freshmanRide = try await rideRequestService.requestRide(
            userId: freshman.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )
        let sophomoreRide = try await rideRequestService.requestRide(
            userId: sophomore.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )
        let juniorRide = try await rideRequestService.requestRide(
            userId: junior.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )
        let seniorRide = try await rideRequestService.requestRide(
            userId: senior.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        // Then: Verify priorities (all have ~0 wait time, so class year dominates)
        // Senior (4×10) = 40, Junior (3×10) = 30, Sophomore (2×10) = 20, Freshman (1×10) = 10
        XCTAssertGreaterThan(seniorRide.priority, juniorRide.priority)
        XCTAssertGreaterThan(juniorRide.priority, sophomoreRide.priority)
        XCTAssertGreaterThan(sophomoreRide.priority, freshmanRide.priority)

        // And: Verify queue positions
        let seniorPosition = try await queueService.getOverallQueuePosition(
            rideId: seniorRide.id,
            eventId: event.id
        )
        let freshmanPosition = try await queueService.getOverallQueuePosition(
            rideId: freshmanRide.id,
            eventId: event.id
        )

        XCTAssertEqual(seniorPosition, 1, "Senior should be first in line")
        XCTAssertEqual(freshmanPosition, 4, "Freshman should be last in line")
    }

    // MARK: - Multiple DDs

    /// Test Case 3: Multiple DDs receive rides based on wait time
    func testMultipleDDsLoadBalancing() async throws {
        // Given: 3 active DDs
        let dd2 = TestDataFactory.createTestUser(id: "dd-2", classYear: 4, chapterId: chapter.id)
        let dd3 = TestDataFactory.createTestUser(id: "dd-3", classYear: 3, chapterId: chapter.id)

        try await saveUsers([dd2, dd3])

        let assignment2 = TestDataFactory.createTestDDAssignment(userId: dd2.id, eventId: event.id)
        let assignment3 = TestDataFactory.createTestDDAssignment(userId: dd3.id, eventId: event.id)

        try await saveDDAssignments([assignment2, assignment3])

        // When: 5 riders request rides
        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)
        var rides: [Ride] = []

        for i in 1...5 {
            let riderUser = TestDataFactory.createTestUser(
                id: "rider-\(i)",
                classYear: 2,
                chapterId: chapter.id
            )
            try await saveUser(riderUser)

            let ride = try await rideRequestService.requestRide(
                userId: riderUser.id,
                eventId: event.id,
                pickupLocation: coordinate,
                isEmergency: false
            )
            rides.append(ride)
        }

        // Then: Assign all rides and verify distribution
        for ride in rides {
            let allRides = try await fetchRidesForEvent(event.id)
            guard let bestDD = try await ddAssignmentService.findBestDD(for: event, rides: allRides) else {
                XCTFail("Should find available DD")
                continue
            }

            try await ddAssignmentService.assignRide(ride, to: bestDD)
        }

        // Verify rides are distributed across DDs
        let finalRides = try await fetchRidesForEvent(event.id)
        let dd1Rides = finalRides.filter { $0.ddId == dd.id }
        let dd2Rides = finalRides.filter { $0.ddId == dd2.id }
        let dd3Rides = finalRides.filter { $0.ddId == dd3.id }

        // All DDs should have at least 1 ride (load balanced)
        XCTAssertGreaterThan(dd1Rides.count, 0, "DD1 should have rides")
        XCTAssertGreaterThan(dd2Rides.count, 0, "DD2 should have rides")
        XCTAssertGreaterThan(dd3Rides.count, 0, "DD3 should have rides")

        // Total should be 5 rides (plus the original rider)
        let totalAssignedRides = dd1Rides.count + dd2Rides.count + dd3Rides.count
        XCTAssertEqual(totalAssignedRides, 5, "All 5 rides should be assigned")
    }

    // MARK: - Emergency Rides

    /// Test Case 4: Emergency rides get immediate priority
    func testEmergencyRidesGetImmediatePriority() async throws {
        // Given: Regular senior ride already in queue
        let seniorRider = TestDataFactory.createTestUser(id: "senior-rider", classYear: 4, chapterId: chapter.id)
        try await saveUser(seniorRider)

        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

        let seniorRide = try await rideRequestService.requestRide(
            userId: seniorRider.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        // When: Freshman requests emergency ride
        let freshmanRider = TestDataFactory.createTestUser(id: "freshman-rider", classYear: 1, chapterId: chapter.id)
        try await saveUser(freshmanRider)

        let emergencyRide = try await rideRequestService.requestRide(
            userId: freshmanRider.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: true
        )

        // Then: Emergency ride should have highest priority
        XCTAssertEqual(emergencyRide.priority, 9999.0, "Emergency should have max priority")
        XCTAssertGreaterThan(emergencyRide.priority, seniorRide.priority)

        // And: Emergency should be first in queue
        let emergencyPosition = try await queueService.getOverallQueuePosition(
            rideId: emergencyRide.id,
            eventId: event.id
        )
        XCTAssertEqual(emergencyPosition, 1, "Emergency should be first in queue")
    }

    // MARK: - Ride Cancellation

    /// Test Case 5: Rider can cancel queued ride
    func testRiderCanCancelQueuedRide() async throws {
        // Given: Rider has requested ride
        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

        let ride = try await rideRequestService.requestRide(
            userId: rider.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        XCTAssertEqual(ride.status, .queued)

        // When: Rider cancels ride
        var cancelledRide = ride
        cancelledRide.status = .cancelled
        cancelledRide.cancelledAt = Date()
        cancelledRide.cancellationReason = "Changed plans"
        try await saveRide(cancelledRide)

        // Then: Ride should be cancelled
        let finalRide = try await fetchRide(id: ride.id)
        XCTAssertEqual(finalRide.status, .cancelled)
        XCTAssertNotNil(finalRide.cancelledAt)
        XCTAssertEqual(finalRide.cancellationReason, "Changed plans")

        // And: Should not be in active queue
        let activeRides = try await fetchRidesForEvent(event.id)
            .filter { $0.status == .queued || $0.status == .assigned || $0.status == .enroute }
        XCTAssertFalse(activeRides.contains(where: { $0.id == ride.id }))
    }

    // MARK: - Cross-Chapter Rides

    /// Test Case 6: Cross-chapter rides have lower priority
    func testCrossChapterRidesHaveLowerPriority() async throws {
        // Given: Event allows cross-chapter rides
        var crossChapterEvent = event!
        crossChapterEvent.allowedChapterIds = ["ALL"]
        try await saveEvent(crossChapterEvent)

        // Create riders from different chapters
        let sameChapterSenior = TestDataFactory.createTestUser(
            id: "same-senior",
            classYear: 4,
            chapterId: chapter.id // Same chapter as event
        )
        let otherChapter = TestDataFactory.createTestChapter(id: "other-chapter", name: "Other Chapter")
        try await saveChapter(otherChapter)

        let crossChapterFreshman = TestDataFactory.createTestUser(
            id: "cross-freshman",
            classYear: 1,
            chapterId: otherChapter.id // Different chapter
        )

        try await saveUsers([sameChapterSenior, crossChapterFreshman])

        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

        // When: Both request rides
        let sameChapterRide = try await rideRequestService.requestRide(
            userId: sameChapterSenior.id,
            eventId: crossChapterEvent.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        let crossChapterRide = try await rideRequestService.requestRide(
            userId: crossChapterFreshman.id,
            eventId: crossChapterEvent.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        // Then: Same-chapter senior should have higher priority than cross-chapter freshman
        // Same chapter: (4×10) + (0×0.5) = 40
        // Cross chapter: (0×0.5) = 0 (class year ignored)
        XCTAssertGreaterThan(sameChapterRide.priority, crossChapterRide.priority)

        XCTAssertEqual(sameChapterRide.priority, 40.0, accuracy: 0.1)
        XCTAssertEqual(crossChapterRide.priority, 0.0, accuracy: 0.1)
    }

    // MARK: - No Available DDs

    /// Test Case 7: Handle case with no available DDs
    func testNoAvailableDDsScenario() async throws {
        // Given: All DDs are inactive
        let ddAssignment = try await fetchDDAssignment(id: dd.id)
        var inactiveAssignment = ddAssignment
        inactiveAssignment.isActive = false
        try await saveDDAssignment(inactiveAssignment)

        // When: Rider requests ride
        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

        let ride = try await rideRequestService.requestRide(
            userId: rider.id,
            eventId: event.id,
            pickupLocation: coordinate,
            isEmergency: false
        )

        // Then: Ride should be queued but not assigned
        XCTAssertEqual(ride.status, .queued)
        XCTAssertNil(ride.ddId)

        // And: Finding best DD should return nil
        let allRides = try await fetchRidesForEvent(event.id)
        let bestDD = try await ddAssignmentService.findBestDD(for: event, rides: allRides)
        XCTAssertNil(bestDD, "Should not find DD when all are inactive")
    }
}

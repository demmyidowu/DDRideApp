//
//  DDAssignmentServiceTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
@testable import DDRide

/// Unit tests for DDAssignmentService
///
/// Tests the critical DD assignment algorithm:
/// - Assigns to DD with SHORTEST WAIT TIME (not lowest ride count)
/// - Wait time = number of active rides × 15 minutes
/// - DD with 0 active rides has 0 wait time
/// - Inactive DDs are not assigned rides
///
/// Business Logic:
/// - If DD has no active rides → 0 minutes wait
/// - If DD has rides → sum estimated time for all queued/active rides
/// - Assign to DD with minimum wait time
final class DDAssignmentServiceTests: DDRideTestCase {

    var service: DDAssignmentService!
    var event: Event!
    var chapter: Chapter!

    override func setUp() async throws {
        try await super.setUp()
        service = DDAssignmentService.shared

        // Create test chapter and event
        chapter = TestDataFactory.createTestChapter(id: "test-chapter")
        event = TestDataFactory.createTestEvent(chapterId: chapter.id)

        try await saveChapter(chapter)
        try await saveEvent(event)
    }

    // MARK: - Wait Time Calculation Tests

    /// Test Case 1: DD with no active rides has 0 wait time
    func testDDWithNoRidesHasZeroWaitTime() async throws {
        // Given: DD with no rides
        let dd = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        try await saveUser(dd)

        let assignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id)
        try await saveDDAssignment(assignment)

        let allRides: [Ride] = []

        // When: Calculate wait time
        let waitTime = try await service.calculateWaitTime(for: assignment, with: allRides)

        // Then: Wait time should be 0
        XCTAssertEqual(waitTime, 0)
    }

    /// Test Case 2: DD with 1 active ride has 15 minute wait (900 seconds)
    func testDDWithOneRideHas15MinuteWait() async throws {
        // Given: DD with 1 active ride
        let dd = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        try await saveUser(dd)

        let assignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id)
        try await saveDDAssignment(assignment)

        let rider = TestDataFactory.createTestUser(id: "rider1", classYear: 2, chapterId: chapter.id)
        try await saveUser(rider)

        let ride = TestDataFactory.createTestRide(
            riderId: rider.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .assigned,
            ddId: dd.id
        )
        try await saveRide(ride)

        let allRides = [ride]

        // When: Calculate wait time
        let waitTime = try await service.calculateWaitTime(for: assignment, with: allRides)

        // Then: Wait time should be 15 minutes = 900 seconds
        XCTAssertEqual(waitTime, 900, accuracy: 1)
    }

    /// Test Case 3: DD with 2 active rides has 30 minute wait (1800 seconds)
    func testDDWithTwoRidesHas30MinuteWait() async throws {
        // Given: DD with 2 active rides
        let dd = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        try await saveUser(dd)

        let assignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id)
        try await saveDDAssignment(assignment)

        let rider1 = TestDataFactory.createTestUser(id: "rider1", classYear: 2, chapterId: chapter.id)
        let rider2 = TestDataFactory.createTestUser(id: "rider2", classYear: 3, chapterId: chapter.id)
        try await saveUser(rider1)
        try await saveUser(rider2)

        let ride1 = TestDataFactory.createTestRide(
            riderId: rider1.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .enroute,
            ddId: dd.id
        )
        let ride2 = TestDataFactory.createTestRide(
            riderId: rider2.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .assigned,
            ddId: dd.id
        )
        try await saveRide(ride1)
        try await saveRide(ride2)

        let allRides = [ride1, ride2]

        // When: Calculate wait time
        let waitTime = try await service.calculateWaitTime(for: assignment, with: allRides)

        // Then: Wait time should be 30 minutes = 1800 seconds
        XCTAssertEqual(waitTime, 1800, accuracy: 1)
    }

    /// Test Case 4: Only count active rides (queued, assigned, enroute)
    func testOnlyActiveRidesCountTowardWaitTime() async throws {
        // Given: DD with 2 active rides and 1 completed ride
        let dd = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        try await saveUser(dd)

        let assignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id)
        try await saveDDAssignment(assignment)

        let rider1 = TestDataFactory.createTestUser(id: "rider1", classYear: 2, chapterId: chapter.id)
        let rider2 = TestDataFactory.createTestUser(id: "rider2", classYear: 3, chapterId: chapter.id)
        let rider3 = TestDataFactory.createTestUser(id: "rider3", classYear: 1, chapterId: chapter.id)
        try await saveUsers([rider1, rider2, rider3])

        let activeRide1 = TestDataFactory.createTestRide(
            riderId: rider1.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .assigned,
            ddId: dd.id
        )
        let activeRide2 = TestDataFactory.createTestRide(
            riderId: rider2.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .enroute,
            ddId: dd.id
        )
        let completedRide = TestDataFactory.createTestRide(
            riderId: rider3.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .completed,
            ddId: dd.id
        )

        try await saveRides([activeRide1, activeRide2, completedRide])

        let allRides = [activeRide1, activeRide2, completedRide]

        // When: Calculate wait time
        let waitTime = try await service.calculateWaitTime(for: assignment, with: allRides)

        // Then: Wait time should be 30 minutes (only 2 active rides)
        XCTAssertEqual(waitTime, 1800, accuracy: 1)
    }

    // MARK: - Find Best DD Tests

    /// Test Case 5: Assign to DD with shortest wait time
    func testAssignToDDWithShortestWaitTime() async throws {
        // Given: 3 DDs with different workloads
        let dd1 = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        let dd2 = TestDataFactory.createTestUser(id: "dd2", classYear: 4, chapterId: chapter.id)
        let dd3 = TestDataFactory.createTestUser(id: "dd3", classYear: 2, chapterId: chapter.id)

        try await saveUsers([dd1, dd2, dd3])

        let assignment1 = TestDataFactory.createTestDDAssignment(userId: dd1.id, eventId: event.id)
        let assignment2 = TestDataFactory.createTestDDAssignment(userId: dd2.id, eventId: event.id)
        let assignment3 = TestDataFactory.createTestDDAssignment(userId: dd3.id, eventId: event.id)

        try await saveDDAssignments([assignment1, assignment2, assignment3])

        // DD1: 2 active rides (30 min wait)
        let rider1 = TestDataFactory.createTestUser(id: "rider1", classYear: 2, chapterId: chapter.id)
        let rider2 = TestDataFactory.createTestUser(id: "rider2", classYear: 3, chapterId: chapter.id)
        try await saveUsers([rider1, rider2])

        let dd1Ride1 = TestDataFactory.createTestRide(
            riderId: rider1.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .assigned,
            ddId: dd1.id
        )
        let dd1Ride2 = TestDataFactory.createTestRide(
            riderId: rider2.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .enroute,
            ddId: dd1.id
        )

        // DD2: 1 active ride (15 min wait)
        let rider3 = TestDataFactory.createTestUser(id: "rider3", classYear: 1, chapterId: chapter.id)
        try await saveUser(rider3)

        let dd2Ride1 = TestDataFactory.createTestRide(
            riderId: rider3.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .assigned,
            ddId: dd2.id
        )

        // DD3: 0 active rides (0 min wait)

        let allRides = [dd1Ride1, dd1Ride2, dd2Ride1]
        try await saveRides(allRides)

        // When: Find best DD
        let bestDD = try await service.findBestDD(for: event, rides: allRides)

        // Then: Should assign to DD3 (shortest wait time = 0)
        XCTAssertNotNil(bestDD)
        XCTAssertEqual(bestDD?.userId, dd3.id)
    }

    /// Test Case 6: When multiple DDs have same wait time, pick first one
    func testSameWaitTimePicksFirstDD() async throws {
        // Given: 2 DDs with same workload (0 rides each)
        let dd1 = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        let dd2 = TestDataFactory.createTestUser(id: "dd2", classYear: 4, chapterId: chapter.id)

        try await saveUsers([dd1, dd2])

        let assignment1 = TestDataFactory.createTestDDAssignment(userId: dd1.id, eventId: event.id)
        let assignment2 = TestDataFactory.createTestDDAssignment(userId: dd2.id, eventId: event.id)

        try await saveDDAssignments([assignment1, assignment2])

        let allRides: [Ride] = []

        // When: Find best DD
        let bestDD = try await service.findBestDD(for: event, rides: allRides)

        // Then: Should return one of them (both have 0 wait)
        XCTAssertNotNil(bestDD)
        XCTAssertTrue(bestDD?.userId == dd1.id || bestDD?.userId == dd2.id)
    }

    /// Test Case 7: Inactive DDs are not assigned
    func testInactiveDDsNotAssigned() async throws {
        // Given: 1 active DD and 1 inactive DD (both with 0 rides)
        let ddActive = TestDataFactory.createTestUser(id: "dd-active", classYear: 3, chapterId: chapter.id)
        let ddInactive = TestDataFactory.createTestUser(id: "dd-inactive", classYear: 4, chapterId: chapter.id)

        try await saveUsers([ddActive, ddInactive])

        let assignmentActive = TestDataFactory.createTestDDAssignment(
            userId: ddActive.id,
            eventId: event.id,
            isActive: true
        )
        let assignmentInactive = TestDataFactory.createTestDDAssignment(
            userId: ddInactive.id,
            eventId: event.id,
            isActive: false
        )

        try await saveDDAssignments([assignmentActive, assignmentInactive])

        let allRides: [Ride] = []

        // When: Find best DD
        let bestDD = try await service.findBestDD(for: event, rides: allRides)

        // Then: Should only return active DD
        XCTAssertNotNil(bestDD)
        XCTAssertEqual(bestDD?.userId, ddActive.id)
        XCTAssertTrue(bestDD?.isActive ?? false)
    }

    /// Test Case 8: Return nil if no active DDs available
    func testReturnsNilIfNoActiveDDs() async throws {
        // Given: 2 inactive DDs
        let dd1 = TestDataFactory.createTestUser(id: "dd1", classYear: 3, chapterId: chapter.id)
        let dd2 = TestDataFactory.createTestUser(id: "dd2", classYear: 4, chapterId: chapter.id)

        try await saveUsers([dd1, dd2])

        let assignment1 = TestDataFactory.createTestDDAssignment(
            userId: dd1.id,
            eventId: event.id,
            isActive: false
        )
        let assignment2 = TestDataFactory.createTestDDAssignment(
            userId: dd2.id,
            eventId: event.id,
            isActive: false
        )

        try await saveDDAssignments([assignment1, assignment2])

        let allRides: [Ride] = []

        // When: Find best DD
        let bestDD = try await service.findBestDD(for: event, rides: allRides)

        // Then: Should return nil (no active DDs)
        XCTAssertNil(bestDD)
    }

    // MARK: - Complex Workload Scenarios

    /// Test Case 9: Multiple DDs with varying workloads
    func testMultipleDDsWithVaryingWorkloads() async throws {
        // Given: 4 DDs with different workloads
        let dds = (1...4).map { i in
            TestDataFactory.createTestUser(id: "dd\(i)", classYear: i, chapterId: chapter.id)
        }

        try await saveUsers(dds)

        let assignments = dds.map { dd in
            TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id)
        }

        try await saveDDAssignments(assignments)

        // DD1: 3 rides, DD2: 1 ride, DD3: 0 rides, DD4: 2 rides
        var allRides: [Ride] = []

        // DD1 rides (3)
        for i in 1...3 {
            let rider = TestDataFactory.createTestUser(id: "rider\(i)", classYear: 2, chapterId: chapter.id)
            try await saveUser(rider)

            let ride = TestDataFactory.createTestRide(
                riderId: rider.id,
                chapterId: chapter.id,
                eventId: event.id,
                status: .assigned,
                ddId: dds[0].id
            )
            allRides.append(ride)
            try await saveRide(ride)
        }

        // DD2 rides (1)
        let rider4 = TestDataFactory.createTestUser(id: "rider4", classYear: 3, chapterId: chapter.id)
        try await saveUser(rider4)

        let ride4 = TestDataFactory.createTestRide(
            riderId: rider4.id,
            chapterId: chapter.id,
            eventId: event.id,
            status: .assigned,
            ddId: dds[1].id
        )
        allRides.append(ride4)
        try await saveRide(ride4)

        // DD4 rides (2)
        for i in 5...6 {
            let rider = TestDataFactory.createTestUser(id: "rider\(i)", classYear: 1, chapterId: chapter.id)
            try await saveUser(rider)

            let ride = TestDataFactory.createTestRide(
                riderId: rider.id,
                chapterId: chapter.id,
                eventId: event.id,
                status: .assigned,
                ddId: dds[3].id
            )
            allRides.append(ride)
            try await saveRide(ride)
        }

        // When: Find best DD
        let bestDD = try await service.findBestDD(for: event, rides: allRides)

        // Then: Should assign to DD3 (0 rides = shortest wait)
        XCTAssertNotNil(bestDD)
        XCTAssertEqual(bestDD?.userId, dds[2].id)

        // Verify wait times
        let waitTimes = await service.calculateWaitTimes(for: assignments, with: allRides)
        XCTAssertEqual(waitTimes[dds[0].id], 2700, accuracy: 1) // 45 min = 3 rides × 15
        XCTAssertEqual(waitTimes[dds[1].id], 900, accuracy: 1)  // 15 min = 1 ride × 15
        XCTAssertEqual(waitTimes[dds[2].id], 0, accuracy: 1)    // 0 min = 0 rides
        XCTAssertEqual(waitTimes[dds[3].id], 1800, accuracy: 1) // 30 min = 2 rides × 15
    }

    // MARK: - Edge Cases

    /// Test Case 10: No DDs assigned to event
    func testNoDDsAssignedToEvent() async throws {
        // Given: Event with no DD assignments
        let allRides: [Ride] = []

        // When: Find best DD
        let bestDD = try await service.findBestDD(for: event, rides: allRides)

        // Then: Should return nil
        XCTAssertNil(bestDD)
    }
}

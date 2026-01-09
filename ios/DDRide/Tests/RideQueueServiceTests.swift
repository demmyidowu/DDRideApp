//
//  RideQueueServiceTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
@testable import DDRide

/// Unit tests for RideQueueService priority calculation with cross-chapter support
///
/// Tests verify the critical business logic:
/// - Same chapter: (classYear × 10) + (waitMinutes × 0.5)
/// - Cross chapter: (waitMinutes × 0.5) only
/// - Emergency: always 9999
final class RideQueueServiceTests: XCTestCase {

    var sut: RideQueueService!

    override func setUp() {
        super.setUp()
        sut = RideQueueService.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Same Chapter Tests

    /// Test Case 1: Same chapter - Senior waiting 5 minutes
    /// Expected: (4×10) + (5×0.5) = 42.5
    func testSameChapterSenior() {
        let priority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 5.0,
            isEmergency: false,
            isSameChapter: true
        )

        XCTAssertEqual(priority, 42.5, accuracy: 0.01)
    }

    /// Test Case 2: Same chapter - Junior waiting 10 minutes
    /// Expected: (3×10) + (10×0.5) = 35.0
    func testSameChapterJunior() {
        let priority = sut.calculatePriority(
            classYear: 3,
            waitMinutes: 10.0,
            isEmergency: false,
            isSameChapter: true
        )

        XCTAssertEqual(priority, 35.0, accuracy: 0.01)
    }

    /// Test Case 3: Same chapter - Sophomore waiting 20 minutes
    /// Expected: (2×10) + (20×0.5) = 30.0
    func testSameChapterSophomore() {
        let priority = sut.calculatePriority(
            classYear: 2,
            waitMinutes: 20.0,
            isEmergency: false,
            isSameChapter: true
        )

        XCTAssertEqual(priority, 30.0, accuracy: 0.01)
    }

    /// Test Case 4: Same chapter - Freshman waiting 15 minutes
    /// Expected: (1×10) + (15×0.5) = 17.5
    func testSameChapterFreshman() {
        let priority = sut.calculatePriority(
            classYear: 1,
            waitMinutes: 15.0,
            isEmergency: false,
            isSameChapter: true
        )

        XCTAssertEqual(priority, 17.5, accuracy: 0.01)
    }

    // MARK: - Cross Chapter Tests

    /// Test Case 5: Cross chapter - Senior waiting 5 minutes (class year ignored)
    /// Expected: 5×0.5 = 2.5
    func testCrossChapterSenior() {
        let priority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 5.0,
            isEmergency: false,
            isSameChapter: false
        )

        XCTAssertEqual(priority, 2.5, accuracy: 0.01)
    }

    /// Test Case 6: Cross chapter - Freshman waiting 15 minutes (class year ignored)
    /// Expected: 15×0.5 = 7.5
    func testCrossChapterFreshman() {
        let priority = sut.calculatePriority(
            classYear: 1,
            waitMinutes: 15.0,
            isEmergency: false,
            isSameChapter: false
        )

        XCTAssertEqual(priority, 7.5, accuracy: 0.01)
    }

    /// Test Case 7: Cross chapter - Junior waiting 30 minutes
    /// Expected: 30×0.5 = 15.0
    func testCrossChapterJunior() {
        let priority = sut.calculatePriority(
            classYear: 3,
            waitMinutes: 30.0,
            isEmergency: false,
            isSameChapter: false
        )

        XCTAssertEqual(priority, 15.0, accuracy: 0.01)
    }

    /// Test Case 8: Cross chapter - Verify class year is ignored
    /// A freshman waiting longer should beat a senior waiting less
    func testCrossChapterClassYearIgnored() {
        let seniorPriority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 5.0,
            isEmergency: false,
            isSameChapter: false
        )

        let freshmanPriority = sut.calculatePriority(
            classYear: 1,
            waitMinutes: 10.0,
            isEmergency: false,
            isSameChapter: false
        )

        // Freshman waiting 10 min (5.0) > Senior waiting 5 min (2.5)
        XCTAssertGreaterThan(freshmanPriority, seniorPriority)
        XCTAssertEqual(freshmanPriority, 5.0, accuracy: 0.01)
        XCTAssertEqual(seniorPriority, 2.5, accuracy: 0.01)
    }

    // MARK: - Emergency Tests

    /// Test Case 9: Emergency (same chapter) - always 9999
    func testEmergencySameChapter() {
        let priority = sut.calculatePriority(
            classYear: 2,
            waitMinutes: 10.0,
            isEmergency: true,
            isSameChapter: true
        )

        XCTAssertEqual(priority, 9999.0)
    }

    /// Test Case 10: Emergency (cross chapter) - always 9999
    func testEmergencyCrossChapter() {
        let priority = sut.calculatePriority(
            classYear: 2,
            waitMinutes: 10.0,
            isEmergency: true,
            isSameChapter: false
        )

        XCTAssertEqual(priority, 9999.0)
    }

    // MARK: - Comparison Tests

    /// Test Case 11: Same chapter senior beats cross chapter senior (same wait time)
    /// Same chapter: (4×10) + (5×0.5) = 42.5
    /// Cross chapter: 5×0.5 = 2.5
    func testSameChapterBeatsCrossChapterSameWait() {
        let sameChapterPriority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 5.0,
            isEmergency: false,
            isSameChapter: true
        )

        let crossChapterPriority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 5.0,
            isEmergency: false,
            isSameChapter: false
        )

        XCTAssertGreaterThan(sameChapterPriority, crossChapterPriority)
        XCTAssertEqual(sameChapterPriority, 42.5, accuracy: 0.01)
        XCTAssertEqual(crossChapterPriority, 2.5, accuracy: 0.01)
    }

    /// Test Case 12: Cross chapter rider waiting long enough can beat same chapter freshman
    /// Cross chapter waiting 40 min: 40×0.5 = 20.0
    /// Same chapter freshman waiting 5 min: (1×10) + (5×0.5) = 12.5
    func testCrossChapterCanBeatSameChapterFreshman() {
        let crossChapterPriority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 40.0,
            isEmergency: false,
            isSameChapter: false
        )

        let sameChapterPriority = sut.calculatePriority(
            classYear: 1,
            waitMinutes: 5.0,
            isEmergency: false,
            isSameChapter: true
        )

        XCTAssertGreaterThan(crossChapterPriority, sameChapterPriority)
        XCTAssertEqual(crossChapterPriority, 20.0, accuracy: 0.01)
        XCTAssertEqual(sameChapterPriority, 12.5, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    /// Test Case 13: Zero wait time
    func testZeroWaitTime() {
        let sameChapterPriority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 0.0,
            isEmergency: false,
            isSameChapter: true
        )

        let crossChapterPriority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: 0.0,
            isEmergency: false,
            isSameChapter: false
        )

        XCTAssertEqual(sameChapterPriority, 40.0) // Only class year counts
        XCTAssertEqual(crossChapterPriority, 0.0) // No wait time = 0 priority
    }

    /// Test Case 14: Negative wait time (should not happen in practice, but test boundary)
    func testNegativeWaitTime() {
        let priority = sut.calculatePriority(
            classYear: 4,
            waitMinutes: -5.0,
            isEmergency: false,
            isSameChapter: true
        )

        // Should handle gracefully: (4×10) + (-5×0.5) = 37.5
        XCTAssertEqual(priority, 37.5, accuracy: 0.01)
    }

    /// Test Case 15: Very high wait time (hour+)
    func testHighWaitTime() {
        let priority = sut.calculatePriority(
            classYear: 1,
            waitMinutes: 120.0,
            isEmergency: false,
            isSameChapter: true
        )

        // (1×10) + (120×0.5) = 70.0
        XCTAssertEqual(priority, 70.0, accuracy: 0.01)
    }

    // MARK: - Helper Method Tests

    /// Test Case 16: isSameChapterRide with matching chapter
    func testIsSameChapterRide_Matching() {
        let ride = Ride(
            id: "ride1",
            riderId: "rider1",
            ddId: nil,
            chapterId: "chapter1",
            eventId: "event1",
            pickupLocation: GeoPoint(latitude: 39.0, longitude: -96.0),
            pickupAddress: "123 Main St",
            dropoffAddress: nil,
            status: .queued,
            priority: 0,
            isEmergency: false,
            estimatedWaitTime: nil,
            queuePosition: nil,
            requestedAt: Date(),
            assignedAt: nil,
            enrouteAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            cancellationReason: nil,
            notes: nil
        )

        let event = Event(
            id: "event1",
            name: "Test Event",
            chapterId: "chapter1",
            date: Date(),
            allowedChapterIds: ["chapter1"],
            status: .active,
            location: nil,
            description: nil,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: "admin1"
        )

        XCTAssertTrue(sut.isSameChapterRide(ride: ride, event: event))
    }

    /// Test Case 17: isSameChapterRide with different chapter
    func testIsSameChapterRide_Different() {
        let ride = Ride(
            id: "ride1",
            riderId: "rider1",
            ddId: nil,
            chapterId: "chapter2",
            eventId: "event1",
            pickupLocation: GeoPoint(latitude: 39.0, longitude: -96.0),
            pickupAddress: "123 Main St",
            dropoffAddress: nil,
            status: .queued,
            priority: 0,
            isEmergency: false,
            estimatedWaitTime: nil,
            queuePosition: nil,
            requestedAt: Date(),
            assignedAt: nil,
            enrouteAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            cancellationReason: nil,
            notes: nil
        )

        let event = Event(
            id: "event1",
            name: "Test Event",
            chapterId: "chapter1",
            date: Date(),
            allowedChapterIds: ["chapter1", "chapter2"],
            status: .active,
            location: nil,
            description: nil,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: "admin1"
        )

        XCTAssertFalse(sut.isSameChapterRide(ride: ride, event: event))
    }

    /// Test Case 18: isSameChapterRide with "ALL" chapters allowed
    func testIsSameChapterRide_AllChapters() {
        let ride = Ride(
            id: "ride1",
            riderId: "rider1",
            ddId: nil,
            chapterId: "chapter2",
            eventId: "event1",
            pickupLocation: GeoPoint(latitude: 39.0, longitude: -96.0),
            pickupAddress: "123 Main St",
            dropoffAddress: nil,
            status: .queued,
            priority: 0,
            isEmergency: false,
            estimatedWaitTime: nil,
            queuePosition: nil,
            requestedAt: Date(),
            assignedAt: nil,
            enrouteAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            cancellationReason: nil,
            notes: nil
        )

        let event = Event(
            id: "event1",
            name: "Test Event",
            chapterId: "chapter1",
            date: Date(),
            allowedChapterIds: ["ALL"],
            status: .active,
            location: nil,
            description: nil,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: "admin1"
        )

        // Even with "ALL" allowed, rider from chapter2 is different from event's chapter1
        XCTAssertFalse(sut.isSameChapterRide(ride: ride, event: event))
    }
}

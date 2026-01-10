//
//  TestDataFactory.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import Foundation
import FirebaseFirestore
@testable import DDRide

/// Factory for creating consistent test data across all tests
///
/// This factory provides methods to create realistic test data that matches
/// the production data structure. All data uses unique IDs to avoid collisions.
///
/// Usage:
/// ```swift
/// let chapter = TestDataFactory.createTestChapter()
/// let senior = TestDataFactory.createTestUser(classYear: 4, chapterId: chapter.id)
/// let event = TestDataFactory.createTestEvent(chapterId: chapter.id)
/// ```
class TestDataFactory {

    // MARK: - Chapter

    /// Create a test chapter
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - name: Chapter name (default: "Test Sigma Chi")
    ///   - universityId: University ID (default: "ksu")
    /// - Returns: Chapter instance
    static func createTestChapter(
        id: String? = nil,
        name: String = "Test Sigma Chi",
        universityId: String = "ksu"
    ) -> Chapter {
        let chapterId = id ?? "chapter-\(UUID().uuidString)"

        return Chapter(
            id: chapterId,
            name: name,
            universityId: universityId,
            inviteCode: "TEST\(Int.random(in: 1000...9999))",
            yearTransitionDate: Date(timeIntervalSince1970: 1722470400), // August 1, 2024
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - User

    /// Create a test user
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - classYear: Class year (1-4)
    ///   - role: User role (default: .member)
    ///   - chapterId: Chapter ID (default: "test-chapter")
    ///   - name: User name (default: "Test User {classYear}")
    /// - Returns: User instance
    static func createTestUser(
        id: String? = nil,
        classYear: Int,
        role: UserRole = .member,
        chapterId: String = "test-chapter",
        name: String? = nil
    ) -> User {
        let userId = id ?? "user-\(UUID().uuidString)"
        let userName = name ?? "Test User Year \(classYear)"

        return User(
            id: userId,
            name: userName,
            email: "test\(Int.random(in: 1000...9999))@ksu.edu",
            phoneNumber: "+1555\(String(format: "%07d", Int.random(in: 0...9999999)))",
            chapterId: chapterId,
            role: role,
            classYear: classYear,
            isEmailVerified: true,
            fcmToken: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Event

    /// Create a test event
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - chapterId: Chapter ID (default: "test-chapter")
    ///   - status: Event status (default: .active)
    ///   - allowedChapters: Allowed chapter IDs (default: ["ALL"])
    ///   - name: Event name (default: "Test Thursday Party")
    /// - Returns: Event instance
    static func createTestEvent(
        id: String? = nil,
        chapterId: String = "test-chapter",
        status: EventStatus = .active,
        allowedChapters: [String] = ["ALL"],
        name: String = "Test Thursday Party"
    ) -> Event {
        let eventId = id ?? "event-\(UUID().uuidString)"

        return Event(
            id: eventId,
            name: name,
            chapterId: chapterId,
            date: Date(),
            allowedChapterIds: allowedChapters,
            status: status,
            location: "Test Fraternity House",
            description: "Test event for unit testing",
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: "test-admin"
        )
    }

    // MARK: - DD Assignment

    /// Create a test DD assignment
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - userId: DD user ID
    ///   - eventId: Event ID
    ///   - isActive: Active status (default: true)
    ///   - totalRidesCompleted: Number of rides completed (default: 0)
    /// - Returns: DDAssignment instance
    static func createTestDDAssignment(
        id: String? = nil,
        userId: String,
        eventId: String,
        isActive: Bool = true,
        totalRidesCompleted: Int = 0
    ) -> DDAssignment {
        let assignmentId = id ?? "assignment-\(UUID().uuidString)"

        return DDAssignment(
            id: assignmentId,
            userId: userId,
            eventId: eventId,
            photoURL: "https://example.com/photo-\(userId).jpg",
            carDescription: "Black Honda Civic - ABC\(Int.random(in: 100...999))",
            isActive: isActive,
            inactiveToggles: 0,
            lastActiveTimestamp: isActive ? Date() : nil,
            lastInactiveTimestamp: isActive ? nil : Date(),
            totalRidesCompleted: totalRidesCompleted,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Ride

    /// Create a test ride
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - riderId: Rider user ID
    ///   - chapterId: Chapter ID (default: "test-chapter")
    ///   - eventId: Event ID
    ///   - classYear: Rider's class year (for priority calculation, default: 2)
    ///   - waitMinutes: Wait time in minutes (for priority calculation, default: 5.0)
    ///   - isEmergency: Emergency status (default: false)
    ///   - isSameChapter: Whether rider is from same chapter as event (default: true)
    ///   - status: Ride status (default: .queued)
    ///   - ddId: DD user ID (default: nil)
    /// - Returns: Ride instance
    static func createTestRide(
        id: String? = nil,
        riderId: String,
        chapterId: String = "test-chapter",
        eventId: String,
        classYear: Int = 2,
        waitMinutes: Double = 5.0,
        isEmergency: Bool = false,
        isSameChapter: Bool = true,
        status: RideStatus = .queued,
        ddId: String? = nil
    ) -> Ride {
        let rideId = id ?? "ride-\(UUID().uuidString)"

        // Calculate priority using the actual algorithm
        let priority = RideQueueService.shared.calculatePriority(
            classYear: classYear,
            waitMinutes: waitMinutes,
            isEmergency: isEmergency,
            isSameChapter: isSameChapter
        )

        // Calculate request time based on wait minutes
        let requestTime = Date().addingTimeInterval(-waitMinutes * 60)

        return Ride(
            id: rideId,
            riderId: riderId,
            ddId: ddId,
            chapterId: chapterId,
            eventId: eventId,
            pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717), // Manhattan, KS
            pickupAddress: "\(Int.random(in: 100...999)) Test St, Manhattan, KS 66502",
            dropoffAddress: nil,
            status: status,
            priority: priority,
            isEmergency: isEmergency,
            estimatedWaitTime: nil,
            queuePosition: nil,
            requestedAt: requestTime,
            assignedAt: status == .assigned || status == .enroute || status == .completed ? Date() : nil,
            enrouteAt: status == .enroute || status == .completed ? Date() : nil,
            completedAt: status == .completed ? Date() : nil,
            cancelledAt: status == .cancelled ? Date() : nil,
            cancellationReason: status == .cancelled ? "Test cancellation" : nil,
            notes: nil
        )
    }

    // MARK: - Admin Alert

    /// Create a test admin alert
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - chapterId: Chapter ID
    ///   - type: Alert type
    ///   - message: Alert message
    ///   - ddId: Optional DD user ID
    ///   - rideId: Optional ride ID
    /// - Returns: AdminAlert instance
    static func createTestAdminAlert(
        id: String? = nil,
        chapterId: String,
        type: AlertType,
        message: String,
        ddId: String? = nil,
        rideId: String? = nil
    ) -> AdminAlert {
        let alertId = id ?? "alert-\(UUID().uuidString)"

        return AdminAlert(
            id: alertId,
            chapterId: chapterId,
            type: type,
            message: message,
            ddId: ddId,
            rideId: rideId,
            isRead: false,
            createdAt: Date()
        )
    }

    // MARK: - Year Transition Log

    /// Create a test year transition log
    ///
    /// - Parameters:
    ///   - id: Optional custom ID (default: auto-generated)
    ///   - chapterId: Chapter ID
    ///   - status: Transition status
    ///   - seniorsRemoved: Number of seniors removed
    ///   - usersAdvanced: Number of users advanced
    /// - Returns: YearTransitionLog instance
    static func createTestYearTransitionLog(
        id: String? = nil,
        chapterId: String,
        status: TransitionStatus,
        seniorsRemoved: Int = 0,
        usersAdvanced: Int = 0
    ) -> YearTransitionLog {
        let logId = id ?? "log-\(UUID().uuidString)"

        return YearTransitionLog(
            id: logId,
            chapterId: chapterId,
            executionDate: Date(),
            status: status,
            seniorsRemoved: seniorsRemoved,
            usersAdvanced: usersAdvanced,
            errorMessage: status == .failed ? "Test error" : nil,
            createdAt: Date()
        )
    }

    // MARK: - Batch Creation Helpers

    /// Create multiple users at once with different class years
    ///
    /// - Parameters:
    ///   - chapterId: Chapter ID for all users
    ///   - classYears: Array of class years to create (default: [1,2,3,4])
    /// - Returns: Array of User instances
    static func createTestUsers(
        chapterId: String,
        classYears: [Int] = [1, 2, 3, 4]
    ) -> [User] {
        return classYears.map { classYear in
            createTestUser(classYear: classYear, chapterId: chapterId)
        }
    }

    /// Create multiple DD assignments at once
    ///
    /// - Parameters:
    ///   - userIds: Array of user IDs to create assignments for
    ///   - eventId: Event ID
    ///   - isActive: Active status (default: true)
    /// - Returns: Array of DDAssignment instances
    static func createTestDDAssignments(
        userIds: [String],
        eventId: String,
        isActive: Bool = true
    ) -> [DDAssignment] {
        return userIds.map { userId in
            createTestDDAssignment(userId: userId, eventId: eventId, isActive: isActive)
        }
    }

    /// Create multiple rides at once
    ///
    /// - Parameters:
    ///   - count: Number of rides to create
    ///   - eventId: Event ID
    ///   - chapterId: Chapter ID
    /// - Returns: Array of Ride instances
    static func createTestRides(
        count: Int,
        eventId: String,
        chapterId: String = "test-chapter"
    ) -> [Ride] {
        return (0..<count).map { index in
            let riderId = "rider-\(index)"
            let classYear = (index % 4) + 1 // Distribute across all class years
            return createTestRide(
                riderId: riderId,
                chapterId: chapterId,
                eventId: eventId,
                classYear: classYear
            )
        }
    }
}

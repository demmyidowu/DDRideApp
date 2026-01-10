//
//  YearTransitionServiceTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
@testable import DDRide

/// Unit tests for YearTransitionService
///
/// Tests the critical year transition process:
/// - Remove all seniors (classYear == 4)
/// - Increment classYear for all remaining users (1→2, 2→3, 3→4)
/// - Create audit logs
/// - Handle edge cases (no users, only seniors, etc.)
///
/// Business Logic:
/// - Scheduled: August 1st, midnight
/// - Remove all users with classYear == 4
/// - Increment everyone else's classYear by 1
/// - Admin receives notification to add new freshmen
final class YearTransitionServiceTests: DDRideTestCase {

    var service: YearTransitionService!
    var chapter: Chapter!

    override func setUp() async throws {
        try await super.setUp()
        service = YearTransitionService.shared

        // Create test chapter
        chapter = TestDataFactory.createTestChapter(id: "test-chapter")
        try await saveChapter(chapter)
    }

    // MARK: - Basic Transition Tests

    /// Test Case 1: Remove all seniors and advance others
    func testYearTransitionRemovesSeniorsAndAdvancesOthers() async throws {
        // Given: Create users of all class years
        let freshman = TestDataFactory.createTestUser(id: "freshman", classYear: 1, chapterId: chapter.id)
        let sophomore = TestDataFactory.createTestUser(id: "sophomore", classYear: 2, chapterId: chapter.id)
        let junior = TestDataFactory.createTestUser(id: "junior", classYear: 3, chapterId: chapter.id)
        let senior1 = TestDataFactory.createTestUser(id: "senior1", classYear: 4, chapterId: chapter.id)
        let senior2 = TestDataFactory.createTestUser(id: "senior2", classYear: 4, chapterId: chapter.id)

        try await saveUsers([freshman, sophomore, junior, senior1, senior2])

        // When: Execute transition
        let log = try await service.executeTransition(for: chapter)

        // Then: Verify seniors deleted
        let senior1After = try? await fetchUser(id: senior1.id)
        let senior2After = try? await fetchUser(id: senior2.id)
        XCTAssertNil(senior1After, "Senior 1 should be deleted")
        XCTAssertNil(senior2After, "Senior 2 should be deleted")

        // And: Verify others advanced
        let freshmanAfter = try await fetchUser(id: freshman.id)
        let sophomoreAfter = try await fetchUser(id: sophomore.id)
        let juniorAfter = try await fetchUser(id: junior.id)

        XCTAssertEqual(freshmanAfter.classYear, 2, "Freshman should advance to Sophomore")
        XCTAssertEqual(sophomoreAfter.classYear, 3, "Sophomore should advance to Junior")
        XCTAssertEqual(juniorAfter.classYear, 4, "Junior should advance to Senior")

        // And: Verify log is correct
        XCTAssertEqual(log.seniorsRemoved, 2, "Should remove 2 seniors")
        XCTAssertEqual(log.usersAdvanced, 3, "Should advance 3 users")
        XCTAssertEqual(log.status, .success, "Transition should succeed")
        XCTAssertNil(log.errorMessage, "Should have no error message")
    }

    /// Test Case 2: Handle chapter with no users
    func testYearTransitionWithNoUsers() async throws {
        // Given: Chapter with no users

        // When: Execute transition
        let log = try await service.executeTransition(for: chapter)

        // Then: Should succeed with 0 users affected
        XCTAssertEqual(log.seniorsRemoved, 0)
        XCTAssertEqual(log.usersAdvanced, 0)
        XCTAssertEqual(log.status, .success)
    }

    /// Test Case 3: Handle chapter with only seniors
    func testYearTransitionWithOnlySeniors() async throws {
        // Given: Chapter with only seniors
        let senior1 = TestDataFactory.createTestUser(id: "senior1", classYear: 4, chapterId: chapter.id)
        let senior2 = TestDataFactory.createTestUser(id: "senior2", classYear: 4, chapterId: chapter.id)
        let senior3 = TestDataFactory.createTestUser(id: "senior3", classYear: 4, chapterId: chapter.id)

        try await saveUsers([senior1, senior2, senior3])

        // When: Execute transition
        let log = try await service.executeTransition(for: chapter)

        // Then: All seniors should be deleted
        let senior1After = try? await fetchUser(id: senior1.id)
        let senior2After = try? await fetchUser(id: senior2.id)
        let senior3After = try? await fetchUser(id: senior3.id)

        XCTAssertNil(senior1After)
        XCTAssertNil(senior2After)
        XCTAssertNil(senior3After)

        // And: Log should reflect this
        XCTAssertEqual(log.seniorsRemoved, 3)
        XCTAssertEqual(log.usersAdvanced, 0)
        XCTAssertEqual(log.status, .success)
    }

    /// Test Case 4: Handle chapter with no seniors
    func testYearTransitionWithNoSeniors() async throws {
        // Given: Chapter with no seniors
        let freshman = TestDataFactory.createTestUser(id: "freshman", classYear: 1, chapterId: chapter.id)
        let sophomore = TestDataFactory.createTestUser(id: "sophomore", classYear: 2, chapterId: chapter.id)
        let junior = TestDataFactory.createTestUser(id: "junior", classYear: 3, chapterId: chapter.id)

        try await saveUsers([freshman, sophomore, junior])

        // When: Execute transition
        let log = try await service.executeTransition(for: chapter)

        // Then: All users should be advanced
        let freshmanAfter = try await fetchUser(id: freshman.id)
        let sophomoreAfter = try await fetchUser(id: sophomore.id)
        let juniorAfter = try await fetchUser(id: junior.id)

        XCTAssertEqual(freshmanAfter.classYear, 2)
        XCTAssertEqual(sophomoreAfter.classYear, 3)
        XCTAssertEqual(juniorAfter.classYear, 4)

        // And: Log should show 0 seniors removed
        XCTAssertEqual(log.seniorsRemoved, 0)
        XCTAssertEqual(log.usersAdvanced, 3)
        XCTAssertEqual(log.status, .success)
    }

    // MARK: - User Preservation Tests

    /// Test Case 5: Verify user data is preserved (except classYear)
    func testTransitionPreservesUserData() async throws {
        // Given: User with specific data
        var user = TestDataFactory.createTestUser(id: "test-user", classYear: 2, chapterId: chapter.id)
        user.name = "John Smith"
        user.email = "john.smith@ksu.edu"
        user.phoneNumber = "+15551234567"
        user.role = .admin

        try await saveUser(user)

        // When: Execute transition
        _ = try await service.executeTransition(for: chapter)

        // Then: User data should be preserved (except classYear)
        let userAfter = try await fetchUser(id: user.id)

        XCTAssertEqual(userAfter.classYear, 3, "Class year should advance")
        XCTAssertEqual(userAfter.name, user.name, "Name should be preserved")
        XCTAssertEqual(userAfter.email, user.email, "Email should be preserved")
        XCTAssertEqual(userAfter.phoneNumber, user.phoneNumber, "Phone should be preserved")
        XCTAssertEqual(userAfter.role, user.role, "Role should be preserved")
        XCTAssertEqual(userAfter.chapterId, user.chapterId, "Chapter should be preserved")
    }

    // MARK: - Multiple Chapter Tests

    /// Test Case 6: Only affect specified chapter's users
    func testTransitionOnlyAffectsSpecifiedChapter() async throws {
        // Given: Two chapters with users
        let chapter2 = TestDataFactory.createTestChapter(id: "chapter-2", name: "Other Chapter")
        try await saveChapter(chapter2)

        // Chapter 1 users
        let chapter1Senior = TestDataFactory.createTestUser(id: "c1-senior", classYear: 4, chapterId: chapter.id)
        let chapter1Junior = TestDataFactory.createTestUser(id: "c1-junior", classYear: 3, chapterId: chapter.id)

        // Chapter 2 users
        let chapter2Senior = TestDataFactory.createTestUser(id: "c2-senior", classYear: 4, chapterId: chapter2.id)
        let chapter2Junior = TestDataFactory.createTestUser(id: "c2-junior", classYear: 3, chapterId: chapter2.id)

        try await saveUsers([chapter1Senior, chapter1Junior, chapter2Senior, chapter2Junior])

        // When: Execute transition for chapter 1 only
        let log = try await service.executeTransition(for: chapter)

        // Then: Chapter 1 users should be affected
        let c1SeniorAfter = try? await fetchUser(id: chapter1Senior.id)
        let c1JuniorAfter = try await fetchUser(id: chapter1Junior.id)

        XCTAssertNil(c1SeniorAfter, "Chapter 1 senior should be deleted")
        XCTAssertEqual(c1JuniorAfter?.classYear, 4, "Chapter 1 junior should advance")

        // And: Chapter 2 users should NOT be affected
        let c2SeniorAfter = try await fetchUser(id: chapter2Senior.id)
        let c2JuniorAfter = try await fetchUser(id: chapter2Junior.id)

        XCTAssertEqual(c2SeniorAfter.classYear, 4, "Chapter 2 senior should NOT change")
        XCTAssertEqual(c2JuniorAfter.classYear, 3, "Chapter 2 junior should NOT change")

        // And: Log should only count chapter 1 users
        XCTAssertEqual(log.seniorsRemoved, 1)
        XCTAssertEqual(log.usersAdvanced, 1)
    }

    // MARK: - Large Scale Tests

    /// Test Case 7: Handle large number of users
    func testTransitionWithManyUsers() async throws {
        // Given: 100 users across all class years
        var users: [User] = []

        for i in 1...100 {
            let classYear = ((i - 1) % 4) + 1 // Distribute evenly: 1, 2, 3, 4
            let user = TestDataFactory.createTestUser(
                id: "user-\(i)",
                classYear: classYear,
                chapterId: chapter.id
            )
            users.append(user)
        }

        try await saveUsers(users)

        // When: Execute transition
        let log = try await service.executeTransition(for: chapter)

        // Then: Should process all users correctly
        let expectedSeniorsRemoved = 25 // 25% of 100
        let expectedUsersAdvanced = 75  // 75% of 100

        XCTAssertEqual(log.seniorsRemoved, expectedSeniorsRemoved)
        XCTAssertEqual(log.usersAdvanced, expectedUsersAdvanced)
        XCTAssertEqual(log.status, .success)

        // Verify total users after transition
        let usersAfter = try await fetchUsersForChapter(chapter.id)
        XCTAssertEqual(usersAfter.count, 75, "Should have 75 users remaining")

        // Verify no user has classYear < 2 or > 4
        for user in usersAfter {
            XCTAssertGreaterThanOrEqual(user.classYear, 2, "Minimum class year should be 2 after transition")
            XCTAssertLessThanOrEqual(user.classYear, 4, "Maximum class year should be 4")
        }
    }

    // MARK: - Audit Log Tests

    /// Test Case 8: Create audit log with correct data
    func testTransitionCreatesAuditLog() async throws {
        // Given: Chapter with users
        let senior = TestDataFactory.createTestUser(id: "senior", classYear: 4, chapterId: chapter.id)
        let junior = TestDataFactory.createTestUser(id: "junior", classYear: 3, chapterId: chapter.id)

        try await saveUsers([senior, junior])

        // When: Execute transition
        let log = try await service.executeTransition(for: chapter)

        // Then: Log should be created with correct values
        XCTAssertEqual(log.chapterId, chapter.id)
        XCTAssertEqual(log.seniorsRemoved, 1)
        XCTAssertEqual(log.usersAdvanced, 1)
        XCTAssertEqual(log.status, .success)
        XCTAssertNotNil(log.executionDate)
        XCTAssertNil(log.errorMessage)

        // And: Log should be saved to Firestore
        let savedLog = try await FirestoreService.shared.fetch(
            YearTransitionLog.self,
            id: log.id,
            from: "yearTransitionLogs"
        )

        XCTAssertEqual(savedLog.id, log.id)
        XCTAssertEqual(savedLog.chapterId, chapter.id)
        XCTAssertEqual(savedLog.seniorsRemoved, 1)
        XCTAssertEqual(savedLog.usersAdvanced, 1)
    }

    // MARK: - Role Preservation Tests

    /// Test Case 9: Admins remain admins after transition
    func testAdminsRemainAdminsAfterTransition() async throws {
        // Given: Admin users of different class years
        let adminFreshman = TestDataFactory.createTestUser(
            id: "admin-freshman",
            classYear: 1,
            role: .admin,
            chapterId: chapter.id
        )
        let adminSenior = TestDataFactory.createTestUser(
            id: "admin-senior",
            classYear: 4,
            role: .admin,
            chapterId: chapter.id
        )

        try await saveUsers([adminFreshman, adminSenior])

        // When: Execute transition
        _ = try await service.executeTransition(for: chapter)

        // Then: Admin freshman should still be admin (and advanced)
        let adminFreshmanAfter = try await fetchUser(id: adminFreshman.id)
        XCTAssertEqual(adminFreshmanAfter.classYear, 2)
        XCTAssertEqual(adminFreshmanAfter.role, .admin, "Admin role should be preserved")

        // And: Admin senior should be deleted
        let adminSeniorAfter = try? await fetchUser(id: adminSenior.id)
        XCTAssertNil(adminSeniorAfter, "Senior admin should also be deleted")
    }

    // MARK: - Edge Cases

    /// Test Case 10: Verify timestamps are updated
    func testTransitionUpdatesTimestamps() async throws {
        // Given: User with old timestamp
        var user = TestDataFactory.createTestUser(id: "test-user", classYear: 2, chapterId: chapter.id)
        let oldTimestamp = Date().addingTimeInterval(-3600) // 1 hour ago
        user.updatedAt = oldTimestamp

        try await saveUser(user)

        // When: Execute transition
        _ = try await service.executeTransition(for: chapter)

        // Wait a moment for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        // Then: updatedAt should be more recent
        let userAfter = try await fetchUser(id: user.id)
        XCTAssertGreaterThan(userAfter.updatedAt, oldTimestamp, "updatedAt should be refreshed")
    }
}

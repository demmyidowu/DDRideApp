//
//  AdminTransitionTests.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
import FirebaseFirestore
@testable import DDRide

/// Integration tests for admin role transition workflow
///
/// Tests the complete admin transition flow:
/// 1. Atomic role transfer between users
/// 2. Validation of transition eligibility
/// 3. Transaction rollback on failures
/// 4. Audit trail logging
/// 5. Multiple transitions in sequence
///
/// This tests integration between:
/// - AdminTransitionService
/// - User model
/// - AdminTransitionLog model
/// - Firestore transactions
final class AdminTransitionTests: DDRideTestCase {

    var transitionService: AdminTransitionService!

    var chapter: Chapter!
    var currentAdmin: User!
    var newAdmin: User!
    var regularMember: User!

    override func setUp() async throws {
        try await super.setUp()

        transitionService = AdminTransitionService.shared

        // Create test data
        chapter = TestDataFactory.createTestChapter(id: "test-chapter")
        try await saveChapter(chapter)

        currentAdmin = TestDataFactory.createTestUser(
            id: "current-admin",
            classYear: 4,
            role: .admin,
            chapterId: chapter.id
        )
        try await saveUser(currentAdmin)

        newAdmin = TestDataFactory.createTestUser(
            id: "new-admin",
            classYear: 3,
            role: .member,
            chapterId: chapter.id
        )
        try await saveUser(newAdmin)

        regularMember = TestDataFactory.createTestUser(
            id: "regular-member",
            classYear: 2,
            role: .member,
            chapterId: chapter.id
        )
        try await saveUser(regularMember)
    }

    // MARK: - Role Transfer Tests

    /// Test Case 1: Successful role transfer
    func testSuccessfulRoleTransfer() async throws {
        // ARRANGE
        // Verify initial states
        XCTAssertEqual(currentAdmin.role, .admin)
        XCTAssertEqual(newAdmin.role, .member)

        // ACT
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ASSERT - Roles should be swapped
        let updatedOldAdmin = try await fetchUser(id: currentAdmin.id)
        let updatedNewAdmin = try await fetchUser(id: newAdmin.id)

        XCTAssertEqual(updatedOldAdmin.role, .member, "Old admin should become member")
        XCTAssertEqual(updatedNewAdmin.role, .admin, "New admin should become admin")

        // Verify both users still belong to same chapter
        XCTAssertEqual(updatedOldAdmin.chapterId, chapter.id)
        XCTAssertEqual(updatedNewAdmin.chapterId, chapter.id)
    }

    /// Test Case 2: Transition creates audit log
    func testTransitionCreatesLog() async throws {
        // ARRANGE
        // No logs initially
        let initialLogs = try await fetchAdminTransitionLogs(chapterId: chapter.id)
        let initialCount = initialLogs.count

        // ACT
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ASSERT - Log should be created
        let logs = try await fetchAdminTransitionLogs(chapterId: chapter.id)

        XCTAssertEqual(logs.count, initialCount + 1, "Transition log should be created")

        let log = logs.first
        XCTAssertNotNil(log)
        XCTAssertEqual(log?.fromUserId, currentAdmin.id)
        XCTAssertEqual(log?.fromUserName, currentAdmin.name)
        XCTAssertEqual(log?.toUserId, newAdmin.id)
        XCTAssertEqual(log?.toUserName, newAdmin.name)
        XCTAssertEqual(log?.chapterId, chapter.id)
        XCTAssertNotNil(log?.timestamp)
        XCTAssertNotNil(log?.performedBy)
    }

    /// Test Case 3: Transaction atomicity - both users updated or neither
    func testAtomicityOfTransition() async throws {
        // ARRANGE
        let initialOldAdminRole = currentAdmin.role
        let initialNewAdminRole = newAdmin.role

        // ACT
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ASSERT - Both changes should be applied or neither
        let updatedOldAdmin = try await fetchUser(id: currentAdmin.id)
        let updatedNewAdmin = try await fetchUser(id: newAdmin.id)

        // If transaction was atomic, both should have changed
        let oldAdminChanged = updatedOldAdmin.role != initialOldAdminRole
        let newAdminChanged = updatedNewAdmin.role != initialNewAdminRole

        XCTAssertTrue(
            (oldAdminChanged && newAdminChanged) || (!oldAdminChanged && !newAdminChanged),
            "Transaction should be atomic - both succeed or both fail"
        )

        // In this test, both should succeed
        XCTAssertTrue(oldAdminChanged && newAdminChanged)
        XCTAssertEqual(updatedOldAdmin.role, .member)
        XCTAssertEqual(updatedNewAdmin.role, .admin)
    }

    /// Test Case 4: Cannot transfer to user in different chapter
    func testCannotTransferToUserInDifferentChapter() async throws {
        // ARRANGE
        let otherChapter = TestDataFactory.createTestChapter(id: "other-chapter", name: "Other Chapter")
        try await saveChapter(otherChapter)

        let userInOtherChapter = TestDataFactory.createTestUser(
            id: "other-user",
            classYear: 3,
            role: .member,
            chapterId: otherChapter.id
        )
        try await saveUser(userInOtherChapter)

        // ACT & ASSERT - Should throw error
        do {
            try await transitionService.transferAdminRole(
                from: currentAdmin.id,
                to: userInOtherChapter.id,
                in: chapter.id
            )
            XCTFail("Should not allow transfer to user in different chapter")
        } catch AdminTransitionError.notInChapter {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify no changes were made
        let unchangedAdmin = try await fetchUser(id: currentAdmin.id)
        XCTAssertEqual(unchangedAdmin.role, .admin, "Admin role should not change on failed transfer")
    }

    /// Test Case 5: Cannot transfer from non-admin
    func testCannotTransferFromNonAdmin() async throws {
        // ARRANGE - Regular member tries to transfer admin role
        // ACT & ASSERT - Should throw error
        do {
            try await transitionService.transferAdminRole(
                from: regularMember.id,
                to: newAdmin.id,
                in: chapter.id
            )
            XCTFail("Should not allow transfer from non-admin")
        } catch AdminTransitionError.notCurrentAdmin {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify roles unchanged
        let unchangedMember = try await fetchUser(id: regularMember.id)
        let unchangedNewAdmin = try await fetchUser(id: newAdmin.id)
        XCTAssertEqual(unchangedMember.role, .member)
        XCTAssertEqual(unchangedNewAdmin.role, .member)
    }

    /// Test Case 6: Cannot transfer to nonexistent user
    func testCannotTransferToNonexistentUser() async throws {
        // ARRANGE
        let fakeUserId = "nonexistent-user-123"

        // ACT & ASSERT
        do {
            try await transitionService.transferAdminRole(
                from: currentAdmin.id,
                to: fakeUserId,
                in: chapter.id
            )
            XCTFail("Should not allow transfer to nonexistent user")
        } catch AdminTransitionError.userNotFound {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify admin unchanged
        let unchangedAdmin = try await fetchUser(id: currentAdmin.id)
        XCTAssertEqual(unchangedAdmin.role, .admin)
    }

    /// Test Case 7: Cannot transfer to same user
    func testCannotTransferToSameUser() async throws {
        // ACT & ASSERT
        do {
            try await transitionService.transferAdminRole(
                from: currentAdmin.id,
                to: currentAdmin.id,
                in: chapter.id
            )
            XCTFail("Should not allow transfer to same user")
        } catch AdminTransitionError.sameUser {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Test Case 8: Validation before transaction
    func testValidationBeforeTransaction() async throws {
        // ACT
        let (oldAdmin, newAdminUser) = try await transitionService.validateTransition(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ASSERT
        XCTAssertEqual(oldAdmin.id, currentAdmin.id)
        XCTAssertEqual(oldAdmin.role, .admin)
        XCTAssertEqual(oldAdmin.chapterId, chapter.id)

        XCTAssertEqual(newAdminUser.id, newAdmin.id)
        XCTAssertEqual(newAdminUser.chapterId, chapter.id)
    }

    /// Test Case 9: Multiple transitions in sequence
    func testMultipleTransitionsInSequence() async throws {
        // ARRANGE
        let admin2 = TestDataFactory.createTestUser(
            id: "admin-2",
            classYear: 3,
            role: .member,
            chapterId: chapter.id
        )
        try await saveUser(admin2)

        let admin3 = TestDataFactory.createTestUser(
            id: "admin-3",
            classYear: 2,
            role: .member,
            chapterId: chapter.id
        )
        try await saveUser(admin3)

        // ACT - Chain of transitions
        // currentAdmin → newAdmin
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // newAdmin → admin2
        try await transitionService.transferAdminRole(
            from: newAdmin.id,
            to: admin2.id,
            in: chapter.id
        )

        // admin2 → admin3
        try await transitionService.transferAdminRole(
            from: admin2.id,
            to: admin3.id,
            in: chapter.id
        )

        // ASSERT - Final state
        let finalAdmin = try await fetchUser(id: admin3.id)
        XCTAssertEqual(finalAdmin.role, .admin, "Final user should be admin")

        // All others should be members
        let user1 = try await fetchUser(id: currentAdmin.id)
        let user2 = try await fetchUser(id: newAdmin.id)
        let user3 = try await fetchUser(id: admin2.id)

        XCTAssertEqual(user1.role, .member)
        XCTAssertEqual(user2.role, .member)
        XCTAssertEqual(user3.role, .member)

        // Should have 3 logs
        let logs = try await fetchAdminTransitionLogs(chapterId: chapter.id)
        XCTAssertEqual(logs.count, 3, "Should have 3 transition logs")

        // Verify log order (most recent first)
        XCTAssertEqual(logs[0].toUserId, admin3.id, "Most recent log should be to admin3")
        XCTAssertEqual(logs[1].toUserId, admin2.id)
        XCTAssertEqual(logs[2].toUserId, newAdmin.id)
    }

    /// Test Case 10: Fetch transition history
    func testFetchTransitionHistory() async throws {
        // ARRANGE - Create multiple transitions
        let member1 = TestDataFactory.createTestUser(id: "member-1", classYear: 3, role: .member, chapterId: chapter.id)
        let member2 = TestDataFactory.createTestUser(id: "member-2", classYear: 2, role: .member, chapterId: chapter.id)
        try await saveUser(member1)
        try await saveUser(member2)

        try await transitionService.transferAdminRole(from: currentAdmin.id, to: member1.id, in: chapter.id)

        // Small delay to ensure different timestamps
        try await Task.sleep(nanoseconds: 100_000_000)

        try await transitionService.transferAdminRole(from: member1.id, to: member2.id, in: chapter.id)

        // ACT
        let history = try await transitionService.fetchTransitionHistory(chapterId: chapter.id)

        // ASSERT
        XCTAssertGreaterThanOrEqual(history.count, 2, "Should have at least 2 transitions")

        // Verify sorted by timestamp descending (most recent first)
        if history.count >= 2 {
            XCTAssertGreaterThanOrEqual(history[0].timestamp, history[1].timestamp)
        }
    }

    /// Test Case 11: Get latest transition
    func testGetLatestTransition() async throws {
        // ARRANGE
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ACT
        let latestTransition = try await transitionService.getLatestTransition(chapterId: chapter.id)

        // ASSERT
        XCTAssertNotNil(latestTransition)
        XCTAssertEqual(latestTransition?.fromUserId, currentAdmin.id)
        XCTAssertEqual(latestTransition?.toUserId, newAdmin.id)
    }

    /// Test Case 12: Get current admins for chapter
    func testGetCurrentAdmins() async throws {
        // ACT - Before transition
        let adminsBefore = try await transitionService.getCurrentAdmins(chapterId: chapter.id)

        // ASSERT
        XCTAssertEqual(adminsBefore.count, 1, "Should have 1 admin")
        XCTAssertEqual(adminsBefore.first?.id, currentAdmin.id)

        // ACT - After transition
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        let adminsAfter = try await transitionService.getCurrentAdmins(chapterId: chapter.id)

        // ASSERT
        XCTAssertEqual(adminsAfter.count, 1, "Should still have 1 admin")
        XCTAssertEqual(adminsAfter.first?.id, newAdmin.id, "Should be the new admin")
    }

    /// Test Case 13: Transition preserves other user data
    func testTransitionPreservesOtherUserData() async throws {
        // ARRANGE - Note original data
        let originalOldAdminEmail = currentAdmin.email
        let originalOldAdminName = currentAdmin.name
        let originalNewAdminEmail = newAdmin.email
        let originalNewAdminName = newAdmin.name

        // ACT
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ASSERT - Only role should change, other data preserved
        let updatedOldAdmin = try await fetchUser(id: currentAdmin.id)
        let updatedNewAdmin = try await fetchUser(id: newAdmin.id)

        XCTAssertEqual(updatedOldAdmin.email, originalOldAdminEmail)
        XCTAssertEqual(updatedOldAdmin.name, originalOldAdminName)
        XCTAssertEqual(updatedNewAdmin.email, originalNewAdminEmail)
        XCTAssertEqual(updatedNewAdmin.name, originalNewAdminName)
    }

    /// Test Case 14: No transition log when validation fails
    func testNoLogWhenValidationFails() async throws {
        // ARRANGE
        let initialLogCount = try await fetchAdminTransitionLogs(chapterId: chapter.id).count

        // ACT - Try invalid transition
        do {
            try await transitionService.transferAdminRole(
                from: regularMember.id, // Not admin
                to: newAdmin.id,
                in: chapter.id
            )
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // ASSERT - No new log created
        let finalLogCount = try await fetchAdminTransitionLogs(chapterId: chapter.id).count
        XCTAssertEqual(finalLogCount, initialLogCount, "No log should be created on failed transition")
    }

    /// Test Case 15: Transition log includes all required fields
    func testTransitionLogCompleteness() async throws {
        // ACT
        try await transitionService.transferAdminRole(
            from: currentAdmin.id,
            to: newAdmin.id,
            in: chapter.id
        )

        // ASSERT
        let logs = try await fetchAdminTransitionLogs(chapterId: chapter.id)
        guard let log = logs.first else {
            XCTFail("Log should exist")
            return
        }

        // Verify all fields are populated
        XCTAssertFalse(log.id.isEmpty, "Log ID should not be empty")
        XCTAssertEqual(log.chapterId, chapter.id)
        XCTAssertEqual(log.fromUserId, currentAdmin.id)
        XCTAssertEqual(log.fromUserName, currentAdmin.name)
        XCTAssertEqual(log.toUserId, newAdmin.id)
        XCTAssertEqual(log.toUserName, newAdmin.name)
        XCTAssertFalse(log.performedBy.isEmpty, "PerformedBy should not be empty")
        XCTAssertNotNil(log.timestamp)

        // Timestamp should be recent (within last minute)
        let timeSinceTransition = Date().timeIntervalSince(log.timestamp)
        XCTAssertLessThan(timeSinceTransition, 60, "Timestamp should be within last minute")
    }
}

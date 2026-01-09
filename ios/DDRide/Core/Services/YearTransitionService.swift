//
//  YearTransitionService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import Combine

/// Service for managing annual year transitions
///
/// This service handles the critical year transition process:
/// - Remove all seniors (classYear == 4)
/// - Increment classYear for all remaining users
/// - Create transition logs for audit trail
/// - Handle errors gracefully with partial success tracking
///
/// Scheduled to run on August 1st at midnight (handled by Cloud Scheduler on backend)
/// Can also be triggered manually by admins
///
/// Example Usage:
/// ```swift
/// let service = YearTransitionService.shared
///
/// // Check if chapter is eligible for transition
/// let eligible = try await service.validateTransitionEligibility(for: chapter)
///
/// // Execute transition
/// let log = try await service.executeTransition(for: chapter)
/// print("Removed \(log.seniorsRemoved) seniors, advanced \(log.usersAdvanced) users")
/// ```
@MainActor
class YearTransitionService: ObservableObject {
    static let shared = YearTransitionService()

    private let firestoreService = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()

    // Constants
    private let seniorClassYear = 4
    private let batchSize = 500 // Firestore batch limit

    private init() {}

    // MARK: - Validation

    /// Validate if a chapter is eligible for year transition
    ///
    /// Checks:
    /// 1. Current date is past August 1st of current year
    /// 2. Transition hasn't been run already this year
    ///
    /// - Parameter chapter: The chapter to validate
    /// - Returns: True if eligible, false otherwise
    func validateTransitionEligibility(for chapter: Chapter) async throws -> Bool {
        let calendar = Calendar.current
        let currentDate = Date()

        // Check if we're past the transition date
        let components = calendar.dateComponents([.year], from: currentDate)
        guard let currentYear = components.year else {
            return false
        }

        // Get transition date for current year
        let transitionComponents = calendar.dateComponents([.month, .day], from: chapter.yearTransitionDate)
        guard let transitionMonth = transitionComponents.month,
              let transitionDay = transitionComponents.day else {
            return false
        }

        var thisYearTransitionComponents = DateComponents()
        thisYearTransitionComponents.year = currentYear
        thisYearTransitionComponents.month = transitionMonth
        thisYearTransitionComponents.day = transitionDay

        guard let thisYearTransitionDate = calendar.date(from: thisYearTransitionComponents) else {
            return false
        }

        // Check if current date is past transition date
        guard currentDate >= thisYearTransitionDate else {
            return false
        }

        // Check if transition has already been run this year
        let logs = try await firestoreService.fetchYearTransitionLogs(chapterId: chapter.id)

        // Check if any successful transition occurred after this year's transition date
        let hasTransitionedThisYear = logs.contains { log in
            log.status == .success &&
            log.executionDate >= thisYearTransitionDate
        }

        return !hasTransitionedThisYear
    }

    /// Get the next transition date for a chapter
    ///
    /// - Parameter chapter: The chapter
    /// - Returns: Next transition date
    func getNextTransitionDate(for chapter: Chapter) -> Date {
        let calendar = Calendar.current
        let currentDate = Date()

        let components = calendar.dateComponents([.year], from: currentDate)
        guard let currentYear = components.year else {
            return chapter.yearTransitionDate
        }

        // Get transition date for current year
        let transitionComponents = calendar.dateComponents([.month, .day], from: chapter.yearTransitionDate)
        guard let transitionMonth = transitionComponents.month,
              let transitionDay = transitionComponents.day else {
            return chapter.yearTransitionDate
        }

        var thisYearComponents = DateComponents()
        thisYearComponents.year = currentYear
        thisYearComponents.month = transitionMonth
        thisYearComponents.day = transitionDay

        guard let thisYearDate = calendar.date(from: thisYearComponents) else {
            return chapter.yearTransitionDate
        }

        // If we're past this year's date, return next year's date
        if currentDate >= thisYearDate {
            var nextYearComponents = DateComponents()
            nextYearComponents.year = currentYear + 1
            nextYearComponents.month = transitionMonth
            nextYearComponents.day = transitionDay

            return calendar.date(from: nextYearComponents) ?? thisYearDate
        }

        return thisYearDate
    }

    // MARK: - Execute Transition

    /// Execute year transition for a chapter
    ///
    /// Process:
    /// 1. Fetch all users for the chapter
    /// 2. Filter seniors (classYear == 4)
    /// 3. Remove all senior users (batch delete)
    /// 4. Increment classYear for all remaining users (batch update)
    /// 5. Create YearTransitionLog with counts
    /// 6. Handle errors gracefully (use TransitionStatus.partial if some operations fail)
    ///
    /// - Parameter chapter: The chapter to transition
    /// - Returns: YearTransitionLog with results
    /// - Throws: FirestoreError if operation fails
    func executeTransition(for chapter: Chapter) async throws -> YearTransitionLog {
        let startTime = Date()
        var seniorsRemoved = 0
        var usersAdvanced = 0
        var errors: [String] = []

        do {
            // Fetch all users for the chapter
            let allUsers = try await firestoreService.fetchMembers(chapterId: chapter.id)

            // Separate seniors from others
            let seniors = allUsers.filter { $0.classYear == seniorClassYear }
            let remainingUsers = allUsers.filter { $0.classYear < seniorClassYear }

            // STEP 1: Delete seniors
            if !seniors.isEmpty {
                let deleteResult = try await deleteSeniors(seniors)
                seniorsRemoved = deleteResult.successCount
                if let error = deleteResult.error {
                    errors.append("Senior deletion: \(error)")
                }
            }

            // STEP 2: Advance remaining users
            if !remainingUsers.isEmpty {
                let advanceResult = try await advanceUsers(remainingUsers)
                usersAdvanced = advanceResult.successCount
                if let error = advanceResult.error {
                    errors.append("User advancement: \(error)")
                }
            }

            // Determine status
            let status: TransitionStatus
            if errors.isEmpty {
                status = .success
            } else if seniorsRemoved > 0 || usersAdvanced > 0 {
                status = .partial
            } else {
                status = .failed
            }

            // Create log
            let log = YearTransitionLog(
                id: UUID().uuidString,
                chapterId: chapter.id,
                executionDate: startTime,
                seniorsRemoved: seniorsRemoved,
                usersAdvanced: usersAdvanced,
                status: status,
                errorMessage: errors.isEmpty ? nil : errors.joined(separator: "; "),
                createdAt: Date()
            )

            // Save log
            try await firestoreService.createYearTransitionLog(log)

            return log

        } catch {
            // Create failed log
            let log = YearTransitionLog(
                id: UUID().uuidString,
                chapterId: chapter.id,
                executionDate: startTime,
                seniorsRemoved: seniorsRemoved,
                usersAdvanced: usersAdvanced,
                status: .failed,
                errorMessage: error.localizedDescription,
                createdAt: Date()
            )

            // Try to save log (best effort)
            try? await firestoreService.createYearTransitionLog(log)

            throw error
        }
    }

    // MARK: - Helper Methods

    /// Delete senior users in batches
    ///
    /// - Parameter seniors: Array of senior users to delete
    /// - Returns: BatchResult with success count and errors
    private func deleteSeniors(_ seniors: [User]) async throws -> BatchResult {
        var successCount = 0
        var lastError: String?

        // Split into batches of 500 (Firestore limit)
        let batches = seniors.chunked(into: batchSize)

        for batch in batches {
            do {
                // Create batch operations
                let operations = batch.map { user in
                    BatchOperation.delete(collection: "users", id: user.id)
                }

                // Execute batch
                try await firestoreService.executeBatch(operations)
                successCount += batch.count

            } catch {
                lastError = error.localizedDescription
                // Continue with next batch instead of failing completely
            }
        }

        return BatchResult(
            successCount: successCount,
            error: lastError
        )
    }

    /// Advance users to next class year in batches
    ///
    /// - Parameter users: Array of users to advance
    /// - Returns: BatchResult with success count and errors
    private func advanceUsers(_ users: [User]) async throws -> BatchResult {
        var successCount = 0
        var lastError: String?

        // Split into batches of 500 (Firestore limit)
        let batches = users.chunked(into: batchSize)

        for batch in batches {
            do {
                // Create batch operations
                let operations = batch.map { user in
                    BatchOperation.update(
                        collection: "users",
                        id: user.id,
                        data: [
                            "classYear": user.classYear + 1,
                            "updatedAt": Date()
                        ]
                    )
                }

                // Execute batch
                try await firestoreService.executeBatch(operations)
                successCount += batch.count

            } catch {
                lastError = error.localizedDescription
                // Continue with next batch instead of failing completely
            }
        }

        return BatchResult(
            successCount: successCount,
            error: lastError
        )
    }

    // MARK: - Preview/Dry Run

    /// Preview what would happen during transition (dry run)
    ///
    /// This doesn't make any changes, just returns what would be affected
    ///
    /// - Parameter chapter: The chapter to preview
    /// - Returns: TransitionPreview with counts
    func previewTransition(for chapter: Chapter) async throws -> TransitionPreview {
        let allUsers = try await firestoreService.fetchMembers(chapterId: chapter.id)

        let seniors = allUsers.filter { $0.classYear == seniorClassYear }
        let remainingUsers = allUsers.filter { $0.classYear < seniorClassYear }

        // Group remaining users by class year
        var usersByYear: [Int: [User]] = [:]
        for user in remainingUsers {
            usersByYear[user.classYear, default: []].append(user)
        }

        return TransitionPreview(
            seniorsToRemove: seniors.count,
            seniorNames: seniors.map { $0.name },
            freshmenToAdvance: usersByYear[1]?.count ?? 0,
            sophomoresToAdvance: usersByYear[2]?.count ?? 0,
            juniorsToAdvance: usersByYear[3]?.count ?? 0,
            totalToAdvance: remainingUsers.count
        )
    }

    // MARK: - Rollback (Emergency)

    /// Rollback a transition (emergency use only)
    ///
    /// WARNING: This cannot restore deleted seniors!
    /// It only reverts the classYear increments
    ///
    /// - Parameter log: The transition log to rollback
    func rollbackTransition(log: YearTransitionLog) async throws {
        // Fetch all users for the chapter
        let allUsers = try await firestoreService.fetchMembers(chapterId: log.chapterId)

        // Filter users who would have been advanced (classYear 2-4)
        let usersToRevert = allUsers.filter { $0.classYear >= 2 && $0.classYear <= 4 }

        // Revert in batches
        let batches = usersToRevert.chunked(into: batchSize)

        for batch in batches {
            let operations = batch.map { user in
                BatchOperation.update(
                    collection: "users",
                    id: user.id,
                    data: [
                        "classYear": user.classYear - 1,
                        "updatedAt": Date()
                    ]
                )
            }

            try await firestoreService.executeBatch(operations)
        }

        // Create rollback log
        let rollbackLog = YearTransitionLog(
            id: UUID().uuidString,
            chapterId: log.chapterId,
            executionDate: Date(),
            seniorsRemoved: 0,
            usersAdvanced: -usersToRevert.count,
            status: .success,
            errorMessage: "Rollback of transition from \(log.executionDate)",
            createdAt: Date()
        )

        try await firestoreService.createYearTransitionLog(rollbackLog)
    }
}

// MARK: - Supporting Types

/// Result of a batch operation
private struct BatchResult {
    let successCount: Int
    let error: String?
}

/// Preview of what would happen during transition
struct TransitionPreview {
    let seniorsToRemove: Int
    let seniorNames: [String]
    let freshmenToAdvance: Int
    let sophomoresToAdvance: Int
    let juniorsToAdvance: Int
    let totalToAdvance: Int

    var summary: String {
        """
        Year Transition Preview:
        - Seniors to remove: \(seniorsToRemove)
        - Freshmen → Sophomores: \(freshmenToAdvance)
        - Sophomores → Juniors: \(sophomoresToAdvance)
        - Juniors → Seniors: \(juniorsToAdvance)
        - Total users to advance: \(totalToAdvance)
        """
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

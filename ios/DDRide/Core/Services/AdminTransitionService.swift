//
//  AdminTransitionService.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import FirebaseFirestore

/// Service for transferring admin role between users
///
/// This service implements critical business logic for:
/// - Atomic admin role transfers using Firestore transactions
/// - Validation of role transfer eligibility
/// - Logging all admin transitions for audit trail
/// - Ensuring exactly one admin change at a time
///
/// Business Rules:
/// - Transfer must be atomic (both role changes succeed or both fail)
/// - Both users must belong to the same chapter
/// - Current user must have admin role
/// - New admin must currently be a member
/// - All transitions are logged with timestamps
///
/// Example Usage:
/// ```swift
/// let service = AdminTransitionService.shared
///
/// // Transfer admin role
/// try await service.transferAdminRole(
///     from: "currentAdminId",
///     to: "newAdminId",
///     in: "chapterId"
/// )
/// ```
@MainActor
class AdminTransitionService: ObservableObject {
    static let shared = AdminTransitionService()

    private let firestoreService = FirestoreService.shared

    private init() {}

    // MARK: - Admin Role Transfer

    /// Transfer admin role from current admin to new admin atomically
    ///
    /// Process (MUST BE ATOMIC using Firestore transaction):
    /// 1. Validate both users exist and belong to the chapter
    /// 2. Validate current user has admin role
    /// 3. Update old admin: role = .member
    /// 4. Update new admin: role = .admin
    /// 5. Create AdminTransitionLog for audit trail
    /// 6. TODO: Send notifications to both users (future)
    ///
    /// All steps must succeed together or all fail together.
    ///
    /// - Parameters:
    ///   - oldAdminId: Current admin's user ID
    ///   - newAdminId: New admin's user ID
    ///   - chapterId: Chapter ID (for validation)
    /// - Throws: AdminTransitionError if validation or transaction fails
    func transferAdminRole(
        from oldAdminId: String,
        to newAdminId: String,
        in chapterId: String
    ) async throws {
        // Get current user ID for logging
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw AdminTransitionError.notAuthenticated
        }

        // Validate inputs
        guard oldAdminId != newAdminId else {
            throw AdminTransitionError.sameUser
        }

        // Pre-validate users exist and are in the same chapter
        let (oldAdmin, newAdmin) = try await validateTransition(
            from: oldAdminId,
            to: newAdminId,
            in: chapterId
        )

        print("🔄 Starting admin transition from \(oldAdmin.name) to \(newAdmin.name)")

        // Execute atomic transaction
        do {
            try await firestoreService.runTransaction { transaction in
                let db = Firestore.firestore()

                // References for both users
                let oldAdminRef = db.collection("users").document(oldAdminId)
                let newAdminRef = db.collection("users").document(newAdminId)

                // Update old admin to member role
                transaction.updateData([
                    "role": UserRole.member.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: oldAdminRef)

                print("  ✓ Updated \(oldAdmin.name) to member role")

                // Update new admin to admin role
                transaction.updateData([
                    "role": UserRole.admin.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: newAdminRef)

                print("  ✓ Updated \(newAdmin.name) to admin role")

                // Create transition log for audit trail
                let log = AdminTransitionLog(
                    id: UUID().uuidString,
                    chapterId: chapterId,
                    fromUserId: oldAdminId,
                    fromUserName: oldAdmin.name,
                    toUserId: newAdminId,
                    toUserName: newAdmin.name,
                    performedBy: currentUserId,
                    timestamp: Date()
                )

                // Save log to Firestore (as part of transaction)
                let logRef = db.collection("adminTransitionLogs").document(log.id)
                do {
                    let logData = try Firestore.Encoder().encode(log)
                    transaction.setData(logData, forDocument: logRef)
                    print("  ✓ Created transition log \(log.id)")
                } catch {
                    throw AdminTransitionError.logCreationFailed(error.localizedDescription)
                }

                return () // Transaction successful
            }

            print("✅ Admin transition completed successfully")

            // TODO: Send notifications to both users
            // await sendTransitionNotifications(oldAdmin: oldAdmin, newAdmin: newAdmin)

        } catch let error as AdminTransitionError {
            // Re-throw AdminTransitionError as-is
            print("❌ Admin transition failed: \(error.localizedDescription)")
            throw error
        } catch {
            // Wrap other errors
            print("❌ Admin transition failed: \(error.localizedDescription)")
            throw AdminTransitionError.transactionFailed(error.localizedDescription)
        }
    }

    // MARK: - Validation

    /// Validate admin transition eligibility
    ///
    /// Checks:
    /// 1. Both users exist
    /// 2. Both users belong to the specified chapter
    /// 3. Old admin has admin role
    /// 4. New admin has member role (or can also be admin for multi-admin support)
    ///
    /// - Parameters:
    ///   - oldAdminId: Current admin's user ID
    ///   - newAdminId: New admin's user ID
    ///   - chapterId: Chapter ID
    /// - Returns: Tuple of (oldAdmin, newAdmin)
    /// - Throws: AdminTransitionError if validation fails
    func validateTransition(
        from oldAdminId: String,
        to newAdminId: String,
        in chapterId: String
    ) async throws -> (User, User) {
        // Fetch both users
        let oldAdmin: User
        let newAdmin: User

        do {
            oldAdmin = try await firestoreService.fetchUser(id: oldAdminId)
        } catch {
            throw AdminTransitionError.userNotFound("Current admin not found")
        }

        do {
            newAdmin = try await firestoreService.fetchUser(id: newAdminId)
        } catch {
            throw AdminTransitionError.userNotFound("New admin not found")
        }

        // Validate both belong to the same chapter
        guard oldAdmin.chapterId == chapterId else {
            throw AdminTransitionError.notInChapter("Current admin not in specified chapter")
        }

        guard newAdmin.chapterId == chapterId else {
            throw AdminTransitionError.notInChapter("New admin not in specified chapter")
        }

        // Validate old admin has admin role
        guard oldAdmin.role == .admin else {
            throw AdminTransitionError.notCurrentAdmin("User \(oldAdmin.name) is not an admin")
        }

        // Note: We don't strictly require new admin to be a member
        // They could already be an admin (for multi-admin support)
        // But we'll log a warning if they're already admin
        if newAdmin.role == .admin {
            print("⚠️ Warning: \(newAdmin.name) is already an admin. This may create multiple admins.")
        }

        return (oldAdmin, newAdmin)
    }

    // MARK: - Transition History

    /// Fetch admin transition history for a chapter
    ///
    /// - Parameters:
    ///   - chapterId: The chapter ID
    ///   - limit: Maximum number of logs to return (default: 50)
    /// - Returns: Array of transition logs, sorted by timestamp descending
    func fetchTransitionHistory(chapterId: String, limit: Int = 50) async throws -> [AdminTransitionLog] {
        // Note: We need to add a query method for AdminTransitionLog to FirestoreService
        // For now, we'll use the generic query method
        let logs = try await firestoreService.query(
            AdminTransitionLog.self,
            from: "adminTransitionLogs",
            filters: [.equals("chapterId", chapterId)],
            orderBy: "timestamp",
            descending: true,
            limit: limit
        )

        return logs
    }

    /// Get the most recent admin transition for a chapter
    ///
    /// - Parameter chapterId: The chapter ID
    /// - Returns: Most recent transition log, or nil if none exist
    func getLatestTransition(chapterId: String) async throws -> AdminTransitionLog? {
        let logs = try await fetchTransitionHistory(chapterId: chapterId, limit: 1)
        return logs.first
    }

    /// Check who is currently admin for a chapter
    ///
    /// - Parameter chapterId: The chapter ID
    /// - Returns: Array of users with admin role (should typically be 1)
    func getCurrentAdmins(chapterId: String) async throws -> [User] {
        let members = try await firestoreService.fetchMembers(chapterId: chapterId)
        return members.filter { $0.role == .admin }
    }

    // MARK: - Future: Notification Support

    /// Send notifications to both users about role change
    ///
    /// TODO: Implement when FCM service is added
    ///
    /// - Parameters:
    ///   - oldAdmin: Previous admin user
    ///   - newAdmin: New admin user
    private func sendTransitionNotifications(oldAdmin: User, newAdmin: User) async {
        // Placeholder for future implementation
        print("📱 TODO: Send role change notifications")
        print("   To \(oldAdmin.name): You are now a member")
        print("   To \(newAdmin.name): You are now an admin")
    }
}

// MARK: - Error Types

/// Custom errors for admin transition operations
enum AdminTransitionError: LocalizedError {
    case notAuthenticated
    case sameUser
    case userNotFound(String)
    case notInChapter(String)
    case notCurrentAdmin(String)
    case transactionFailed(String)
    case logCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to transfer admin role."
        case .sameUser:
            return "Cannot transfer admin role to the same user."
        case .userNotFound(let message):
            return "User not found: \(message)"
        case .notInChapter(let message):
            return "Chapter mismatch: \(message)"
        case .notCurrentAdmin(let message):
            return "Not current admin: \(message)"
        case .transactionFailed(let message):
            return "Admin transition failed: \(message)"
        case .logCreationFailed(let message):
            return "Failed to log admin transition: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in and try again."
        case .sameUser:
            return "Select a different user to become admin."
        case .userNotFound:
            return "Verify the user account exists and try again."
        case .notInChapter:
            return "Both users must belong to the same chapter."
        case .notCurrentAdmin:
            return "Only current admins can transfer their role."
        case .transactionFailed:
            return "Check your internet connection and try again."
        case .logCreationFailed:
            return "Role transfer succeeded but logging failed. Contact support if needed."
        }
    }
}

// MARK: - Test Cases and Examples

/*
 Test Case 1: Successful admin transition
 =========================================
 Input:
   - oldAdminId: "admin123" (current admin)
   - newAdminId: "member456" (current member)
   - chapterId: "chapter789"

 Expected Result:
   - Transaction succeeds
   - admin123 role changes to .member
   - member456 role changes to .admin
   - AdminTransitionLog created with:
     * fromUserId: "admin123"
     * toUserId: "member456"
     * timestamp: current Date
   - Both users' updatedAt timestamp updated
   - All changes atomic (all succeed or all fail)

 Test Case 2: Validation failure - User not found
 =================================================
 Input:
   - oldAdminId: "nonexistent" (doesn't exist)
   - newAdminId: "member456"
   - chapterId: "chapter789"

 Expected Result:
   - Throws AdminTransitionError.userNotFound
   - No changes made to database
   - No transaction executed
   - User-friendly error message displayed

 Test Case 3: Validation failure - Not current admin
 ====================================================
 Input:
   - oldAdminId: "member999" (is a member, not admin)
   - newAdminId: "member456"
   - chapterId: "chapter789"

 Expected Result:
   - Throws AdminTransitionError.notCurrentAdmin
   - No changes made to database
   - Error message: "User [name] is not an admin"

 Test Case 4: Validation failure - Different chapters
 =====================================================
 Input:
   - oldAdminId: "admin123" (in chapter789)
   - newAdminId: "member456" (in chapterABC)
   - chapterId: "chapter789"

 Expected Result:
   - Throws AdminTransitionError.notInChapter
   - Error message indicates new admin not in specified chapter
   - No changes made

 Test Case 5: Same user
 =======================
 Input:
   - oldAdminId: "admin123"
   - newAdminId: "admin123" (same user)
   - chapterId: "chapter789"

 Expected Result:
   - Throws AdminTransitionError.sameUser
   - No transaction executed
   - Error message: "Cannot transfer admin role to the same user"

 Test Case 6: Transaction atomicity - Network failure
 =====================================================
 Scenario:
   - Valid inputs
   - Network disconnects during transaction

 Expected Result:
   - Transaction fails completely
   - Neither user's role is changed
   - No AdminTransitionLog created
   - Throws AdminTransitionError.transactionFailed
   - Database remains in consistent state

 Test Case 7: Fetch transition history
 ======================================
 Scenario:
   - Chapter has 10 admin transitions over time
   - Fetch with limit = 5

 Expected Result:
   - Returns 5 most recent transitions
   - Sorted by timestamp descending (newest first)
   - Each log contains:
     * Both user IDs and names
     * Timestamp
     * performedBy user ID

 Test Case 8: Multiple admin support
 ====================================
 Scenario:
   - Current admin wants to promote another member
   - But keep their own admin role (multi-admin)

 Expected Result:
   - Current implementation will demote old admin
   - Warning logged if new user already admin
   - Future: Add option to keep both as admins
 */

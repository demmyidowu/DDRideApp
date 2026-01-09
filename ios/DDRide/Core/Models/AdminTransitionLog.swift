//
//  AdminTransitionLog.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation

/// Log entry for admin role transitions
///
/// This model tracks all admin role transfers for audit trail purposes.
/// Each time admin role is transferred from one user to another,
/// a log entry is created with details about both users and who performed the action.
///
/// Stored in Firestore collection: `adminTransitionLogs`
///
/// Example:
/// ```swift
/// let log = AdminTransitionLog(
///     id: UUID().uuidString,
///     chapterId: "chapter123",
///     fromUserId: "user456",
///     fromUserName: "John Smith",
///     toUserId: "user789",
///     toUserName: "Jane Doe",
///     performedBy: "user456",
///     timestamp: Date()
/// )
/// ```
struct AdminTransitionLog: Codable, Identifiable {
    /// Unique identifier for the log entry
    let id: String

    /// Chapter where the transition occurred
    let chapterId: String

    /// User ID of the previous admin (who lost admin role)
    let fromUserId: String

    /// Name of the previous admin (stored for historical reference)
    let fromUserName: String

    /// User ID of the new admin (who gained admin role)
    let toUserId: String

    /// Name of the new admin (stored for historical reference)
    let toUserName: String

    /// User ID of who performed the action (typically same as fromUserId, but could be different if super admin)
    let performedBy: String

    /// When the transition occurred
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case chapterId
        case fromUserId
        case fromUserName
        case toUserId
        case toUserName
        case performedBy
        case timestamp
    }
}

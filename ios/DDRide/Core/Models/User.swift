//
//  User.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var email: String // Must be @ksu.edu
    var phoneNumber: String // E.164 format: +15551234567
    var chapterId: String
    var role: UserRole
    var classYear: Int // 4=senior, 3=junior, 2=sophomore, 1=freshman
    var isEmailVerified: Bool
    var fcmToken: String? // Firebase Cloud Messaging token for push notifications
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phoneNumber
        case chapterId
        case role
        case classYear
        case isEmailVerified
        case fcmToken
        case createdAt
        case updatedAt
    }

    // Validate KSU email domain
    var isKSUEmail: Bool {
        email.lowercased().hasSuffix("@ksu.edu")
    }
}

enum UserRole: String, Codable, CaseIterable {
    case admin = "admin"
    case member = "member"

    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .member: return "Member"
        }
    }
}

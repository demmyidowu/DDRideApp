//
//  User.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
    var phoneNumber: String
    var chapterId: String
    var role: UserRole
    var classYear: Int
    var isEmailVerified: Bool
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
        case createdAt
        case updatedAt
    }
}

enum UserRole: String, Codable, CaseIterable {
    case admin = "admin"
    case dd = "dd"
    case rider = "rider"

    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .dd: return "Designated Driver"
        case .rider: return "Rider"
        }
    }
}

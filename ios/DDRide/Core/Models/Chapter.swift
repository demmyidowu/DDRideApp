//
//  Chapter.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct Chapter: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var universityId: String // e.g., "ksu" for Kansas State University
    var inviteCode: String // Unique code for members to join
    var yearTransitionDate: String // "MM-DD" format, e.g., "08-01" for August 1st
    var greekLetters: String?
    var organization: ChapterOrganization
    var phoneNumber: String?
    var address: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case universityId
        case inviteCode
        case yearTransitionDate
        case greekLetters
        case organization
        case phoneNumber
        case address
        case isActive
        case createdAt
        case updatedAt
    }
}

enum ChapterOrganization: String, Codable, CaseIterable {
    case fraternity = "fraternity"
    case sorority = "sorority"

    var displayName: String {
        switch self {
        case .fraternity: return "Fraternity"
        case .sorority: return "Sorority"
        }
    }
}

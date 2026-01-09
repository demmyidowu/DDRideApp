//
//  Chapter.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct Chapter: Codable, Identifiable, Equatable {
    let id: String
    var name: String // e.g., "Sigma Chi"
    var universityId: String // e.g., "ksu" for Kansas State University
    var inviteCode: String // Unique code for members to join
    var yearTransitionDate: Date // Default August 1st, annually triggers senior removal
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case universityId
        case inviteCode
        case yearTransitionDate
        case createdAt
        case updatedAt
    }
}

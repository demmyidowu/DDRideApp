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
    var greekLetters: String?
    var organization: ChapterOrganization
    var phoneNumber: String?
    var address: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
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

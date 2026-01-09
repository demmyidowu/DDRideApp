//
//  Event.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct Event: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var chapterId: String
    var date: Date
    var allowedChapterIds: [String] // ["ALL"] or specific chapter IDs for cross-chapter events
    var status: EventStatus
    var location: String?
    var description: String?
    var createdAt: Date
    var createdBy: String // User ID

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case chapterId
        case date
        case allowedChapterIds
        case status
        case location
        case description
        case createdAt
        case createdBy
    }
}

enum EventStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}

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
    var startTime: Date
    var endTime: Date
    var location: String?
    var description: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String // User ID
}

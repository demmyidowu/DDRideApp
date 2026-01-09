//
//  YearTransitionLog.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct YearTransitionLog: Codable, Identifiable, Equatable {
    let id: String
    var chapterId: String
    var executionDate: Date
    var seniorsRemoved: Int // Count of seniors (classYear == 4) removed
    var usersAdvanced: Int // Count of users whose classYear was incremented
    var status: TransitionStatus
    var errorMessage: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case chapterId
        case executionDate
        case seniorsRemoved
        case usersAdvanced
        case status
        case errorMessage
        case createdAt
    }
}

enum TransitionStatus: String, Codable, CaseIterable {
    case success = "success"
    case failed = "failed"
    case partial = "partial" // Some users transitioned, but errors occurred

    var displayName: String {
        switch self {
        case .success: return "Success"
        case .failed: return "Failed"
        case .partial: return "Partial"
        }
    }
}

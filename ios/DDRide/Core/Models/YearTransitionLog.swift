//
//  YearTransitionLog.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

struct YearTransitionLog: Codable, Identifiable, Equatable {
    let id: String
    var executionDate: Date
    var seniorsRemoved: Int
    var usersAdvanced: Int
    var status: TransitionStatus
    var errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case executionDate
        case seniorsRemoved
        case usersAdvanced
        case status
        case errorMessage
    }
}

enum TransitionStatus: String, Codable, CaseIterable {
    case success = "success"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .success: return "Success"
        case .failed: return "Failed"
        }
    }
}

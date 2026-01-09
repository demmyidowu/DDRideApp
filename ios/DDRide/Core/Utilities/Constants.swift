//
//  Constants.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

enum Constants {
    // MARK: - App
    static let appName = "DD Ride"
    static let bundleId = "com.ddride.app"

    // MARK: - Firestore Collections
    enum Collections {
        static let users = "users"
        static let chapters = "chapters"
        static let events = "events"
        static let rides = "rides"
        static let ddAssignments = "ddAssignments"
    }

    // MARK: - Priority Algorithm
    enum Priority {
        static let classYearMultiplier: Double = 10.0
        static let waitTimeMultiplier: Double = 0.5
        static let emergencyPriority: Double = 9999.0
    }

    // MARK: - Validation
    enum Validation {
        static let emailDomain = "@ksu.edu"
        static let minPasswordLength = 8
        static let phoneNumberRegex = "^\\+?[1-9]\\d{1,14}$"
    }

    // MARK: - Monitoring
    enum Monitoring {
        static let maxInactiveToggles = 5
        static let inactiveToggleWindow: TimeInterval = 30 * 60 // 30 minutes
        static let inactivityAlertThreshold: TimeInterval = 15 * 60 // 15 minutes
    }

    // MARK: - Time
    enum Time {
        static let rideTimeout: TimeInterval = 60 * 60 // 1 hour
        static let locationTimeout: TimeInterval = 10 // 10 seconds
    }

    // MARK: - UI
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let animationDuration: Double = 0.3
    }
}

//
//  Helpers.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation

// MARK: - Priority Calculator

struct PriorityCalculator {
    static func calculate(classYear: Int, waitTime: TimeInterval, isEmergency: Bool) -> Double {
        if isEmergency {
            return Constants.Priority.emergencyPriority
        }

        let waitMinutes = waitTime / 60.0
        let classYearScore = Double(classYear) * Constants.Priority.classYearMultiplier
        let waitTimeScore = waitMinutes * Constants.Priority.waitTimeMultiplier

        return classYearScore + waitTimeScore
    }
}

// MARK: - DD Assignment Selector

struct DDAssignmentSelector {
    static func selectDD(
        assignments: [DDAssignment],
        activeRides: [Ride],
        estimatedRideDuration: TimeInterval = 15 * 60 // 15 minutes default
    ) -> DDAssignment? {
        guard !assignments.isEmpty else { return nil }

        var ddWaitTimes: [(assignment: DDAssignment, waitTime: TimeInterval)] = []

        for assignment in assignments where assignment.isActive {
            // Get rides assigned to this DD that are pending or in progress
            let ddRides = activeRides.filter { ride in
                ride.ddId == assignment.ddId &&
                (ride.status == .pending || ride.status == .assigned || ride.status == .enroute)
            }

            // Calculate wait time (estimated time until DD is available)
            let waitTime = Double(ddRides.count) * estimatedRideDuration
            ddWaitTimes.append((assignment: assignment, waitTime: waitTime))
        }

        // Sort by wait time (ascending) and return the DD with shortest wait
        return ddWaitTimes.min(by: { $0.waitTime < $1.waitTime })?.assignment
    }
}

// MARK: - Queue Position Calculator

struct QueuePositionCalculator {
    static func calculatePosition(for ride: Ride, in rides: [Ride]) -> Int {
        let sortedRides = rides
            .filter { $0.status == .pending || $0.status == .assigned }
            .sorted { $0.priority > $1.priority }

        return (sortedRides.firstIndex(where: { $0.id == ride.id }) ?? 0) + 1
    }
}

// MARK: - Validation Helpers

struct ValidationHelpers {
    static func validateEmail(_ email: String) -> ValidationResult {
        guard !email.isEmpty else {
            return .failure("Email is required")
        }

        guard email.isValidEmail else {
            return .failure("Invalid email format")
        }

        guard email.isValidKSUEmail else {
            return .failure("Must use a @ksu.edu email address")
        }

        return .success
    }

    static func validatePassword(_ password: String) -> ValidationResult {
        guard !password.isEmpty else {
            return .failure("Password is required")
        }

        guard password.count >= Constants.Validation.minPasswordLength else {
            return .failure("Password must be at least \(Constants.Validation.minPasswordLength) characters")
        }

        return .success
    }

    static func validatePhoneNumber(_ phoneNumber: String) -> ValidationResult {
        guard !phoneNumber.isEmpty else {
            return .failure("Phone number is required")
        }

        guard phoneNumber.isValidPhoneNumber else {
            return .failure("Invalid phone number format")
        }

        return .success
    }

    static func validateClassYear(_ classYear: Int) -> ValidationResult {
        guard classYear >= 1 && classYear <= 4 else {
            return .failure("Class year must be between 1 and 4")
        }

        return .success
    }
}

enum ValidationResult {
    case success
    case failure(String)

    var isValid: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Date Helpers

struct DateHelpers {
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    static func startOfDay(_ date: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date = Date()) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(date)) ?? date
    }
}

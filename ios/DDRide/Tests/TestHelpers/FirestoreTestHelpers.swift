//
//  FirestoreTestHelpers.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import Foundation
import FirebaseFirestore
@testable import DDRide

/// Helper functions for Firestore operations in tests
///
/// Provides convenience methods to save and fetch test data
/// without needing to call FirestoreService directly
extension DDRideTestCase {

    // MARK: - Save Methods

    /// Save a chapter to Firestore
    func saveChapter(_ chapter: Chapter) async throws {
        try await FirestoreService.shared.save(chapter, to: "chapters")
    }

    /// Save a user to Firestore
    func saveUser(_ user: User) async throws {
        try await FirestoreService.shared.save(user, to: "users")
    }

    /// Save multiple users to Firestore
    func saveUsers(_ users: [User]) async throws {
        for user in users {
            try await saveUser(user)
        }
    }

    /// Save an event to Firestore
    func saveEvent(_ event: Event) async throws {
        try await FirestoreService.shared.save(event, to: "events")
    }

    /// Save a DD assignment to Firestore
    func saveDDAssignment(_ assignment: DDAssignment) async throws {
        try await FirestoreService.shared.save(assignment, to: "ddAssignments")
    }

    /// Save multiple DD assignments to Firestore
    func saveDDAssignments(_ assignments: [DDAssignment]) async throws {
        for assignment in assignments {
            try await saveDDAssignment(assignment)
        }
    }

    /// Save a ride to Firestore
    func saveRide(_ ride: Ride) async throws {
        try await FirestoreService.shared.save(ride, to: "rides")
    }

    /// Save multiple rides to Firestore
    func saveRides(_ rides: [Ride]) async throws {
        for ride in rides {
            try await saveRide(ride)
        }
    }

    /// Save an admin alert to Firestore
    func saveAdminAlert(_ alert: AdminAlert) async throws {
        try await FirestoreService.shared.save(alert, to: "adminAlerts")
    }

    /// Save a year transition log to Firestore
    func saveYearTransitionLog(_ log: YearTransitionLog) async throws {
        try await FirestoreService.shared.save(log, to: "yearTransitionLogs")
    }

    /// Save an admin transition log to Firestore
    func saveAdminTransitionLog(_ log: AdminTransitionLog) async throws {
        try await FirestoreService.shared.save(log, to: "adminTransitionLogs")
    }

    // MARK: - Fetch Methods

    /// Fetch a chapter from Firestore
    func fetchChapter(id: String) async throws -> Chapter {
        return try await FirestoreService.shared.fetch(Chapter.self, id: id, from: "chapters")
    }

    /// Fetch a user from Firestore
    func fetchUser(id: String) async throws -> User {
        return try await FirestoreService.shared.fetch(User.self, id: id, from: "users")
    }

    /// Fetch an event from Firestore
    func fetchEvent(id: String) async throws -> Event {
        return try await FirestoreService.shared.fetch(Event.self, id: id, from: "events")
    }

    /// Fetch a ride from Firestore
    func fetchRide(id: String) async throws -> Ride {
        return try await FirestoreService.shared.fetch(Ride.self, id: id, from: "rides")
    }

    /// Fetch a DD assignment from Firestore
    func fetchDDAssignment(id: String) async throws -> DDAssignment {
        return try await FirestoreService.shared.fetch(DDAssignment.self, id: id, from: "ddAssignments")
    }

    /// Fetch all admin alerts for a chapter
    func fetchAdminAlerts(chapterId: String, type: AlertType? = nil) async throws -> [AdminAlert] {
        let db = Firestore.firestore()
        var query: Query = db.collection("adminAlerts")
            .whereField("chapterId", isEqualTo: chapterId)

        if let type = type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { try $0.data(as: AdminAlert.self) }
    }

    /// Fetch all admin transition logs for a chapter
    func fetchAdminTransitionLogs(chapterId: String) async throws -> [AdminTransitionLog] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("adminTransitionLogs")
            .whereField("chapterId", isEqualTo: chapterId)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: AdminTransitionLog.self) }
    }

    /// Fetch all users for a chapter
    func fetchUsersForChapter(_ chapterId: String) async throws -> [User] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users")
            .whereField("chapterId", isEqualTo: chapterId)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: User.self) }
    }

    /// Fetch all rides for an event
    func fetchRidesForEvent(_ eventId: String) async throws -> [Ride] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("rides")
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Ride.self) }
    }

    /// Fetch all DD assignments for an event
    func fetchDDAssignmentsForEvent(_ eventId: String) async throws -> [DDAssignment] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("ddAssignments")
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: DDAssignment.self) }
    }

    // MARK: - Delete Methods

    /// Delete a document from a collection
    func deleteDocument(id: String, from collection: String) async throws {
        try await Firestore.firestore()
            .collection(collection)
            .document(id)
            .delete()
    }

    // MARK: - Query Methods

    /// Count documents in a collection with optional filter
    func countDocuments(in collection: String, whereField field: String? = nil, isEqualTo value: Any? = nil) async throws -> Int {
        let db = Firestore.firestore()
        var query: Query = db.collection(collection)

        if let field = field, let value = value {
            query = query.whereField(field, isEqualTo: value)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.count
    }
}

//
//  FirestoreService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Users

    func fetchUser(id: String) async throws -> User {
        let document = try await db.collection("users").document(id).getDocument()
        return try document.data(as: User.self)
    }

    func fetchMembers(chapterId: String) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .whereField("chapterId", isEqualTo: chapterId)
            .order(by: "name")
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: User.self) }
    }

    func updateUser(_ user: User) async throws {
        var updatedUser = user
        updatedUser.updatedAt = Date()
        try db.collection("users").document(user.id).setData(from: updatedUser)
    }

    func deleteUser(id: String) async throws {
        try await db.collection("users").document(id).delete()
    }

    // MARK: - Chapters

    func fetchChapter(id: String) async throws -> Chapter {
        let document = try await db.collection("chapters").document(id).getDocument()
        return try document.data(as: Chapter.self)
    }

    func fetchChapters() async throws -> [Chapter] {
        let snapshot = try await db.collection("chapters")
            .order(by: "name")
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Chapter.self) }
    }

    func createChapter(_ chapter: Chapter) async throws {
        try db.collection("chapters").document(chapter.id).setData(from: chapter)
    }

    func updateChapter(_ chapter: Chapter) async throws {
        var updatedChapter = chapter
        updatedChapter.updatedAt = Date()
        try db.collection("chapters").document(chapter.id).setData(from: updatedChapter)
    }

    // MARK: - Events

    func fetchEvent(id: String) async throws -> Event {
        let document = try await db.collection("events").document(id).getDocument()
        return try document.data(as: Event.self)
    }

    func fetchEvents(chapterId: String) async throws -> [Event] {
        let snapshot = try await db.collection("events")
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "date", descending: true)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Event.self) }
    }

    func createEvent(_ event: Event) async throws {
        try db.collection("events").document(event.id).setData(from: event)
    }

    func updateEvent(_ event: Event) async throws {
        var updatedEvent = event
        updatedEvent.updatedAt = Date()
        try db.collection("events").document(event.id).setData(from: updatedEvent)
    }

    func deleteEvent(id: String) async throws {
        try await db.collection("events").document(id).delete()
    }

    // MARK: - Rides

    func fetchRide(id: String) async throws -> Ride {
        let document = try await db.collection("rides").document(id).getDocument()
        return try document.data(as: Ride.self)
    }

    func fetchActiveRides(chapterId: String) async throws -> [Ride] {
        let snapshot = try await db.collection("rides")
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("status", in: ["pending", "assigned", "enroute"])
            .order(by: "priority", descending: true)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Ride.self) }
    }

    func fetchRiderRides(riderId: String) async throws -> [Ride] {
        let snapshot = try await db.collection("rides")
            .whereField("riderId", isEqualTo: riderId)
            .order(by: "requestedAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Ride.self) }
    }

    func fetchDDRides(ddId: String) async throws -> [Ride] {
        let snapshot = try await db.collection("rides")
            .whereField("ddId", isEqualTo: ddId)
            .order(by: "requestedAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Ride.self) }
    }

    func createRide(_ ride: Ride) async throws {
        try db.collection("rides").document(ride.id).setData(from: ride)
    }

    func updateRide(_ ride: Ride) async throws {
        try db.collection("rides").document(ride.id).setData(from: ride, merge: true)
    }

    // MARK: - DD Assignments

    func fetchDDAssignment(id: String) async throws -> DDAssignment {
        let document = try await db.collection("ddAssignments").document(id).getDocument()
        return try document.data(as: DDAssignment.self)
    }

    func fetchActiveDDAssignments(eventId: String) async throws -> [DDAssignment] {
        let snapshot = try await db.collection("ddAssignments")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: DDAssignment.self) }
    }

    func createDDAssignment(_ assignment: DDAssignment) async throws {
        try db.collection("ddAssignments").document(assignment.id).setData(from: assignment)
    }

    func updateDDAssignment(_ assignment: DDAssignment) async throws {
        var updatedAssignment = assignment
        updatedAssignment.updatedAt = Date()
        try db.collection("ddAssignments").document(assignment.id).setData(from: updatedAssignment)
    }

    // MARK: - Real-time Listeners

    func listenToActiveRides(chapterId: String, completion: @escaping ([Ride]) -> Void) -> ListenerRegistration {
        return db.collection("rides")
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("status", in: ["pending", "assigned", "enroute"])
            .order(by: "priority", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let rides = documents.compactMap { try? $0.data(as: Ride.self) }
                completion(rides)
            }
    }
}

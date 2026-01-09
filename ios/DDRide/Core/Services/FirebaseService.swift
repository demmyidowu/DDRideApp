//
//  FirebaseService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Singleton service for Firebase configuration and management
@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    private let db: Firestore
    private let auth: Auth

    private init() {
        // Firebase should already be configured in AppDelegate
        self.db = Firestore.firestore()
        self.auth = Auth.auth()

        // Configure emulators for debug builds
        #if DEBUG
        configureEmulators()
        #endif

        // Configure Firestore settings
        configureFirestoreSettings()
    }

    // MARK: - Configuration

    private func configureEmulators() {
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        // Configure Auth emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        print("🔧 Firebase Emulators configured (Firestore: localhost:8080, Auth: localhost:9099)")
    }

    private func configureFirestoreSettings() {
        let settings = db.settings
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings

        print("✅ Firebase initialized successfully")
    }

    // MARK: - Helper Properties

    var firestore: Firestore {
        return db
    }

    var authentication: Auth {
        return auth
    }

    // MARK: - Common Operations

    /// Generate a new document ID
    func generateDocumentId(for collection: String) -> String {
        return db.collection(collection).document().documentID
    }

    /// Batch write helper
    func batch() -> WriteBatch {
        return db.batch()
    }

    /// Transaction helper
    func runTransaction<T>(_ updateBlock: @escaping (Transaction) throws -> T) async throws -> T {
        return try await db.runTransaction({ (transaction, errorPointer) -> T? in
            do {
                return try updateBlock(transaction)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        })
    }

    // MARK: - Collection References

    func usersCollection() -> CollectionReference {
        return db.collection("users")
    }

    func chaptersCollection() -> CollectionReference {
        return db.collection("chapters")
    }

    func eventsCollection() -> CollectionReference {
        return db.collection("events")
    }

    func ridesCollection() -> CollectionReference {
        return db.collection("rides")
    }

    func adminAlertsCollection() -> CollectionReference {
        return db.collection("adminAlerts")
    }

    func yearTransitionLogsCollection() -> CollectionReference {
        return db.collection("yearTransitionLogs")
    }

    func ddAssignmentsCollection(eventId: String) -> CollectionReference {
        return db.collection("events").document(eventId).collection("ddAssignments")
    }

    // MARK: - Users

    func createUser(_ user: User) async throws {
        try usersCollection().document(user.id).setData(from: user)
    }

    func fetchUser(id: String) async throws -> User {
        let document = try await usersCollection().document(id).getDocument()
        guard let user = try? document.data(as: User.self) else {
            throw FirebaseError.userNotFound
        }
        return user
    }

    func updateUser(_ user: User) async throws {
        var updatedUser = user
        updatedUser.updatedAt = Date()
        try usersCollection().document(user.id).setData(from: updatedUser, merge: true)
    }

    func deleteUser(id: String) async throws {
        try await usersCollection().document(id).delete()
    }

    func fetchChapterMembers(chapterId: String) async throws -> [User] {
        let snapshot = try await usersCollection()
            .whereField("chapterId", isEqualTo: chapterId)
            .order(by: "name")
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: User.self) }
    }

    // MARK: - Chapters

    func createChapter(_ chapter: Chapter) async throws {
        try chaptersCollection().document(chapter.id).setData(from: chapter)
    }

    func fetchChapter(id: String) async throws -> Chapter {
        let document = try await chaptersCollection().document(id).getDocument()
        guard let chapter = try? document.data(as: Chapter.self) else {
            throw FirebaseError.chapterNotFound
        }
        return chapter
    }

    func fetchChapters() async throws -> [Chapter] {
        let snapshot = try await chaptersCollection()
            .whereField("isActive", isEqualTo: true)
            .order(by: "name")
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Chapter.self) }
    }

    func updateChapter(_ chapter: Chapter) async throws {
        var updatedChapter = chapter
        updatedChapter.updatedAt = Date()
        try chaptersCollection().document(chapter.id).setData(from: updatedChapter, merge: true)
    }

    // MARK: - Events

    func createEvent(_ event: Event) async throws {
        try eventsCollection().document(event.id).setData(from: event)
    }

    func fetchEvent(id: String) async throws -> Event {
        let document = try await eventsCollection().document(id).getDocument()
        guard let event = try? document.data(as: Event.self) else {
            throw FirebaseError.eventNotFound
        }
        return event
    }

    func fetchActiveEvents(chapterId: String) async throws -> [Event] {
        let snapshot = try await eventsCollection()
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("status", isEqualTo: EventStatus.active.rawValue)
            .order(by: "date", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Event.self) }
    }

    func updateEvent(_ event: Event) async throws {
        try eventsCollection().document(event.id).setData(from: event, merge: true)
    }

    func deleteEvent(id: String) async throws {
        try await eventsCollection().document(id).delete()
    }

    // MARK: - DD Assignments

    func createDDAssignment(_ assignment: DDAssignment, eventId: String) async throws {
        try ddAssignmentsCollection(eventId: eventId)
            .document(assignment.id)
            .setData(from: assignment)
    }

    func fetchDDAssignment(id: String, eventId: String) async throws -> DDAssignment {
        let document = try await ddAssignmentsCollection(eventId: eventId)
            .document(id)
            .getDocument()

        guard let assignment = try? document.data(as: DDAssignment.self) else {
            throw FirebaseError.assignmentNotFound
        }
        return assignment
    }

    func fetchActiveDDAssignments(eventId: String) async throws -> [DDAssignment] {
        let snapshot = try await ddAssignmentsCollection(eventId: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: DDAssignment.self) }
    }

    func updateDDAssignment(_ assignment: DDAssignment, eventId: String) async throws {
        var updatedAssignment = assignment
        updatedAssignment.updatedAt = Date()
        try ddAssignmentsCollection(eventId: eventId)
            .document(assignment.id)
            .setData(from: updatedAssignment, merge: true)
    }

    // MARK: - Rides

    func createRide(_ ride: Ride) async throws {
        try ridesCollection().document(ride.id).setData(from: ride)
    }

    func fetchRide(id: String) async throws -> Ride {
        let document = try await ridesCollection().document(id).getDocument()
        guard let ride = try? document.data(as: Ride.self) else {
            throw FirebaseError.rideNotFound
        }
        return ride
    }

    /// Fetch queued and assigned rides for an event, sorted by priority
    func fetchActiveRides(eventId: String) async throws -> [Ride] {
        let snapshot = try await ridesCollection()
            .whereField("eventId", isEqualTo: eventId)
            .whereField("status", in: [
                RideStatus.queued.rawValue,
                RideStatus.assigned.rawValue,
                RideStatus.enroute.rawValue
            ])
            .order(by: "priority", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Ride.self) }
    }

    func fetchRiderRides(riderId: String, limit: Int = 50) async throws -> [Ride] {
        let snapshot = try await ridesCollection()
            .whereField("riderId", isEqualTo: riderId)
            .order(by: "requestTime", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Ride.self) }
    }

    func fetchDDRides(ddId: String, eventId: String) async throws -> [Ride] {
        let snapshot = try await ridesCollection()
            .whereField("eventId", isEqualTo: eventId)
            .whereField("ddId", isEqualTo: ddId)
            .whereField("status", in: [
                RideStatus.assigned.rawValue,
                RideStatus.enroute.rawValue
            ])
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Ride.self) }
    }

    func updateRide(_ ride: Ride) async throws {
        try ridesCollection().document(ride.id).setData(from: ride, merge: true)
    }

    // MARK: - Admin Alerts

    func createAdminAlert(_ alert: AdminAlert) async throws {
        try adminAlertsCollection().document(alert.id).setData(from: alert)
    }

    func fetchUnreadAlerts(chapterId: String) async throws -> [AdminAlert] {
        let snapshot = try await adminAlertsCollection()
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: AdminAlert.self) }
    }

    func markAlertAsRead(alertId: String) async throws {
        try await adminAlertsCollection()
            .document(alertId)
            .updateData(["isRead": true])
    }

    // MARK: - Year Transition Logs

    func fetchYearTransitionLogs(limit: Int = 20) async throws -> [YearTransitionLog] {
        let snapshot = try await yearTransitionLogsCollection()
            .order(by: "executionDate", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: YearTransitionLog.self) }
    }

    // MARK: - Real-time Listeners

    func listenToActiveRides(eventId: String, completion: @escaping ([Ride]) -> Void) -> ListenerRegistration {
        return ridesCollection()
            .whereField("eventId", isEqualTo: eventId)
            .whereField("status", in: [
                RideStatus.queued.rawValue,
                RideStatus.assigned.rawValue,
                RideStatus.enroute.rawValue
            ])
            .order(by: "priority", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let rides = documents.compactMap { try? $0.data(as: Ride.self) }
                completion(rides)
            }
    }

    func listenToUser(userId: String, completion: @escaping (User?) -> Void) -> ListenerRegistration {
        return usersCollection()
            .document(userId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else {
                    completion(nil)
                    return
                }
                let user = try? snapshot?.data(as: User.self)
                completion(user)
            }
    }

    func listenToUnreadAlerts(chapterId: String, completion: @escaping ([AdminAlert]) -> Void) -> ListenerRegistration {
        return adminAlertsCollection()
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let alerts = documents.compactMap { try? $0.data(as: AdminAlert.self) }
                completion(alerts)
            }
    }
}

// MARK: - Firebase Errors

enum FirebaseError: LocalizedError {
    case userNotFound
    case chapterNotFound
    case eventNotFound
    case assignmentNotFound
    case rideNotFound

    var errorDescription: String? {
        switch self {
        case .userNotFound: return "User not found"
        case .chapterNotFound: return "Chapter not found"
        case .eventNotFound: return "Event not found"
        case .assignmentNotFound: return "DD Assignment not found"
        case .rideNotFound: return "Ride not found"
        }
    }
}

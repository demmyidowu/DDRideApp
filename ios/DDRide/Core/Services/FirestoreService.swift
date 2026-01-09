//
//  FirestoreService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import FirebaseFirestore
import Combine

/// Custom error types for Firestore operations with user-friendly messages
enum FirestoreError: LocalizedError {
    case documentNotFound
    case decodingFailed(String)
    case encodingFailed(String)
    case networkError(Error)
    case permissionDenied
    case invalidData(String)
    case batchLimitExceeded
    case transactionFailed(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "The requested document could not be found."
        case .decodingFailed(let type):
            return "Failed to decode \(type) from Firestore."
        case .encodingFailed(let type):
            return "Failed to encode \(type) for Firestore."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .permissionDenied:
            return "You don't have permission to perform this operation."
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .batchLimitExceeded:
            return "Batch operation exceeds 500 operation limit."
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0

    private init() {
        // Configure Firestore settings for offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        db.settings = settings
    }

    // MARK: - Generic CRUD Operations

    /// Create or update a document in Firestore
    /// - Parameters:
    ///   - document: The document to save (must conform to Codable and Identifiable)
    ///   - collection: The collection name
    ///   - merge: Whether to merge with existing data (default: false)
    func save<T: Codable & Identifiable>(_ document: T, to collection: String, merge: Bool = false) async throws where T.ID == String {
        do {
            try db.collection(collection).document(document.id).setData(from: document, merge: merge)
        } catch {
            throw mapFirestoreError(error, context: "saving \(T.self)")
        }
    }

    /// Fetch a single document by ID
    /// - Parameters:
    ///   - id: The document ID
    ///   - collection: The collection name
    /// - Returns: The decoded document
    func fetch<T: Codable>(_ type: T.Type, id: String, from collection: String) async throws -> T {
        do {
            let document = try await db.collection(collection).document(id).getDocument()

            guard document.exists else {
                throw FirestoreError.documentNotFound
            }

            return try document.data(as: T.self)
        } catch let error as FirestoreError {
            throw error
        } catch {
            throw mapFirestoreError(error, context: "fetching \(T.self)")
        }
    }

    /// Delete a document by ID
    /// - Parameters:
    ///   - id: The document ID
    ///   - collection: The collection name
    func delete(id: String, from collection: String) async throws {
        do {
            try await db.collection(collection).document(id).delete()
        } catch {
            throw mapFirestoreError(error, context: "deleting document")
        }
    }

    /// Query documents with filters
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - collection: The collection name
    ///   - filters: Array of query filters
    ///   - orderBy: Optional field to order by
    ///   - descending: Whether to order descending
    ///   - limit: Optional limit for results
    /// - Returns: Array of decoded documents
    func query<T: Codable>(
        _ type: T.Type,
        from collection: String,
        filters: [QueryFilter] = [],
        orderBy: String? = nil,
        descending: Bool = false,
        limit: Int? = nil
    ) async throws -> [T] {
        do {
            var query: Query = db.collection(collection)

            // Apply filters
            for filter in filters {
                query = applyFilter(filter, to: query)
            }

            // Apply ordering
            if let orderBy = orderBy {
                query = query.order(by: orderBy, descending: descending)
            }

            // Apply limit
            if let limit = limit {
                query = query.limit(to: limit)
            }

            let snapshot = try await query.getDocuments()
            return try snapshot.documents.map { try $0.data(as: T.self) }
        } catch {
            throw mapFirestoreError(error, context: "querying \(T.self)")
        }
    }

    // MARK: - Batch Operations

    /// Execute multiple write operations in a batch (max 500 operations)
    /// - Parameter operations: Array of batch operations
    func executeBatch(_ operations: [BatchOperation]) async throws {
        guard operations.count <= 500 else {
            throw FirestoreError.batchLimitExceeded
        }

        let batch = db.batch()

        for operation in operations {
            switch operation {
            case .create(let collection, let id, let data):
                let ref = db.collection(collection).document(id)
                batch.setData(data, forDocument: ref)

            case .update(let collection, let id, let data):
                let ref = db.collection(collection).document(id)
                batch.updateData(data, forDocument: ref)

            case .delete(let collection, let id):
                let ref = db.collection(collection).document(id)
                batch.deleteDocument(ref)
            }
        }

        do {
            try await batch.commit()
        } catch {
            throw mapFirestoreError(error, context: "executing batch")
        }
    }

    /// Split large batch operations into multiple batches if needed
    /// - Parameter operations: Array of batch operations
    func executeLargeBatch(_ operations: [BatchOperation]) async throws {
        let chunks = operations.chunked(into: 500)

        for chunk in chunks {
            try await executeBatch(chunk)
        }
    }

    // MARK: - Transaction Operations

    /// Execute a transaction with retry logic
    /// - Parameter updateBlock: The transaction update block
    /// - Returns: The result from the transaction
    func runTransaction<T>(_ updateBlock: @escaping (Transaction) throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await db.runTransaction { transaction, errorPointer in
                    do {
                        return try updateBlock(transaction)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil as T?
                    }
                } as! T
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
            }
        }

        throw FirestoreError.transactionFailed(lastError?.localizedDescription ?? "Unknown error")
    }

    // MARK: - Users

    func createUser(_ user: User) async throws {
        try await save(user, to: "users")
    }

    func fetchUser(id: String) async throws -> User {
        try await fetch(User.self, id: id, from: "users")
    }

    func fetchMembers(chapterId: String) async throws -> [User] {
        try await query(
            User.self,
            from: "users",
            filters: [.equals("chapterId", chapterId)],
            orderBy: "name"
        )
    }

    func updateUser(_ user: User) async throws {
        var updatedUser = user
        updatedUser.updatedAt = Date()
        try await save(updatedUser, to: "users", merge: true)
    }

    func updateUserFCMToken(userId: String, token: String) async throws {
        try await db.collection("users")
            .document(userId)
            .updateData(["fcmToken": token])
    }

    func deleteUser(id: String) async throws {
        try await delete(id: id, from: "users")
    }

    // MARK: - Chapters

    func fetchChapter(id: String) async throws -> Chapter {
        try await fetch(Chapter.self, id: id, from: "chapters")
    }

    func fetchChapters() async throws -> [Chapter] {
        try await query(Chapter.self, from: "chapters", orderBy: "name")
    }

    func createChapter(_ chapter: Chapter) async throws {
        try await save(chapter, to: "chapters")
    }

    func updateChapter(_ chapter: Chapter) async throws {
        var updatedChapter = chapter
        updatedChapter.updatedAt = Date()
        try await save(updatedChapter, to: "chapters", merge: true)
    }

    // MARK: - Events

    func fetchEvent(id: String) async throws -> Event {
        try await fetch(Event.self, id: id, from: "events")
    }

    func fetchEvents(chapterId: String) async throws -> [Event] {
        try await query(
            Event.self,
            from: "events",
            filters: [
                .equals("chapterId", chapterId),
                .equals("status", EventStatus.active.rawValue)
            ],
            orderBy: "date",
            descending: true
        )
    }

    func fetchAllEvents(chapterId: String) async throws -> [Event] {
        try await query(
            Event.self,
            from: "events",
            filters: [.equals("chapterId", chapterId)],
            orderBy: "date",
            descending: true
        )
    }

    func createEvent(_ event: Event) async throws {
        try await save(event, to: "events")
    }

    func updateEvent(_ event: Event) async throws {
        var updatedEvent = event
        updatedEvent.updatedAt = Date()
        try await save(updatedEvent, to: "events", merge: true)
    }

    func deleteEvent(id: String) async throws {
        try await delete(id: id, from: "events")
    }

    // MARK: - Rides

    func fetchRide(id: String) async throws -> Ride {
        try await fetch(Ride.self, id: id, from: "rides")
    }

    func fetchActiveRides(eventId: String) async throws -> [Ride] {
        try await query(
            Ride.self,
            from: "rides",
            filters: [
                .equals("eventId", eventId),
                .in("status", [RideStatus.queued.rawValue, RideStatus.assigned.rawValue, RideStatus.enroute.rawValue])
            ],
            orderBy: "priority",
            descending: true
        )
    }

    func fetchRiderRides(riderId: String) async throws -> [Ride] {
        try await query(
            Ride.self,
            from: "rides",
            filters: [.equals("riderId", riderId)],
            orderBy: "requestedAt",
            descending: true,
            limit: 50
        )
    }

    func fetchDDRides(ddId: String, eventId: String) async throws -> [Ride] {
        try await query(
            Ride.self,
            from: "rides",
            filters: [
                .equals("ddId", ddId),
                .equals("eventId", eventId)
            ],
            orderBy: "requestedAt",
            descending: true
        )
    }

    func createRide(_ ride: Ride) async throws {
        try await save(ride, to: "rides")
    }

    func updateRide(_ ride: Ride) async throws {
        try await save(ride, to: "rides", merge: true)
    }

    // MARK: - DD Assignments

    func fetchDDAssignment(id: String) async throws -> DDAssignment {
        try await fetch(DDAssignment.self, id: id, from: "ddAssignments")
    }

    func fetchActiveDDAssignments(eventId: String) async throws -> [DDAssignment] {
        try await query(
            DDAssignment.self,
            from: "ddAssignments",
            filters: [
                .equals("eventId", eventId),
                .equals("isActive", true)
            ]
        )
    }

    func fetchAllDDAssignments(eventId: String) async throws -> [DDAssignment] {
        try await query(
            DDAssignment.self,
            from: "ddAssignments",
            filters: [.equals("eventId", eventId)]
        )
    }

    func createDDAssignment(_ assignment: DDAssignment) async throws {
        try await save(assignment, to: "ddAssignments")
    }

    func updateDDAssignment(_ assignment: DDAssignment) async throws {
        var updatedAssignment = assignment
        updatedAssignment.updatedAt = Date()
        try await save(updatedAssignment, to: "ddAssignments", merge: true)
    }

    // MARK: - Admin Alerts

    func fetchAdminAlerts(chapterId: String, unreadOnly: Bool = false) async throws -> [AdminAlert] {
        var filters: [QueryFilter] = [.equals("chapterId", chapterId)]
        if unreadOnly {
            filters.append(.equals("isRead", false))
        }

        return try await query(
            AdminAlert.self,
            from: "adminAlerts",
            filters: filters,
            orderBy: "createdAt",
            descending: true
        )
    }

    func createAdminAlert(_ alert: AdminAlert) async throws {
        try await save(alert, to: "adminAlerts")
    }

    func markAlertAsRead(id: String) async throws {
        try await db.collection("adminAlerts")
            .document(id)
            .updateData(["isRead": true])
    }

    // MARK: - Year Transition Logs

    func fetchYearTransitionLogs(chapterId: String) async throws -> [YearTransitionLog] {
        try await query(
            YearTransitionLog.self,
            from: "yearTransitionLogs",
            filters: [.equals("chapterId", chapterId)],
            orderBy: "executionDate",
            descending: true,
            limit: 50
        )
    }

    func createYearTransitionLog(_ log: YearTransitionLog) async throws {
        try await save(log, to: "yearTransitionLogs")
    }

    // MARK: - Real-time Listeners with Combine

    /// Listen to active rides for an event with Combine publisher
    /// Example usage:
    /// ```swift
    /// FirestoreService.shared.observeActiveRides(eventId: eventId)
    ///     .sink(receiveCompletion: { completion in
    ///         // Handle completion
    ///     }, receiveValue: { rides in
    ///         // Handle rides update
    ///     })
    ///     .store(in: &cancellables)
    /// ```
    func observeActiveRides(eventId: String) -> AnyPublisher<[Ride], Error> {
        let subject = PassthroughSubject<[Ride], Error>()

        let listener = db.collection("rides")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("status", in: [
                RideStatus.queued.rawValue,
                RideStatus.assigned.rawValue,
                RideStatus.enroute.rawValue
            ])
            .order(by: "priority", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(self.mapFirestoreError(error, context: "observing rides")))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let rides = documents.compactMap { try? $0.data(as: Ride.self) }
                subject.send(rides)
            }

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    /// Listen to active DD assignments for an event
    func observeActiveDDAssignments(eventId: String) -> AnyPublisher<[DDAssignment], Error> {
        let subject = PassthroughSubject<[DDAssignment], Error>()

        let listener = db.collection("ddAssignments")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(self.mapFirestoreError(error, context: "observing DD assignments")))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let assignments = documents.compactMap { try? $0.data(as: DDAssignment.self) }
                subject.send(assignments)
            }

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    /// Listen to unread admin alerts for a chapter
    func observeAdminAlerts(chapterId: String) -> AnyPublisher<[AdminAlert], Error> {
        let subject = PassthroughSubject<[AdminAlert], Error>()

        let listener = db.collection("adminAlerts")
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(self.mapFirestoreError(error, context: "observing admin alerts")))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let alerts = documents.compactMap { try? $0.data(as: AdminAlert.self) }
                subject.send(alerts)
            }

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    /// Listen to a specific chapter
    func observeChapter(id: String) -> AnyPublisher<Chapter, Error> {
        let subject = PassthroughSubject<Chapter, Error>()

        let listener = db.collection("chapters").document(id)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(self.mapFirestoreError(error, context: "observing chapter")))
                    return
                }

                guard let snapshot = snapshot, snapshot.exists,
                      let chapter = try? snapshot.data(as: Chapter.self) else {
                    subject.send(completion: .failure(FirestoreError.documentNotFound))
                    return
                }

                subject.send(chapter)
            }

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    /// Listen to active events for a chapter
    func observeActiveEvents(chapterId: String) -> AnyPublisher<[Event], Error> {
        let subject = PassthroughSubject<[Event], Error>()

        let listener = db.collection("events")
            .whereField("chapterId", isEqualTo: chapterId)
            .whereField("status", isEqualTo: EventStatus.active.rawValue)
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(self.mapFirestoreError(error, context: "observing events")))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let events = documents.compactMap { try? $0.data(as: Event.self) }
                subject.send(events)
            }

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    // MARK: - Legacy Listener (for backwards compatibility)

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

    // MARK: - Helper Methods

    private func applyFilter(_ filter: QueryFilter, to query: Query) -> Query {
        switch filter {
        case .equals(let field, let value):
            return query.whereField(field, isEqualTo: value)
        case .notEquals(let field, let value):
            return query.whereField(field, isNotEqualTo: value)
        case .lessThan(let field, let value):
            return query.whereField(field, isLessThan: value)
        case .lessThanOrEquals(let field, let value):
            return query.whereField(field, isLessThanOrEqualTo: value)
        case .greaterThan(let field, let value):
            return query.whereField(field, isGreaterThan: value)
        case .greaterThanOrEquals(let field, let value):
            return query.whereField(field, isGreaterThanOrEqualTo: value)
        case .in(let field, let values):
            return query.whereField(field, in: values)
        case .notIn(let field, let values):
            return query.whereField(field, notIn: values)
        case .arrayContains(let field, let value):
            return query.whereField(field, arrayContains: value)
        }
    }

    private func mapFirestoreError(_ error: Error, context: String) -> FirestoreError {
        let nsError = error as NSError

        switch nsError.code {
        case FirestoreErrorCode.notFound.rawValue:
            return .documentNotFound
        case FirestoreErrorCode.permissionDenied.rawValue, FirestoreErrorCode.unauthenticated.rawValue:
            return .permissionDenied
        case FirestoreErrorCode.unavailable.rawValue, FirestoreErrorCode.deadlineExceeded.rawValue:
            return .networkError(error)
        default:
            if nsError.domain == NSCocoaErrorDomain {
                if nsError.code == 4864 {
                    return .decodingFailed(context)
                }
            }
            return .unknown(error)
        }
    }
}

// MARK: - Supporting Types

/// Query filter types for building complex queries
enum QueryFilter {
    case equals(String, Any)
    case notEquals(String, Any)
    case lessThan(String, Any)
    case lessThanOrEquals(String, Any)
    case greaterThan(String, Any)
    case greaterThanOrEquals(String, Any)
    case `in`(String, [Any])
    case notIn(String, [Any])
    case arrayContains(String, Any)
}

/// Batch operation types
enum BatchOperation {
    case create(collection: String, id: String, data: [String: Any])
    case update(collection: String, id: String, data: [String: Any])
    case delete(collection: String, id: String)
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

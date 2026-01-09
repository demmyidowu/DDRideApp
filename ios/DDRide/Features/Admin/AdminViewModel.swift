//
//  AdminViewModel.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import Combine
import FirebaseFirestore

/// View model for the admin dashboard
/// Manages real-time updates for events, rides, DD assignments, and alerts
@MainActor
class AdminViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var activeEvent: Event?
    @Published var allEvents: [Event] = []
    @Published var activeRides: [Ride] = []
    @Published var ddAssignments: [DDAssignment] = []
    @Published var allMembers: [User] = []
    @Published var unreadAlerts: [AdminAlert] = []
    @Published var unreadAlertCount: Int = 0

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Computed Stats

    var activeRidesCount: Int {
        activeRides.filter { $0.status == .queued || $0.status == .assigned || $0.status == .enroute }.count
    }

    var activeDDsCount: Int {
        ddAssignments.filter { $0.isActive }.count
    }

    // MARK: - Dependencies

    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Initialization is handled by loadDashboardData()
    }

    deinit {
        // Cleanup all listeners
        cancellables.removeAll()
    }

    // MARK: - Core Methods

    /// Load all dashboard data and set up real-time listeners
    func loadDashboardData() async {
        guard let currentUser = authService.currentUser else {
            errorMessage = "User not authenticated"
            return
        }

        guard currentUser.role == .admin else {
            errorMessage = "Admin access required"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch all events for the chapter
            allEvents = try await firestoreService.fetchAllEvents(chapterId: currentUser.chapterId)

            // Find the active event
            activeEvent = allEvents.first { $0.status == .active }

            // Fetch all chapter members
            allMembers = try await firestoreService.fetchMembers(chapterId: currentUser.chapterId)

            // If there's an active event, set up real-time listeners
            if let activeEvent = activeEvent {
                observeActiveRides(eventId: activeEvent.id)
                observeDDAssignments(eventId: activeEvent.id)
            }

            // Observe admin alerts
            observeAdminAlerts(chapterId: currentUser.chapterId)

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Observe active rides in real-time using Combine
    func observeActiveRides(eventId: String) {
        firestoreService.observeActiveRides(eventId: eventId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to observe rides: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] rides in
                self?.activeRides = rides.sorted { $0.priority > $1.priority }
            })
            .store(in: &cancellables)
    }

    /// Observe DD assignments in real-time using Combine
    func observeDDAssignments(eventId: String) {
        // Observe all DD assignments (not just active ones) to show full status
        let subject = PassthroughSubject<[DDAssignment], Error>()

        let listener = Firestore.firestore().collection("ddAssignments")
            .whereField("eventId", isEqualTo: eventId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let assignments = documents.compactMap { try? $0.data(as: DDAssignment.self) }
                subject.send(assignments)
            }

        subject
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to observe DD assignments: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] assignments in
                // Sort: active first, then by name (requires looking up user names)
                self?.ddAssignments = assignments.sorted { first, second in
                    if first.isActive != second.isActive {
                        return first.isActive
                    }
                    return first.userId < second.userId
                }
            })
            .store(in: &cancellables)

        // Store listener for cleanup
        _ = subject.handleEvents(receiveCancel: {
            listener.remove()
        })
    }

    /// Observe admin alerts in real-time using Combine
    func observeAdminAlerts(chapterId: String) {
        firestoreService.observeAdminAlerts(chapterId: chapterId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to observe alerts: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] alerts in
                self?.unreadAlerts = alerts
                self?.unreadAlertCount = alerts.count
            })
            .store(in: &cancellables)
    }

    /// Deactivate the currently active event
    func deactivateEvent() async {
        guard let event = activeEvent else { return }

        isLoading = true
        errorMessage = nil

        do {
            var updatedEvent = event
            updatedEvent.status = .completed
            updatedEvent.updatedAt = Date()

            try await firestoreService.updateEvent(updatedEvent)

            // Reload dashboard
            await loadDashboardData()

            isLoading = false
        } catch {
            errorMessage = "Failed to deactivate event: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Fetch all members for the chapter (used in MemberManagementView)
    func fetchMembers() async {
        guard let currentUser = authService.currentUser else { return }

        do {
            allMembers = try await firestoreService.fetchMembers(chapterId: currentUser.chapterId)
        } catch {
            errorMessage = "Failed to fetch members: \(error.localizedDescription)"
        }
    }

    /// Get user details for a given user ID
    func getUser(userId: String) -> User? {
        allMembers.first { $0.id == userId }
    }

    /// Get rider details for a ride
    func getRider(for ride: Ride) -> User? {
        getUser(userId: ride.riderId)
    }

    /// Get DD details for a ride
    func getDD(for ride: Ride) -> User? {
        guard let ddId = ride.ddId else { return nil }
        return getUser(userId: ddId)
    }

    /// Refresh dashboard data manually
    func refresh() async {
        await loadDashboardData()
    }
}

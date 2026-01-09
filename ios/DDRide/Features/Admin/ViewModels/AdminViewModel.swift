//
//  AdminViewModel.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AdminViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var activeEvent: Event?
    @Published var allEvents: [Event] = []
    @Published var activeRides: [Ride] = []
    @Published var ddAssignments: [DDAssignment] = []
    @Published var allMembers: [User] = []
    @Published var unreadAlerts: [AdminAlert] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    // UI State
    @Published var showingCreateEvent = false
    @Published var showingManageMembers = false
    @Published var showingAlerts = false

    // Computed Properties
    var activeRidesCount: Int {
        activeRides.count
    }

    var activeDDsCount: Int {
        ddAssignments.filter { $0.isActive }.count
    }

    var unreadAlertCount: Int {
        unreadAlerts.count
    }

    // MARK: - Private Properties
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    private var currentChapterId: String? {
        authService.currentUser?.chapterId
    }

    // MARK: - Initialization
    init() {
        setupObservers()
    }

    // MARK: - Public Methods

    func loadDashboardData() async {
        guard let chapterId = currentChapterId else {
            errorMessage = "No chapter ID found"
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Load active event
            let events = try await firestoreService.fetchEvents(chapterId: chapterId)
            activeEvent = events.first

            // Load all events
            allEvents = try await firestoreService.fetchAllEvents(chapterId: chapterId)

            // Load members
            allMembers = try await firestoreService.fetchMembers(chapterId: chapterId)

            // If there's an active event, load rides and DD assignments
            if let eventId = activeEvent?.id {
                activeRides = try await firestoreService.fetchActiveRides(eventId: eventId)
                ddAssignments = try await firestoreService.fetchAllDDAssignments(eventId: eventId)
            }

            // Load unread alerts
            unreadAlerts = try await firestoreService.fetchAdminAlerts(chapterId: chapterId, unreadOnly: true)

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deactivateEvent() async {
        guard var event = activeEvent else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            event.status = .completed
            try await firestoreService.updateEvent(event)

            // Reload dashboard
            await loadDashboardData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helper Methods

    func getRiderName(riderId: String) -> String {
        allMembers.first { $0.id == riderId }?.name ?? "Unknown Rider"
    }

    func getDDName(ddId: String) -> String {
        allMembers.first { $0.id == ddId }?.name ?? "Unknown DD"
    }

    func getDDRideCount(ddId: String) -> Int {
        activeRides.filter { $0.ddId == ddId }.count
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe active event changes
        authService.$currentUser
            .compactMap { $0?.chapterId }
            .removeDuplicates()
            .sink { [weak self] chapterId in
                Task { [weak self] in
                    await self?.observeActiveData(chapterId: chapterId)
                }
            }
            .store(in: &cancellables)
    }

    private func observeActiveData(chapterId: String) async {
        // Observe active events
        firestoreService.observeActiveEvents(chapterId: chapterId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] events in
                self?.activeEvent = events.first

                // When active event changes, observe its rides and DDs
                if let eventId = events.first?.id {
                    Task { [weak self] in
                        await self?.observeEventData(eventId: eventId)
                    }
                }
            })
            .store(in: &cancellables)

        // Observe admin alerts
        firestoreService.observeAdminAlerts(chapterId: chapterId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] alerts in
                self?.unreadAlerts = alerts
            })
            .store(in: &cancellables)
    }

    private func observeEventData(eventId: String) async {
        // Observe active rides
        firestoreService.observeActiveRides(eventId: eventId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] rides in
                self?.activeRides = rides
            })
            .store(in: &cancellables)

        // Observe DD assignments
        firestoreService.observeActiveDDAssignments(eventId: eventId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] assignments in
                self?.ddAssignments = assignments
            })
            .store(in: &cancellables)
    }
}

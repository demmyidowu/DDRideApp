//
//  RiderViewModel.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import Combine
import CoreLocation

/// View model for rider dashboard
///
/// Manages:
/// - Active ride state
/// - Queue position and wait time
/// - Ride requests (normal and emergency)
/// - Real-time ride updates
/// - Cancellation
@MainActor
class RiderViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentRide: Ride?
    @Published var queuePosition: Int?
    @Published var estimatedWaitTime: Int?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var notes: String = ""
    @Published var currentEvent: Event?

    // MARK: - Services

    private let authService = AuthService.shared
    private let rideRequestService = RideRequestService.shared
    private let queueService = RideQueueService.shared
    private let firestoreService = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe auth state changes
        authService.$currentUser
            .sink { [weak self] user in
                guard let self = self else { return }
                if user != nil {
                    Task { @MainActor in
                        await self.loadInitialData()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Load initial data (active ride and current event)
    func loadInitialData() async {
        guard let userId = authService.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        // Load active ride if exists
        await loadActiveRide(userId: userId)

        // Load current event
        await loadCurrentEvent()

        // Start observing ride updates if there's an active ride
        if let ride = currentRide {
            observeRideUpdates(rideId: ride.id, eventId: ride.eventId)
        }
    }

    /// Load active ride for user
    private func loadActiveRide(userId: String) async {
        currentRide = await rideRequestService.getActiveRide(userId: userId)
    }

    /// Load current active event
    private func loadCurrentEvent() async {
        guard let chapterId = authService.currentUser?.chapterId else { return }

        do {
            let events = try await firestoreService.fetchEvents(chapterId: chapterId)
            currentEvent = events.first // Get most recent active event
        } catch {
            print("Failed to load event: \(error.localizedDescription)")
        }
    }

    // MARK: - Ride Request

    /// Request a normal ride
    func requestRide() async {
        await requestRide(isEmergency: false, emergencyReason: nil)
    }

    /// Request an emergency ride
    func requestEmergencyRide(reason: String) async {
        await requestRide(isEmergency: true, emergencyReason: reason)
    }

    /// Internal ride request method
    private func requestRide(isEmergency: Bool, emergencyReason: String?) async {
        guard let userId = authService.currentUser?.id,
              let eventId = currentEvent?.id else {
            showErrorMessage("Please ensure you're signed in and an event is active.")
            return
        }

        // Check if user already has an active ride
        if currentRide != nil {
            showErrorMessage("You already have an active ride.")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Prepare notes
            var finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if isEmergency, let reason = emergencyReason {
                finalNotes = finalNotes.isEmpty ? "EMERGENCY: \(reason)" : "EMERGENCY: \(reason) - \(finalNotes)"
            }

            // Request ride
            let ride = try await rideRequestService.requestRide(
                userId: userId,
                eventId: eventId,
                isEmergency: isEmergency,
                notes: finalNotes.isEmpty ? nil : finalNotes
            )

            // Update state
            currentRide = ride
            queuePosition = ride.queuePosition
            notes = ""

            // Start observing ride updates
            observeRideUpdates(rideId: ride.id, eventId: ride.eventId)

        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Ride Cancellation

    /// Cancel the current ride
    func cancelRide() async {
        guard let ride = currentRide else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await rideRequestService.cancelRide(
                rideId: ride.id,
                reason: "Cancelled by rider"
            )

            // Clear current ride
            currentRide = nil
            queuePosition = nil
            estimatedWaitTime = nil

        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Real-time Updates

    /// Observe ride updates in real-time
    private func observeRideUpdates(rideId: String, eventId: String) {
        // Cancel existing observations
        cancellables.removeAll()

        // Observe queue position
        queueService.observeRidePosition(rideId: rideId, eventId: eventId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Queue position observation failed: \(error.localizedDescription)")
                        self?.queuePosition = nil
                    }
                },
                receiveValue: { [weak self] position in
                    self?.queuePosition = position
                }
            )
            .store(in: &cancellables)

        // Observe ride changes
        firestoreService.observeActiveRides(eventId: eventId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Ride observation failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] rides in
                    guard let self = self else { return }

                    // Find current ride in updated rides
                    if let updatedRide = rides.first(where: { $0.id == rideId }) {
                        self.currentRide = updatedRide
                        self.estimatedWaitTime = updatedRide.estimatedWaitTime

                        // Stop observing if ride is completed or cancelled
                        if updatedRide.status == .completed || updatedRide.status == .cancelled {
                            self.cancellables.removeAll()
                            // Clear current ride after a delay to allow user to see final status
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.currentRide = nil
                                self.queuePosition = nil
                                self.estimatedWaitTime = nil
                            }
                        }
                    }
                }
            )
            .store(in: &cancellables)

        // Update estimated wait time periodically
        Task {
            await updateEstimatedWaitTime(rideId: rideId, eventId: eventId)
        }
    }

    /// Update estimated wait time
    private func updateEstimatedWaitTime(rideId: String, eventId: String) async {
        do {
            let waitTime = try await queueService.getEstimatedWaitTime(
                rideId: rideId,
                eventId: eventId
            )
            estimatedWaitTime = waitTime
        } catch {
            print("Failed to update wait time: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Properties

    /// Check if user can request a ride
    var canRequestRide: Bool {
        currentRide == nil && currentEvent != nil && !isLoading
    }

    /// Check if ride is assigned to a DD
    var isRideAssigned: Bool {
        guard let ride = currentRide else { return false }
        return ride.ddId != nil
    }

    /// Check if DD is en route
    var isDDEnRoute: Bool {
        currentRide?.status == .enroute
    }

    // MARK: - Helper Methods

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Reload current ride (for pull-to-refresh)
    func refresh() async {
        await loadInitialData()
    }
}

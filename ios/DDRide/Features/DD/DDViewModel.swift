//
//  DDViewModel.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation
import FirebaseFirestore
import FirebaseStorage

/// View model for DD dashboard operations
///
/// Manages:
/// - DD active/inactive status
/// - Real-time ride assignment listening
/// - Current and next ride tracking
/// - Photo and car description uploads
/// - Ride status updates (en route, complete)
/// - Statistics tracking
/// - Inactive toggle monitoring
@MainActor
class DDViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isActive: Bool = false
    @Published var currentRide: Ride?
    @Published var nextRide: Ride?
    @Published var ddAssignment: DDAssignment?
    @Published var tonightRidesCount: Int = 0
    @Published var totalRidesCount: Int = 0
    @Published var inactiveToggleCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showPhotoUploadRequired: Bool = false

    // Current rider info (cached for display)
    @Published var currentRiderName: String = ""
    @Published var currentRiderPhone: String = ""

    // MARK: - Private Properties

    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let ddAssignmentService = DDAssignmentService.shared
    private let locationService = LocationService.shared
    private let etaService = ETAService.shared

    private var cancellables = Set<AnyCancellable>()
    private var rideListener: ListenerRegistration?
    private var currentEventId: String?

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe authentication state
        authService.$currentUser
            .sink { [weak self] user in
                guard let self = self, let user = user else { return }
                Task {
                    await self.loadDDAssignment()
                }
            }
            .store(in: &cancellables)
    }

    /// Load DD assignment for current user and active event
    func loadDDAssignment() async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch active events for user's chapter
            guard let chapterId = authService.currentUser?.chapterId else {
                throw FirestoreError.invalidData("No chapter ID found")
            }

            let events = try await firestoreService.fetchEvents(chapterId: chapterId)
            guard let activeEvent = events.first(where: { $0.status == .active }) else {
                // No active event
                isLoading = false
                return
            }

            currentEventId = activeEvent.id

            // Fetch DD assignment for this event
            let assignment = try await firestoreService.fetchDDAssignment(id: userId)

            // Verify assignment is for current event
            guard assignment.eventId == activeEvent.id else {
                // Assignment exists but not for current event
                isLoading = false
                return
            }

            ddAssignment = assignment
            isActive = assignment.isActive
            inactiveToggleCount = assignment.inactiveToggles
            totalRidesCount = assignment.totalRidesCompleted

            // Check if photo and car description are complete
            checkProfileCompletion()

            // Start listening to assigned rides
            observeAssignedRides()

            // Fetch stats
            await fetchStats()

            isLoading = false
        } catch {
            errorMessage = "Failed to load DD assignment: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Check if DD profile is complete (photo + car description)
    private func checkProfileCompletion() {
        guard let assignment = ddAssignment else { return }

        let hasPhoto = assignment.photoURL != nil && !assignment.photoURL!.isEmpty
        let hasCarDescription = assignment.carDescription != nil && !assignment.carDescription!.isEmpty

        showPhotoUploadRequired = !hasPhoto || !hasCarDescription
    }

    // MARK: - Active Status Toggle

    /// Toggle DD active/inactive status
    func toggleActiveStatus() async {
        guard let assignment = ddAssignment else {
            errorMessage = "No DD assignment found"
            return
        }

        // Check if DD can go inactive (must not have active ride)
        if isActive && currentRide != nil {
            errorMessage = "Cannot go inactive while you have an active ride"
            return
        }

        // Check if profile is complete before going active
        if !isActive && showPhotoUploadRequired {
            errorMessage = "Please complete your profile (photo and car description) before going active"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Toggle status
            let newStatus = !isActive

            // Use DDAssignmentService to handle toggle (includes monitoring)
            let alerts = try await ddAssignmentService.toggleDDStatus(
                ddAssignment: assignment,
                isActive: newStatus
            )

            // Update local state
            isActive = newStatus

            // Reload assignment to get updated toggle count
            await loadDDAssignment()

            // Show alert if there are warnings
            if !alerts.isEmpty, let alert = alerts.first {
                errorMessage = alert.message
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            isLoading = false
        } catch {
            errorMessage = "Failed to toggle status: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Ride Observation

    /// Observe rides assigned to this DD
    private func observeAssignedRides() {
        guard let userId = authService.currentUser?.id,
              let eventId = currentEventId else {
            return
        }

        // Clean up existing listener
        rideListener?.remove()

        // Listen to rides assigned to this DD
        rideListener = Firestore.firestore()
            .collection("rides")
            .whereField("ddId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .whereField("status", in: [RideStatus.assigned.rawValue, RideStatus.enroute.rawValue])
            .order(by: "priority", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to observe rides: \(error.localizedDescription)"
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let rides = documents.compactMap { try? $0.data(as: Ride.self) }

                Task { @MainActor in
                    // Set current ride (highest priority assigned or enroute)
                    if let ride = rides.first {
                        self.currentRide = ride

                        // Fetch rider info for display
                        await self.fetchRiderInfo(riderId: ride.riderId)
                    } else {
                        self.currentRide = nil
                        self.currentRiderName = ""
                        self.currentRiderPhone = ""
                    }

                    // Set next ride (second in queue if exists)
                    if rides.count > 1 {
                        self.nextRide = rides[1]
                    } else {
                        self.nextRide = nil
                    }
                }
            }
    }

    /// Fetch rider information for display
    private func fetchRiderInfo(riderId: String) async {
        do {
            let rider = try await firestoreService.fetchUser(id: riderId)
            currentRiderName = rider.name
            currentRiderPhone = rider.phoneNumber
        } catch {
            print("Failed to fetch rider info: \(error.localizedDescription)")
            currentRiderName = "Unknown"
            currentRiderPhone = ""
        }
    }

    // MARK: - Ride Actions

    /// Mark ride as en route (capture DD location and calculate ETA)
    func markEnRoute() async {
        guard var ride = currentRide else {
            errorMessage = "No current ride"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Request location permission if needed
            let authorized = await locationService.requestLocationPermission()
            guard authorized else {
                throw LocationError.unauthorized
            }

            // Capture DD location once
            let ddLocation = try await locationService.captureLocationOnce()

            // Calculate ETA to rider's pickup location
            let riderLocation = ride.pickupLocation.coordinate
            let eta = await etaService.calculateETAWithFallback(from: ddLocation, to: riderLocation)

            // Update ride status
            ride.status = .enroute
            ride.enrouteAt = Date()
            ride.estimatedWaitTime = eta

            // Save to Firestore
            try await firestoreService.updateRide(ride)

            // Update local state
            currentRide = ride

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            isLoading = false
        } catch let error as LocationError {
            errorMessage = error.localizedDescription
            isLoading = false
        } catch {
            errorMessage = "Failed to mark en route: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Complete the current ride
    func completeRide() async {
        guard var ride = currentRide else {
            errorMessage = "No current ride"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Update ride status
            ride.status = .completed
            ride.completedAt = Date()

            // Save to Firestore
            try await firestoreService.updateRide(ride)

            // Increment DD assignment completed count
            if var assignment = ddAssignment {
                assignment.totalRidesCompleted += 1
                try await firestoreService.updateDDAssignment(assignment)

                // Update local state
                ddAssignment = assignment
                totalRidesCount = assignment.totalRidesCompleted
            }

            // Update stats
            await fetchStats()

            // Clear current ride (listener will update it)
            currentRide = nil

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            isLoading = false
        } catch {
            errorMessage = "Failed to complete ride: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Photo Upload

    /// Upload DD photo to Firebase Storage
    func uploadPhoto(_ image: UIImage) async throws {
        guard let userId = authService.currentUser?.id else {
            throw FirestoreError.invalidData("User not authenticated")
        }

        isLoading = true
        errorMessage = nil

        do {
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw FirestoreError.invalidData("Failed to compress image")
            }

            // Check file size (max 1MB)
            guard imageData.count <= 1_000_000 else {
                throw FirestoreError.invalidData("Image too large. Please use a smaller image.")
            }

            // Upload to Firebase Storage
            let storage = Storage.storage()
            let storageRef = storage.reference()
            let photoRef = storageRef.child("dd_photos/\(userId).jpg")

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await photoRef.putDataAsync(imageData, metadata: metadata)

            // Get download URL
            let downloadURL = try await photoRef.downloadURL()

            // Update DD assignment
            if var assignment = ddAssignment {
                assignment.photoURL = downloadURL.absoluteString
                try await firestoreService.updateDDAssignment(assignment)

                ddAssignment = assignment
                checkProfileCompletion()
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    /// Update car description
    func updateCarDescription(_ description: String) async {
        guard var assignment = ddAssignment else {
            errorMessage = "No DD assignment found"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            assignment.carDescription = description
            try await firestoreService.updateDDAssignment(assignment)

            ddAssignment = assignment
            checkProfileCompletion()

            isLoading = false
        } catch {
            errorMessage = "Failed to update car description: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Statistics

    /// Fetch tonight's ride count and total ride count
    func fetchStats() async {
        guard let userId = authService.currentUser?.id,
              let eventId = currentEventId else {
            return
        }

        do {
            let stats = try await ddAssignmentService.getDDStats(ddId: userId, eventId: eventId)

            tonightRidesCount = stats.totalRidesCompleted
            totalRidesCount = ddAssignment?.totalRidesCompleted ?? 0
        } catch {
            print("Failed to fetch stats: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        rideListener?.remove()
        cancellables.removeAll()
    }
}

//
//  EventCreationViewModel.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class EventCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var eventName = ""
    @Published var eventDate = Date()
    @Published var eventLocation = ""
    @Published var eventDescription = ""
    @Published var allowAllChapters = true
    @Published var selectedChapters: Set<String> = []
    @Published var selectedDDs: Set<String> = []

    @Published var chapters: [Chapter] = []
    @Published var members: [User] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var currentUser: User? {
        authService.currentUser
    }

    private var currentChapterId: String? {
        currentUser?.chapterId
    }

    // MARK: - Computed Properties

    var isFormValid: Bool {
        !eventName.isEmpty &&
        eventDate > Date() &&
        !selectedDDs.isEmpty &&
        (allowAllChapters || !selectedChapters.isEmpty)
    }

    var ddMembers: [User] {
        // For now, show all members as potential DDs
        // In production, might filter by a DD role or designation
        members
    }

    // MARK: - Public Methods

    func loadData() async {
        guard let chapterId = currentChapterId else {
            errorMessage = "No chapter ID found"
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Load chapters for cross-chapter events
            chapters = try await firestoreService.fetchChapters()

            // Load members who can be DDs
            members = try await firestoreService.fetchMembers(chapterId: chapterId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createEvent() async -> Bool {
        guard let chapterId = currentChapterId,
              let createdBy = currentUser?.id else {
            errorMessage = "User information not available"
            return false
        }

        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            return false
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Create event
            let event = Event(
                id: UUID().uuidString,
                name: eventName,
                chapterId: chapterId,
                date: eventDate,
                allowedChapterIds: allowAllChapters ? ["ALL"] : Array(selectedChapters),
                status: eventDate <= Date() ? .active : .scheduled,
                location: eventLocation.isEmpty ? nil : eventLocation,
                description: eventDescription.isEmpty ? nil : eventDescription,
                createdAt: Date(),
                updatedAt: Date(),
                createdBy: createdBy
            )

            try await firestoreService.createEvent(event)

            // Create DD assignments
            for ddId in selectedDDs {
                let assignment = DDAssignment(
                    id: UUID().uuidString,
                    userId: ddId,
                    eventId: event.id,
                    photoURL: nil,
                    carDescription: nil,
                    isActive: false,
                    inactiveToggles: 0,
                    lastActiveTimestamp: nil,
                    lastInactiveTimestamp: nil,
                    totalRidesCompleted: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                )

                try await firestoreService.createDDAssignment(assignment)
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func getDDMissingInfo(ddId: String) -> String? {
        guard let dd = members.first(where: { $0.id == ddId }) else {
            return nil
        }

        // Check if DD has photo or car description
        // For now, we don't have this info in User model
        // In production, you might check DDAssignment or separate profile
        return nil
    }
}

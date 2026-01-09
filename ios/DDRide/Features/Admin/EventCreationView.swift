//
//  EventCreationView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Event creation view for admins to create new events and assign DDs
/// Includes validation for all required fields
struct EventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EventCreationViewModel()

    // Form state
    @State private var eventName = ""
    @State private var event Date = Date()
    @State private var location = ""
    @State private var eventDescription = ""
    @State private var openToAllChapters = true
    @State private var selectedChapterIds: Set<String> = []
    @State private var selectedDDIds: Set<String> = []

    @State private var showingValidationErrors = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Loading...")
                } else {
                    Form {
                        basicInfoSection
                        accessControlSection
                        ddAssignmentSection
                        validationSection
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createEvent()
                        }
                    }
                    .disabled(!viewModel.isValidForm || viewModel.isSaving)
                }
            }
            .alert("Success", isPresented: $viewModel.showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Event created successfully!")
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK") {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section("Event Details") {
            TextField("Event Name", text: $eventName)
                .autocorrectionDisabled()
                .onChange(of: eventName) { _, newValue in
                    viewModel.eventName = newValue
                }

            DatePicker("Date & Time", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                .onChange(of: eventDate) { _, newValue in
                    viewModel.eventDate = newValue
                }

            TextField("Location (Optional)", text: $location)
                .autocorrectionDisabled()
                .onChange(of: location) { _, newValue in
                    viewModel.location = newValue
                }

            ZStack(alignment: .topLeading) {
                if eventDescription.isEmpty {
                    Text("Description (Optional)")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $eventDescription)
                    .frame(minHeight: 80)
                    .onChange(of: eventDescription) { _, newValue in
                        viewModel.eventDescription = newValue
                    }
            }
        }
    }

    // MARK: - Access Control Section

    private var accessControlSection: some View {
        Section {
            Toggle("Open to All Chapters", isOn: $openToAllChapters)
                .onChange(of: openToAllChapters) { _, newValue in
                    viewModel.openToAllChapters = newValue
                    if newValue {
                        selectedChapterIds.removeAll()
                    }
                }

            if !openToAllChapters {
                ForEach(viewModel.availableChapters) { chapter in
                    Toggle(chapter.name, isOn: Binding(
                        get: { selectedChapterIds.contains(chapter.id) },
                        set: { isSelected in
                            if isSelected {
                                selectedChapterIds.insert(chapter.id)
                            } else {
                                selectedChapterIds.remove(chapter.id)
                            }
                            viewModel.selectedChapterIds = selectedChapterIds
                        }
                    ))
                }
            }
        } header: {
            Text("Access Control")
        } footer: {
            if !openToAllChapters && selectedChapterIds.isEmpty {
                Text("Select at least one chapter")
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - DD Assignment Section

    private var ddAssignmentSection: some View {
        Section {
            ForEach(viewModel.availableDDs) { dd in
                HStack {
                    Toggle(dd.name, isOn: Binding(
                        get: { selectedDDIds.contains(dd.id) },
                        set: { isSelected in
                            if isSelected {
                                selectedDDIds.insert(dd.id)
                            } else {
                                selectedDDIds.remove(dd.id)
                            }
                            viewModel.selectedDDIds = selectedDDIds
                        }
                    ))

                    Spacer()

                    // Warning icons if photo or car missing
                    if viewModel.getDDAssignment(for: dd.id)?.photoURL == nil ||
                       viewModel.getDDAssignment(for: dd.id)?.carDescription == nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
        } header: {
            Text("Assign DDs")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if selectedDDIds.isEmpty {
                    Text("Select at least one DD")
                        .foregroundColor(.red)
                }
                Text("DDs with missing photos or car descriptions are marked with a warning.")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Validation Section

    @ViewBuilder
    private var validationSection: some View {
        if !viewModel.validationErrors.isEmpty {
            Section("Issues") {
                ForEach(viewModel.validationErrors, id: \.self) { error in
                    Label(error, systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Actions

    private func createEvent() async {
        await viewModel.createEvent()
    }
}

// MARK: - Event Creation View Model

@MainActor
class EventCreationViewModel: ObservableObject {
    // Published properties
    @Published var eventName = ""
    @Published var eventDate = Date()
    @Published var location = ""
    @Published var eventDescription = ""
    @Published var openToAllChapters = true
    @Published var selectedChapterIds: Set<String> = []
    @Published var selectedDDIds: Set<String> = []

    @Published var availableChapters: [Chapter] = []
    @Published var availableDDs: [User] = []
    @Published var existingDDAssignments: [DDAssignment] = []

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    @Published var showingSuccessAlert = false

    // Computed properties
    var validationErrors: [String] {
        var errors: [String] = []

        if eventName.isEmpty {
            errors.append("Event name is required")
        } else if eventName.count > 100 {
            errors.append("Event name must be 100 characters or less")
        }

        if eventDate < Date().addingTimeInterval(-86400) { // Allow today minus 1 day for testing
            errors.append("Event date must be in the future")
        }

        if !openToAllChapters && selectedChapterIds.isEmpty {
            errors.append("Select at least one chapter or enable 'Open to All Chapters'")
        }

        if selectedDDIds.isEmpty {
            errors.append("Select at least one DD")
        }

        return errors
    }

    var isValidForm: Bool {
        validationErrors.isEmpty
    }

    // Dependencies
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    // MARK: - Methods

    func loadData() async {
        guard let currentUser = authService.currentUser else { return }

        isLoading = true

        do {
            // Fetch all chapters
            availableChapters = try await firestoreService.fetchChapters()

            // Fetch all chapter members (filter for DDs later)
            let allMembers = try await firestoreService.fetchMembers(chapterId: currentUser.chapterId)
            availableDDs = allMembers.filter { $0.role == .member } // All members can be DDs

            isLoading = false
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            showingErrorAlert = true
            isLoading = false
        }
    }

    func getDDAssignment(for userId: String) -> DDAssignment? {
        existingDDAssignments.first { $0.userId == userId }
    }

    func createEvent() async {
        guard let currentUser = authService.currentUser,
              isValidForm else { return }

        isSaving = true
        errorMessage = nil

        do {
            // Create event
            let eventId = UUID().uuidString
            let event = Event(
                id: eventId,
                name: eventName,
                chapterId: currentUser.chapterId,
                date: eventDate,
                allowedChapterIds: openToAllChapters ? ["ALL"] : Array(selectedChapterIds),
                status: shouldAutoActivate ? .active : .scheduled,
                location: location.isEmpty ? nil : location,
                description: eventDescription.isEmpty ? nil : eventDescription,
                createdAt: Date(),
                updatedAt: Date(),
                createdBy: currentUser.id
            )

            try await firestoreService.createEvent(event)

            // Create DD assignments
            for ddId in selectedDDIds {
                let assignment = DDAssignment(
                    id: ddId,
                    userId: ddId,
                    eventId: eventId,
                    photoURL: nil, // DD will upload later
                    carDescription: nil, // DD will add later
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

            showingSuccessAlert = true
            isSaving = false
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            showingErrorAlert = true
            isSaving = false
        }
    }

    private var shouldAutoActivate: Bool {
        // Auto-activate if event is within 1 hour
        let oneHourFromNow = Date().addingTimeInterval(3600)
        return eventDate <= oneHourFromNow
    }
}

// MARK: - Preview

#Preview {
    EventCreationView()
}

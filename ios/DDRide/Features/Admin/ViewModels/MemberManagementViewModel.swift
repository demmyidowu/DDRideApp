//
//  MemberManagementViewModel.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class MemberManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var members: [User] = []
    @Published var filteredMembers: [User] = []
    @Published var searchText = ""
    @Published var selectedRole: UserRole?
    @Published var selectedClassYear: Int?
    @Published var sortOption: SortOption = .name

    @Published var isLoading = false
    @Published var errorMessage: String?

    // UI State
    @Published var showingAddMember = false
    @Published var showingEditMember = false
    @Published var showingCSVImport = false
    @Published var showingDeleteConfirmation = false

    @Published var selectedMember: User?

    // CSV Import
    @Published var csvImportResults: [CSVImportResult] = []
    @Published var showingCSVPreview = false

    // MARK: - Private Properties
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    private var currentChapterId: String? {
        authService.currentUser?.chapterId
    }

    // MARK: - Enums
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case classYear = "Class Year"
        case role = "Role"
    }

    struct CSVImportResult: Identifiable {
        let id = UUID()
        let name: String
        let email: String
        let phoneNumber: String
        let classYear: Int
        var error: String?
    }

    // MARK: - Initialization
    init() {
        setupBindings()
    }

    // MARK: - Public Methods

    func loadMembers() async {
        guard let chapterId = currentChapterId else {
            errorMessage = "No chapter ID found"
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            members = try await firestoreService.fetchMembers(chapterId: chapterId)
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addMember(name: String, email: String, phoneNumber: String, classYear: Int, role: UserRole) async {
        guard let chapterId = currentChapterId else {
            errorMessage = "No chapter ID found"
            return
        }

        // Validate KSU email
        guard email.lowercased().hasSuffix("@ksu.edu") else {
            errorMessage = "Must use a @ksu.edu email address"
            return
        }

        // Validate phone number (E.164 format)
        guard phoneNumber.hasPrefix("+1") && phoneNumber.count == 12 else {
            errorMessage = "Phone number must be in E.164 format: +1XXXXXXXXXX"
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let user = User(
                id: UUID().uuidString,
                name: name,
                email: email,
                phoneNumber: phoneNumber,
                chapterId: chapterId,
                role: role,
                classYear: classYear,
                isEmailVerified: false,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await firestoreService.createUser(user)

            // Reload members
            await loadMembers()

            showingAddMember = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMember(_ user: User) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await firestoreService.updateUser(user)

            // Reload members
            await loadMembers()

            showingEditMember = false
            selectedMember = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMember(_ user: User) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await firestoreService.deleteUser(id: user.id)

            // Reload members
            await loadMembers()

            showingDeleteConfirmation = false
            selectedMember = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func parseCSV(_ content: String) {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Skip header row
        guard lines.count > 1 else {
            errorMessage = "CSV file is empty or invalid"
            return
        }

        var results: [CSVImportResult] = []

        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            guard fields.count == 4 else {
                results.append(CSVImportResult(
                    name: fields.first ?? "",
                    email: "",
                    phoneNumber: "",
                    classYear: 0,
                    error: "Invalid number of fields"
                ))
                continue
            }

            let name = fields[0]
            let email = fields[1]
            let phoneNumber = fields[2]
            let classYearString = fields[3]

            // Validate
            var error: String?

            if name.isEmpty {
                error = "Name is required"
            } else if !email.lowercased().hasSuffix("@ksu.edu") {
                error = "Must use @ksu.edu email"
            } else if !phoneNumber.hasPrefix("+1") || phoneNumber.count != 12 {
                error = "Invalid phone format (use +1XXXXXXXXXX)"
            } else if let classYear = Int(classYearString), classYear >= 1 && classYear <= 4 {
                // Valid
            } else {
                error = "Invalid class year (must be 1-4)"
            }

            results.append(CSVImportResult(
                name: name,
                email: email,
                phoneNumber: phoneNumber,
                classYear: Int(classYearString) ?? 0,
                error: error
            ))
        }

        csvImportResults = results
        showingCSVPreview = true
    }

    func importCSVResults() async {
        guard let chapterId = currentChapterId else {
            errorMessage = "No chapter ID found"
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Filter only valid results
        let validResults = csvImportResults.filter { $0.error == nil }

        guard !validResults.isEmpty else {
            errorMessage = "No valid members to import"
            return
        }

        do {
            for result in validResults {
                let user = User(
                    id: UUID().uuidString,
                    name: result.name,
                    email: result.email,
                    phoneNumber: result.phoneNumber,
                    chapterId: chapterId,
                    role: .member,
                    classYear: result.classYear,
                    isEmailVerified: false,
                    createdAt: Date(),
                    updatedAt: Date()
                )

                try await firestoreService.createUser(user)
            }

            // Reload members
            await loadMembers()

            showingCSVPreview = false
            showingCSVImport = false
            csvImportResults = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Update filtered members when search text, filters, or sort changes
        Publishers.CombineLatest4(
            $searchText,
            $selectedRole,
            $selectedClassYear,
            $sortOption
        )
        .combineLatest($members)
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
    }

    private func applyFilters() {
        var filtered = members

        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { member in
                member.name.localizedCaseInsensitiveContains(searchText) ||
                member.email.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Role filter
        if let role = selectedRole {
            filtered = filtered.filter { $0.role == role }
        }

        // Class year filter
        if let classYear = selectedClassYear {
            filtered = filtered.filter { $0.classYear == classYear }
        }

        // Sort
        switch sortOption {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .classYear:
            filtered.sort { $0.classYear > $1.classYear }
        case .role:
            filtered.sort { $0.role.rawValue < $1.role.rawValue }
        }

        filteredMembers = filtered
    }
}

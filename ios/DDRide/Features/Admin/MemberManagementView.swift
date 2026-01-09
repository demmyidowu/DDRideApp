//
//  MemberManagementView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI
import UniformTypeIdentifiers

/// Member management interface for admins to add, edit, and delete chapter members
/// Includes search, filtering, and CSV import functionality
struct MemberManagementView: View {
    @StateObject private var viewModel = MemberManagementViewModel()
    @State private var searchText = ""
    @State private var showingAddMember = false
    @State private var showingEditMember: User? = nil
    @State private var showingDeleteAlert: User? = nil
    @State private var showingCSVImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Loading members...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(error: error) {
                        Task { await viewModel.loadMembers() }
                    }
                } else {
                    membersList
                }
            }
            .navigationTitle("Members")
            .searchable(text: $searchText, prompt: "Search by name or email")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddMember = true
                        } label: {
                            Label("Add Member", systemImage: "person.badge.plus")
                        }

                        Button {
                            showingCSVImport = true
                        } label: {
                            Label("Import CSV", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel("Add options")
                    }
                }
            }
            .sheet(isPresented: $showingAddMember) {
                AddMemberView(viewModel: viewModel)
            }
            .sheet(item: $showingEditMember) { member in
                EditMemberView(member: member, viewModel: viewModel)
            }
            .sheet(isPresented: $showingCSVImport) {
                CSVImportView(viewModel: viewModel)
            }
            .alert("Delete Member", isPresented: Binding(
                get: { showingDeleteAlert != nil },
                set: { if !$0 { showingDeleteAlert = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    showingDeleteAlert = nil
                }
                Button("Delete", role: .destructive) {
                    if let member = showingDeleteAlert {
                        Task {
                            await viewModel.deleteMember(member)
                            showingDeleteAlert = nil
                        }
                    }
                }
            } message: {
                if let member = showingDeleteAlert {
                    Text("Are you sure you want to delete \(member.name)? This action cannot be undone.")
                }
            }
            .task {
                await viewModel.loadMembers()
            }
        }
    }

    // MARK: - Members List

    private var membersList: some View {
        Group {
            if filteredMembers.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: searchText.isEmpty ? "No Members" : "No Results",
                    message: searchText.isEmpty ? "Add members to get started." : "No members match your search.",
                    action: searchText.isEmpty ? { showingAddMember = true } : nil,
                    actionTitle: searchText.isEmpty ? "Add Member" : nil
                )
            } else {
                List {
                    ForEach(filteredMembers) { member in
                        MemberRow(member: member)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    showingDeleteAlert = member
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(member.id == viewModel.currentUserId)

                                Button {
                                    showingEditMember = member
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var filteredMembers: [User] {
        if searchText.isEmpty {
            return viewModel.members
        } else {
            return viewModel.members.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: User

    var body: some View {
        HStack(spacing: 12) {
            // Avatar (initials)
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Text(member.name.prefix(2).uppercased())
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline)

                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(member.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    RoleBadge(role: member.role)
                    ClassYearBadge(classYear: member.classYear)
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Badges

struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(role == .admin ? Color.purple : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

struct ClassYearBadge: View {
    let classYear: Int

    var body: some View {
        Text(classYearName)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.3))
            .foregroundColor(.primary)
            .cornerRadius(4)
    }

    private var classYearName: String {
        switch classYear {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "Year \(classYear)"
        }
    }
}

// MARK: - Add Member View

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemberManagementViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var classYear = 1
    @State private var role: UserRole = .member

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                        .autocorrectionDisabled()

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Academic Info") {
                    Picker("Class Year", selection: $classYear) {
                        Text("Freshman").tag(1)
                        Text("Sophomore").tag(2)
                        Text("Junior").tag(3)
                        Text("Senior").tag(4)
                    }
                }

                Section("Role") {
                    Picker("Role", selection: $role) {
                        Text("Member").tag(UserRole.member)
                        Text("Admin").tag(UserRole.admin)
                    }
                    .pickerStyle(.segmented)
                }

                if !validationErrors.isEmpty {
                    Section("Issues") {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addMember()
                        }
                    }
                    .disabled(!isValidForm || viewModel.isSaving)
                }
            }
        }
    }

    private var validationErrors: [String] {
        var errors: [String] = []

        if name.isEmpty {
            errors.append("Name is required")
        }

        if email.isEmpty {
            errors.append("Email is required")
        } else if !email.lowercased().hasSuffix("@ksu.edu") {
            errors.append("Must use @ksu.edu email")
        }

        if phoneNumber.isEmpty {
            errors.append("Phone number is required")
        } else if !phoneNumber.hasPrefix("+1") {
            errors.append("Phone must be in E.164 format (+1XXXXXXXXXX)")
        }

        return errors
    }

    private var isValidForm: Bool {
        validationErrors.isEmpty
    }

    private func addMember() async {
        let userId = UUID().uuidString
        let user = User(
            id: userId,
            name: name,
            email: email,
            phoneNumber: phoneNumber,
            chapterId: viewModel.currentUser?.chapterId ?? "",
            role: role,
            classYear: classYear,
            isEmailVerified: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        await viewModel.addMember(user)
        dismiss()
    }
}

// MARK: - Edit Member View

struct EditMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemberManagementViewModel

    let member: User

    @State private var name: String
    @State private var email: String
    @State private var phoneNumber: String
    @State private var classYear: Int
    @State private var role: UserRole

    init(member: User, viewModel: MemberManagementViewModel) {
        self.member = member
        self.viewModel = viewModel
        _name = State(initialValue: member.name)
        _email = State(initialValue: member.email)
        _phoneNumber = State(initialValue: member.phoneNumber)
        _classYear = State(initialValue: member.classYear)
        _role = State(initialValue: member.role)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                        .autocorrectionDisabled()

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Academic Info") {
                    Picker("Class Year", selection: $classYear) {
                        Text("Freshman").tag(1)
                        Text("Sophomore").tag(2)
                        Text("Junior").tag(3)
                        Text("Senior").tag(4)
                    }
                }

                Section("Role") {
                    Picker("Role", selection: $role) {
                        Text("Member").tag(UserRole.member)
                        Text("Admin").tag(UserRole.admin)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveMember()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private func saveMember() async {
        var updatedMember = member
        updatedMember.name = name
        updatedMember.email = email
        updatedMember.phoneNumber = phoneNumber
        updatedMember.classYear = classYear
        updatedMember.role = role

        await viewModel.updateMember(updatedMember)
        dismiss()
    }
}

// MARK: - CSV Import View

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemberManagementViewModel

    @State private var showingFilePicker = false
    @State private var csvContent: String?
    @State private var parsedMembers: [ParsedMember] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if csvContent == nil {
                    // File picker instructions
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)

                        Text("Import Members from CSV")
                            .font(.title2)
                            .bold()

                        Text("Expected format:")
                            .font(.headline)
                            .padding(.top)

                        Text("""
                        name,email,phone,classYear
                        John Doe,jdoe@ksu.edu,+15551234567,2
                        Jane Smith,jsmith@ksu.edu,+15551234568,3
                        """)
                            .font(.caption)
                            .monospaced()
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        Button("Select CSV File") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Preview parsed members
                    List {
                        Section("Preview (\(parsedMembers.count) members)") {
                            ForEach(parsedMembers) { parsed in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(parsed.name)
                                            .font(.headline)
                                        Text(parsed.email)
                                            .font(.caption)
                                    }

                                    Spacer()

                                    if !parsed.isValid {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !parsedMembers.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            Task {
                                await importMembers()
                            }
                        }
                        .disabled(parsedMembers.filter { $0.isValid }.isEmpty || viewModel.isSaving)
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(csvContent: $csvContent)
            }
            .onChange(of: csvContent) { _, newValue in
                if let content = newValue {
                    parseCSV(content)
                }
            }
        }
    }

    private func parseCSV(_ content: String) {
        // Simple CSV parser (production would use proper library)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return }

        parsedMembers = lines.dropFirst().compactMap { line in
            let components = line.components(separatedBy: ",")
            guard components.count >= 4 else { return nil }

            let name = components[0].trimmingCharacters(in: .whitespaces)
            let email = components[1].trimmingCharacters(in: .whitespaces)
            let phone = components[2].trimmingCharacters(in: .whitespaces)
            let classYearString = components[3].trimmingCharacters(in: .whitespaces)
            let classYear = Int(classYearString) ?? 0

            let isValid = !name.isEmpty &&
                         email.lowercased().hasSuffix("@ksu.edu") &&
                         phone.hasPrefix("+1") &&
                         (1...4).contains(classYear)

            return ParsedMember(
                id: UUID().uuidString,
                name: name,
                email: email,
                phoneNumber: phone,
                classYear: classYear,
                isValid: isValid
            )
        }
    }

    private func importMembers() async {
        let validMembers = parsedMembers.filter { $0.isValid }
        await viewModel.importMembers(validMembers)
        dismiss()
    }
}

struct ParsedMember: Identifiable {
    let id: String
    let name: String
    let email: String
    let phoneNumber: String
    let classYear: Int
    let isValid: Bool
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var csvContent: String?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .plainText])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                parent.csvContent = content
            } catch {
                print("Error reading CSV: \(error)")
            }
        }
    }
}

// MARK: - View Model

@MainActor
class MemberManagementViewModel: ObservableObject {
    @Published var members: [User] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    var currentUser: User? {
        AuthService.shared.currentUser
    }

    var currentUserId: String? {
        currentUser?.id
    }

    private let firestoreService = FirestoreService.shared

    func loadMembers() async {
        guard let chapterId = currentUser?.chapterId else { return }

        isLoading = true
        errorMessage = nil

        do {
            members = try await firestoreService.fetchMembers(chapterId: chapterId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func addMember(_ user: User) async {
        isSaving = true
        do {
            try await firestoreService.createUser(user)
            await loadMembers()
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    func updateMember(_ user: User) async {
        isSaving = true
        do {
            try await firestoreService.updateUser(user)
            await loadMembers()
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    func deleteMember(_ user: User) async {
        guard user.id != currentUserId else {
            errorMessage = "Cannot delete yourself"
            return
        }

        isSaving = true
        do {
            try await firestoreService.deleteUser(id: user.id)
            await loadMembers()
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    func importMembers(_ parsedMembers: [ParsedMember]) async {
        guard let chapterId = currentUser?.chapterId else { return }

        isSaving = true

        for parsed in parsedMembers {
            let user = User(
                id: parsed.id,
                name: parsed.name,
                email: parsed.email,
                phoneNumber: parsed.phoneNumber,
                chapterId: chapterId,
                role: .member,
                classYear: parsed.classYear,
                isEmailVerified: false,
                createdAt: Date(),
                updatedAt: Date()
            )

            try? await firestoreService.createUser(user)
        }

        await loadMembers()
        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    MemberManagementView()
}

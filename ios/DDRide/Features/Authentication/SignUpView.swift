//
//  SignUpView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var classYear = 1
    @State private var selectedChapter: Chapter?
    @State private var chapters: [Chapter] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEmailVerification = false

    private let classYears = [1, 2, 3, 4]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())

                    TextField("Email (@ksu.edu)", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textFieldStyle(RoundedTextFieldStyle())

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(RoundedTextFieldStyle())

                    Picker("Class Year", selection: $classYear) {
                        ForEach(classYears, id: \.self) { year in
                            Text(yearName(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)

                    Menu {
                        ForEach(chapters) { chapter in
                            Button(chapter.name) {
                                selectedChapter = chapter
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedChapter?.name ?? "Select Chapter")
                                .foregroundColor(selectedChapter == nil ? .theme.textSecondary : .theme.text)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(Color.theme.cardBackground)
                        .cornerRadius(Constants.UI.cornerRadius)
                    }

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedTextFieldStyle())

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.theme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: handleSignUp) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || !isFormValid)

                    Text("By signing up, you agree to verify your KSU email address")
                        .font(.caption)
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadChapters()
            }
            .sheet(isPresented: $showingEmailVerification) {
                EmailVerificationView()
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        selectedChapter != nil
    }

    private func yearName(_ year: Int) -> String {
        switch year {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "\(year)"
        }
    }

    private func loadChapters() async {
        do {
            chapters = try await FirestoreService.shared.fetchChapters()
        } catch {
            errorMessage = "Failed to load chapters"
        }
    }

    private func handleSignUp() {
        hideKeyboard()
        errorMessage = nil

        // Validate inputs
        guard ValidationHelpers.validateEmail(email).isValid else {
            errorMessage = ValidationHelpers.validateEmail(email).errorMessage
            return
        }

        guard ValidationHelpers.validatePassword(password).isValid else {
            errorMessage = ValidationHelpers.validatePassword(password).errorMessage
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        guard let chapter = selectedChapter else {
            errorMessage = "Please select a chapter"
            return
        }

        isLoading = true

        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    name: name,
                    phoneNumber: phoneNumber,
                    chapterId: chapter.id,
                    classYear: classYear
                )

                showingEmailVerification = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthService.shared)
}

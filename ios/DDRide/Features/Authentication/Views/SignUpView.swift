//
//  SignUpView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Form
                    formSection

                    // Sign Up Button
                    signUpButton

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isLoading)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showEmailVerification) {
                EmailVerificationView()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Join DD Ride")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use your K-State email to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 20) {
            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                TextField("Full Name", text: $viewModel.name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onChange(of: viewModel.name) { _ in
                        viewModel.validateName()
                    }

                if let error = viewModel.nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.gray)

                    TextField("K-State Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .onChange(of: viewModel.email) { _ in
                            viewModel.validateEmail()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if let error = viewModel.emailError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !viewModel.email.isEmpty {
                    Text("Must be @ksu.edu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Phone Number Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.gray)

                    TextField("Phone Number", text: $viewModel.phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .onChange(of: viewModel.phoneNumber) { _ in
                            viewModel.validatePhone()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if let error = viewModel.phoneError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !viewModel.phoneNumber.isEmpty {
                    Text("Format: \(viewModel.formattedPhoneNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.newPassword)
                        .onChange(of: viewModel.password) { _ in
                            viewModel.validatePasswordField()
                            viewModel.validateConfirmPassword()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if let error = viewModel.passwordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !viewModel.password.isEmpty {
                    Text(viewModel.passwordStrengthText)
                        .font(.caption)
                        .foregroundColor(viewModel.isValidPassword ? .green : .secondary)
                }
            }

            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .onChange(of: viewModel.confirmPassword) { _ in
                            viewModel.validateConfirmPassword()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if let error = viewModel.confirmPasswordError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Password Requirements
            passwordRequirementsSection
        }
    }

    // MARK: - Password Requirements

    private var passwordRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password must include:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: viewModel.password.count >= 8 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(viewModel.password.count >= 8 ? .green : .gray)
                Text("At least 8 characters")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: (viewModel.password.rangeOfCharacter(from: .uppercaseLetters) != nil) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor((viewModel.password.rangeOfCharacter(from: .uppercaseLetters) != nil) ? .green : .gray)
                Text("One uppercase letter")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: (viewModel.password.rangeOfCharacter(from: .lowercaseLetters) != nil) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor((viewModel.password.rangeOfCharacter(from: .lowercaseLetters) != nil) ? .green : .gray)
                Text("One lowercase letter")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: (viewModel.password.rangeOfCharacter(from: .decimalDigits) != nil) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor((viewModel.password.rangeOfCharacter(from: .decimalDigits) != nil) ? .green : .gray)
                Text("One number")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Sign Up Button

    private var signUpButton: some View {
        Button {
            Task {
                await viewModel.signUp()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isSignUpFormValid ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!viewModel.isSignUpFormValid || viewModel.isLoading)
    }
}

#Preview {
    SignUpView()
}

//
//  ForgotPasswordView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Instructions
                instructionsSection

                // Email Field
                emailField

                // Reset Button
                resetButton

                Spacer()
            }
            .padding()
            .navigationTitle("Reset Password")
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
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.showSuccess = false
                    dismiss()
                }
            } message: {
                if let success = viewModel.successMessage {
                    Text(success)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Forgot your password?")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.top, 32)
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(spacing: 8) {
            Text("Enter your K-State email address and we'll send you a link to reset your password.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text("Check your inbox and follow the instructions.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Email Field

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)

                TextField("K-State Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if !email.isEmpty && !email.lowercased().hasSuffix("@ksu.edu") {
                Text("Must use K-State email (@ksu.edu)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            Task {
                await viewModel.resetPassword(email: email)
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Reset Link")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValidEmail ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!isValidEmail || viewModel.isLoading)
    }

    // MARK: - Validation

    private var isValidEmail: Bool {
        !email.isEmpty && email.lowercased().hasSuffix("@ksu.edu")
    }
}

#Preview {
    ForgotPasswordView()
}

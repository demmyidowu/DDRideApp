//
//  ForgotPasswordView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.theme.primary)

                Text("Reset Password")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .foregroundColor(.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(RoundedTextFieldStyle())
                    .padding(.horizontal, 32)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.theme.error)
                }

                Button(action: handleResetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading || email.isEmpty)
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 60)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Email Sent", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Password reset instructions have been sent to \(email)")
            }
        }
    }

    private func handleResetPassword() {
        hideKeyboard()
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await authService.sendPasswordReset(email: email)
                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthService.shared)
}

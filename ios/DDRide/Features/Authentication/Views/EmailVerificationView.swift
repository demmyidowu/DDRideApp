//
//  EmailVerificationView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct EmailVerificationView: View {
    @StateObject private var viewModel = EmailVerificationViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.accentColor)

                // Title and Instructions
                VStack(spacing: 16) {
                    Text("Verify Your Email")
                        .font(.title)
                        .fontWeight(.bold)

                    VStack(spacing: 8) {
                        Text("We've sent a verification link to:")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Text(viewModel.userEmail)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Please check your K-State inbox and click the verification link to continue.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal)
                }

                // Buttons
                VStack(spacing: 16) {
                    // Check Verification Button
                    Button {
                        Task {
                            await viewModel.checkVerification()
                        }
                    } label: {
                        HStack {
                            if viewModel.isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("I've Verified My Email")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isChecking)

                    // Resend Email Button
                    Button {
                        Task {
                            await viewModel.resendEmail()
                        }
                    } label: {
                        HStack {
                            Text(viewModel.canResend ? "Resend Verification Email" : "Resend in \(viewModel.resendCountdown)s")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .foregroundColor(viewModel.canResend ? .accentColor : .gray)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.canResend ? Color.accentColor : Color.gray, lineWidth: 2)
                        )
                    }
                    .disabled(!viewModel.canResend)
                }
                .padding(.horizontal)

                // Help Text
                VStack(spacing: 8) {
                    Text("Didn't receive the email?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Check your spam folder or resend the verification email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                // Sign Out Button
                Button {
                    do {
                        try authService.signOut()
                        dismiss()
                    } catch {
                        viewModel.showErrorMessage(error.localizedDescription)
                    }
                } label: {
                    Text("Sign Out")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
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
                }
            } message: {
                if let success = viewModel.successMessage {
                    Text(success)
                }
            }
        }
    }
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthService.shared)
}

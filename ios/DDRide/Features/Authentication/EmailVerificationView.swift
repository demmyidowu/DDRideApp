//
//  EmailVerificationView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct EmailVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.theme.primary)

            Text("Verify Your Email")
                .font(.title)
                .fontWeight(.bold)

            Text("We've sent a verification email to:")
                .foregroundColor(.theme.textSecondary)

            Text(authService.currentUser?.email ?? "")
                .font(.headline)
                .foregroundColor(.theme.primary)

            Text("Please check your inbox and click the verification link.")
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: checkVerification) {
                if isChecking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("I've Verified My Email")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isChecking)
            .padding(.horizontal, 32)

            Button("Resend Email") {
                Task {
                    // Resend verification email
                }
            }
            .font(.subheadline)
            .foregroundColor(.theme.primary)

            Spacer()

            Button("Skip for Now") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.theme.textSecondary)
            .padding(.bottom, 32)
        }
        .padding(.top, 60)
    }

    private func checkVerification() {
        isChecking = true

        Task {
            do {
                try await authService.refreshEmailVerification()

                if authService.currentUser?.isEmailVerified == true {
                    dismiss()
                }
            } catch {
                print("Error checking verification: \(error)")
            }

            isChecking = false
        }
    }
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthService.shared)
}

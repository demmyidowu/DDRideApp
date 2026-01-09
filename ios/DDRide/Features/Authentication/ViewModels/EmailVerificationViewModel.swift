//
//  EmailVerificationViewModel.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import Combine

@MainActor
class EmailVerificationViewModel: ObservableObject {
    @Published var isChecking = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var canResend = true
    @Published var resendCountdown = 0
    @Published var successMessage: String?
    @Published var showSuccess = false

    private let authService = AuthService.shared
    private var countdownTimer: Timer?

    var userEmail: String {
        if case .emailNotVerified(let user) = authService.authState {
            return user.email
        }
        return ""
    }

    // MARK: - Check Verification

    func checkVerification() async {
        isChecking = true
        errorMessage = nil

        do {
            let isVerified = try await authService.checkEmailVerification()

            isChecking = false

            if !isVerified {
                showErrorMessage("Email not verified yet. Please check your inbox and click the verification link.")
            }
            // If verified, auth state will change automatically
        } catch {
            isChecking = false
            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Resend Email

    func resendEmail() async {
        guard canResend else { return }

        do {
            try await authService.resendVerificationEmail()

            showSuccessMessage("Verification email sent! Check your K-State inbox.")

            startResendCooldown()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Resend Cooldown

    private func startResendCooldown() {
        canResend = false
        resendCountdown = 60

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                self.resendCountdown -= 1

                if self.resendCountdown <= 0 {
                    timer.invalidate()
                    self.canResend = true
                    self.resendCountdown = 0
                }
            }
        }
    }

    // MARK: - Error Handling

    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

    // MARK: - Cleanup

    deinit {
        countdownTimer?.invalidate()
    }
}

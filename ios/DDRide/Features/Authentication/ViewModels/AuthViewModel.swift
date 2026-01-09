//
//  AuthViewModel.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    // Sign Up Fields
    @Published var name = ""
    @Published var email = ""
    @Published var phoneNumber = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showEmailVerification = false
    @Published var successMessage: String?
    @Published var showSuccess = false

    // Validation
    @Published var nameError: String?
    @Published var emailError: String?
    @Published var phoneError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?

    private let authService = AuthService.shared

    // MARK: - Computed Properties

    var isSignUpFormValid: Bool {
        !name.isEmpty &&
        isValidKSUEmail &&
        isValidPhoneNumber &&
        isValidPassword &&
        passwordsMatch
    }

    var isLoginFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var isValidKSUEmail: Bool {
        email.lowercased().hasSuffix("@ksu.edu") && email.contains("@")
    }

    var isValidPhoneNumber: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        return digits.count == 10 || (digits.count == 11 && digits.first == "1")
    }

    var isValidPassword: Bool {
        password.count >= 8 &&
        password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
        password.rangeOfCharacter(from: .lowercaseLetters) != nil &&
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var passwordStrengthText: String {
        if password.isEmpty {
            return ""
        }

        var requirements: [String] = []

        if password.count < 8 {
            requirements.append("8+ characters")
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            requirements.append("uppercase letter")
        }
        if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            requirements.append("lowercase letter")
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            requirements.append("number")
        }

        if requirements.isEmpty {
            return "Strong password"
        } else {
            return "Needs: \(requirements.joined(separator: ", "))"
        }
    }

    var formattedPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }

        if digits.isEmpty {
            return ""
        }

        var formatted = ""

        if digits.count <= 3 {
            formatted = "(\(digits)"
        } else if digits.count <= 6 {
            let areaCode = digits.prefix(3)
            let prefix = digits.dropFirst(3)
            formatted = "(\(areaCode)) \(prefix)"
        } else if digits.count <= 10 {
            let areaCode = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let suffix = digits.dropFirst(6)
            formatted = "(\(areaCode)) \(prefix)-\(suffix)"
        } else {
            let areaCode = digits.dropFirst(1).prefix(3)
            let prefix = digits.dropFirst(4).prefix(3)
            let suffix = digits.dropFirst(7).prefix(4)
            formatted = "(\(areaCode)) \(prefix)-\(suffix)"
        }

        return formatted
    }

    // MARK: - Sign Up

    func signUp() async {
        clearErrors()

        guard validateSignUpForm() else { return }

        isLoading = true

        do {
            try await authService.signUp(
                email: email,
                password: password,
                name: name,
                phoneNumber: phoneNumber
            )

            isLoading = false
            showEmailVerification = true
        } catch let error as AuthError {
            handleError(error)
        } catch let error as NSError {
            if let authError = AuthErrorCode.Code(rawValue: error.code) {
                handleFirebaseError(authError)
            } else {
                handleError(error)
            }
        }
    }

    // MARK: - Sign In

    func signIn() async {
        clearErrors()

        guard !email.isEmpty && !password.isEmpty else {
            showErrorMessage("Please enter email and password")
            return
        }

        isLoading = true

        do {
            try await authService.signIn(email: email, password: password)
            isLoading = false
            // Navigation handled by auth state observer
        } catch let error as AuthError {
            handleError(error)
        } catch let error as NSError {
            if let authError = AuthErrorCode.Code(rawValue: error.code) {
                handleFirebaseError(authError)
            } else {
                handleError(error)
            }
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        clearErrors()

        guard !email.isEmpty else {
            showErrorMessage("Please enter your email")
            return
        }

        isLoading = true

        do {
            try await authService.resetPassword(email: email)
            isLoading = false
            showSuccessMessage("Password reset email sent. Check your K-State inbox.")
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
            clearForm()
        } catch {
            showErrorMessage("Failed to sign out: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation

    private func validateSignUpForm() -> Bool {
        var isValid = true

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = "Please enter your full name"
            isValid = false
        }

        if !isValidKSUEmail {
            emailError = "Must use K-State email (@ksu.edu)"
            isValid = false
        }

        if !isValidPhoneNumber {
            phoneError = "Please enter a valid 10-digit phone number"
            isValid = false
        }

        if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
            isValid = false
        } else if !isValidPassword {
            passwordError = "Password must contain uppercase, lowercase, and number"
            isValid = false
        }

        if !passwordsMatch {
            confirmPasswordError = "Passwords do not match"
            isValid = false
        }

        return isValid
    }

    func validateName() {
        if !name.isEmpty && name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = "Please enter your full name"
        } else {
            nameError = nil
        }
    }

    func validateEmail() {
        if !email.isEmpty && !isValidKSUEmail {
            emailError = "Must use K-State email (@ksu.edu)"
        } else {
            emailError = nil
        }
    }

    func validatePhone() {
        if !phoneNumber.isEmpty && !isValidPhoneNumber {
            phoneError = "Please enter a valid 10-digit phone number"
        } else {
            phoneError = nil
        }
    }

    func validatePasswordField() {
        if !password.isEmpty && password.count < 8 {
            passwordError = "Password must be at least 8 characters"
        } else if !password.isEmpty && !isValidPassword {
            passwordError = "Password must contain uppercase, lowercase, and number"
        } else {
            passwordError = nil
        }
    }

    func validateConfirmPassword() {
        if !confirmPassword.isEmpty && !passwordsMatch {
            confirmPasswordError = "Passwords do not match"
        } else {
            confirmPasswordError = nil
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        isLoading = false

        if let authError = error as? AuthError {
            showErrorMessage(authError.localizedDescription ?? "An error occurred")
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }

    private func handleFirebaseError(_ error: AuthErrorCode.Code) {
        isLoading = false

        let authError = AuthErrorCode(_nsError: NSError(domain: AuthErrorDomain, code: error.rawValue))
        showErrorMessage(authError.friendlyMessage)
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

    private func clearErrors() {
        errorMessage = nil
        showError = false
        successMessage = nil
        showSuccess = false
        nameError = nil
        emailError = nil
        phoneError = nil
        passwordError = nil
        confirmPasswordError = nil
    }

    private func clearForm() {
        name = ""
        email = ""
        phoneNumber = ""
        password = ""
        confirmPassword = ""
        clearErrors()
    }
}

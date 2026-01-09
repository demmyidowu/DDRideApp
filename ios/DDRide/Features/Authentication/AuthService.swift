//
//  AuthService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var authState: AuthState = .signedOut

    private var authStateListener: AuthStateDidChangeListenerHandle?

    enum AuthState: Equatable {
        case signedOut
        case emailNotVerified(User)
        case signedIn(User)

        var isSignedIn: Bool {
            if case .signedIn = self {
                return true
            }
            return false
        }
    }

    private init() {
        // Listen to auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task {
                await self?.handleAuthStateChange(firebaseUser)
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, name: String, phoneNumber: String) async throws {
        // Validate KSU email
        guard validateKSUEmail(email) else {
            throw AuthError.invalidEmail
        }

        // Validate password strength
        try validatePassword(password)

        // Validate name
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AuthError.invalidName
        }

        // Validate phone number
        let formattedPhone = try formatPhoneNumber(phoneNumber)

        // Create Firebase user
        let authResult = try await Auth.auth().createUser(
            withEmail: email.lowercased(),
            password: password
        )

        // Send verification email
        try await authResult.user.sendEmailVerification()

        // Create Firestore user document (marked as unverified)
        let user = User(
            id: authResult.user.uid,
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.lowercased(),
            phoneNumber: formattedPhone,
            chapterId: "", // Will be set by admin
            role: .member,
            classYear: 1, // Default, will be updated by admin
            isEmailVerified: false,
            fcmToken: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await createUserDocument(user)

        authState = .emailNotVerified(user)
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        let authResult = try await Auth.auth().signIn(
            withEmail: email.lowercased(),
            password: password
        )

        // Reload to get latest verification status
        try await authResult.user.reload()

        // Fetch user data
        let user = try await fetchUser(id: authResult.user.uid)

        // Check if email is verified
        guard authResult.user.isEmailVerified else {
            authState = .emailNotVerified(user)
            throw AuthError.emailNotVerified
        }

        // Update user document with verified status if needed
        if !user.isEmailVerified {
            var updatedUser = user
            updatedUser.isEmailVerified = true
            updatedUser.updatedAt = Date()
            try await updateUserDocument(updatedUser)
            currentUser = updatedUser
            authState = .signedIn(updatedUser)
        } else {
            currentUser = user
            authState = .signedIn(user)
        }
    }

    // MARK: - Email Verification

    func checkEmailVerification() async throws -> Bool {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }

        try await firebaseUser.reload()

        if firebaseUser.isEmailVerified {
            let user = try await fetchUser(id: firebaseUser.uid)

            // Update user document with verified status
            if !user.isEmailVerified {
                var updatedUser = user
                updatedUser.isEmailVerified = true
                updatedUser.updatedAt = Date()
                try await updateUserDocument(updatedUser)
                currentUser = updatedUser
                authState = .signedIn(updatedUser)
            } else {
                currentUser = user
                authState = .signedIn(user)
            }

            return true
        }

        return false
    }

    func resendVerificationEmail() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }

        try await firebaseUser.sendEmailVerification()
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        guard validateKSUEmail(email) else {
            throw AuthError.invalidEmail
        }

        try await Auth.auth().sendPasswordReset(withEmail: email.lowercased())
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        authState = .signedOut
    }

    // MARK: - Validation

    private func validateKSUEmail(_ email: String) -> Bool {
        return email.lowercased().hasSuffix("@ksu.edu")
    }

    private func validatePassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw AuthError.passwordTooShort
        }

        guard password.rangeOfCharacter(from: .uppercaseLetters) != nil else {
            throw AuthError.passwordNeedsUppercase
        }

        guard password.rangeOfCharacter(from: .lowercaseLetters) != nil else {
            throw AuthError.passwordNeedsLowercase
        }

        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            throw AuthError.passwordNeedsNumber
        }
    }

    private func formatPhoneNumber(_ phone: String) throws -> String {
        // Remove all non-numeric characters
        let digits = phone.filter { $0.isNumber }

        guard digits.count == 10 || digits.count == 11 else {
            throw AuthError.invalidPhoneNumber
        }

        // Add +1 if not present
        if digits.count == 10 {
            return "+1\(digits)"
        } else if digits.first == "1" {
            return "+\(digits)"
        } else {
            throw AuthError.invalidPhoneNumber
        }
    }

    // MARK: - Firestore Operations

    private func createUserDocument(_ user: User) async throws {
        try Firestore.firestore()
            .collection("users")
            .document(user.id)
            .setData(from: user)
    }

    private func updateUserDocument(_ user: User) async throws {
        try Firestore.firestore()
            .collection("users")
            .document(user.id)
            .setData(from: user)
    }

    private func fetchUser(id: String) async throws -> User {
        return try await Firestore.firestore()
            .collection("users")
            .document(id)
            .getDocument()
            .data(as: User.self)
    }

    // MARK: - Auth State Handler

    private func handleAuthStateChange(_ firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else {
            currentUser = nil
            authState = .signedOut
            return
        }

        do {
            try await firebaseUser.reload()

            let user = try await fetchUser(id: firebaseUser.uid)

            if firebaseUser.isEmailVerified {
                // Update user document if needed
                if !user.isEmailVerified {
                    var updatedUser = user
                    updatedUser.isEmailVerified = true
                    updatedUser.updatedAt = Date()
                    try await updateUserDocument(updatedUser)
                    currentUser = updatedUser
                    authState = .signedIn(updatedUser)
                } else {
                    currentUser = user
                    authState = .signedIn(user)
                }
            } else {
                authState = .emailNotVerified(user)
            }
        } catch {
            print("Error handling auth state: \(error)")
            currentUser = nil
            authState = .signedOut
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidName
    case invalidPhoneNumber
    case emailNotVerified
    case notAuthenticated
    case passwordTooShort
    case passwordNeedsUppercase
    case passwordNeedsLowercase
    case passwordNeedsNumber

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Must use K-State email (@ksu.edu)"
        case .invalidName:
            return "Please enter your full name"
        case .invalidPhoneNumber:
            return "Please enter a valid 10-digit phone number"
        case .emailNotVerified:
            return "Please verify your K-State email before signing in"
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .passwordTooShort:
            return "Password must be at least 8 characters"
        case .passwordNeedsUppercase:
            return "Password must contain at least one uppercase letter"
        case .passwordNeedsLowercase:
            return "Password must contain at least one lowercase letter"
        case .passwordNeedsNumber:
            return "Password must contain at least one number"
        }
    }
}

// MARK: - Firebase Auth Error Extension

extension AuthErrorCode {
    var friendlyMessage: String {
        switch self {
        case .emailAlreadyInUse:
            return "This email is already registered. Please sign in instead."
        case .invalidEmail:
            return "Invalid email address format."
        case .weakPassword:
            return "Password is too weak. Please use a stronger password."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .userNotFound:
            return "No account found with this email."
        case .userDisabled:
            return "This account has been disabled. Please contact support."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return "An error occurred. Please try again."
        }
    }
}

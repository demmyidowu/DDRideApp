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
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let firebaseUser = firebaseUser {
                    await self.loadUserData(uid: firebaseUser.uid)
                } else {
                    self.currentUser = nil
                    self.isLoading = false
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await loadUserData(uid: result.user.uid)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signUp(email: String, password: String, name: String, phoneNumber: String, chapterId: String, classYear: Int) async throws {
        // Validate KSU email
        guard email.lowercased().hasSuffix("@ksu.edu") else {
            let error = NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Must use a @ksu.edu email address"])
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await auth.createUser(withEmail: email, password: password)

            // Create user document
            let user = User(
                id: result.user.uid,
                name: name,
                email: email,
                phoneNumber: phoneNumber,
                chapterId: chapterId,
                role: .member, // Default role (was .rider, corrected to .member)
                classYear: classYear,
                isEmailVerified: false,
                createdAt: Date(),
                updatedAt: Date()
            )

            try await saveUser(user)

            // Send verification email
            try await result.user.sendEmailVerification()

            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signOut() throws {
        do {
            try auth.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func refreshEmailVerification() async throws {
        guard let firebaseUser = auth.currentUser else { return }

        try await firebaseUser.reload()

        if firebaseUser.isEmailVerified, var user = currentUser {
            user.isEmailVerified = true
            user.updatedAt = Date()
            try await saveUser(user)
            currentUser = user
        }
    }

    // MARK: - Private Methods

    private func loadUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()

            guard document.exists else {
                isLoading = false
                return
            }

            currentUser = try document.data(as: User.self)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func saveUser(_ user: User) async throws {
        try db.collection("users").document(user.id).setData(from: user)
    }
}

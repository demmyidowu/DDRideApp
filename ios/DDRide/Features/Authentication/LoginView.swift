//
//  LoginView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo/Header
                    VStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.theme.primary)

                        Text("DD Ride")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("K-State Designated Driver")
                            .font(.subheadline)
                            .foregroundColor(.theme.textSecondary)
                    }
                    .padding(.top, 60)

                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(RoundedTextFieldStyle())

                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.theme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: handleLogin) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || email.isEmpty || password.isEmpty)

                        Button("Forgot Password?") {
                            showingForgotPassword = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.theme.primary)
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.theme.textSecondary)

                        Button("Sign Up") {
                            showingSignUp = true
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.theme.primary)
                    }
                    .font(.subheadline)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
        }
    }

    private func handleLogin() {
        hideKeyboard()
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
}

//
//  LoginView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()

                    // Header
                    headerSection

                    // Form
                    formSection

                    // Sign In Button
                    signInButton

                    // Forgot Password
                    forgotPasswordButton

                    // Divider
                    dividerSection

                    // Sign Up Link
                    signUpSection

                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
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
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon/Logo
            Image(systemName: "car.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("DD Ride")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("K-State Designated Driver")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email Field
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)

                TextField("K-State Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // Password Field
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button {
            Task {
                await viewModel.signIn()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isLoginFormValid ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!viewModel.isLoginFormValid || viewModel.isLoading)
    }

    // MARK: - Forgot Password Button

    private var forgotPasswordButton: some View {
        Button {
            showForgotPassword = true
        } label: {
            Text("Forgot Password?")
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
    }

    // MARK: - Divider Section

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))

            Text("OR")
                .font(.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
    }

    // MARK: - Sign Up Section

    private var signUpSection: some View {
        VStack(spacing: 16) {
            Text("Don't have an account?")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                showSignUp = true
            } label: {
                Text("Create Account")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.clear)
                    .foregroundColor(.accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
            }
        }
    }
}

#Preview {
    LoginView()
}

//
//  ErrorView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

/// Reusable error view with optional retry action
///
/// Usage:
/// ```swift
/// ErrorView(error: error, onRetry: { await viewModel.retry() })
/// ErrorView(message: "Custom error message", onRetry: retryAction)
/// ```
struct ErrorView: View {
    let error: Error?
    let message: String?
    let onRetry: (() -> Void)?

    init(error: Error? = nil, message: String? = nil, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text("Something Went Wrong")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text(displayMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)

            if let onRetry = onRetry {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .accessibilityLabel("Retry")
                .accessibilityHint("Double tap to try the action again")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displayMessage: String {
        if let message = message {
            return message
        } else if let error = error {
            return error.localizedDescription
        } else {
            return "An unexpected error occurred. Please try again."
        }
    }
}

/// Inline error banner for use within views
struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

#Preview {
    VStack(spacing: 40) {
        ErrorView(message: "Something went wrong. Please try again.") {
            print("Retry tapped")
        }

        ErrorBanner(message: "Failed to load data", onDismiss: {
            print("Dismissed")
        })
        .padding()
    }
}

//
//  LoadingView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

/// Reusable loading view with optional message
///
/// Usage:
/// ```swift
/// LoadingView(message: "Loading rides...")
/// LoadingView(message: "Please wait...", showBackground: false)
/// ```
struct LoadingView: View {
    var message: String? = nil
    var showBackground: Bool = true

    var body: some View {
        ZStack {
            if showBackground {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

/// Inline loading indicator for use within views
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingView()
        LoadingView(message: "Requesting ride...")
    }
    .padding()
}

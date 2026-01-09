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
/// ```
struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.5)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

/// Full-screen loading overlay
struct LoadingOverlay: View {
    var message: String = "Loading..."

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            LoadingView(message: message)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingView()
        LoadingView(message: "Requesting ride...")
    }
    .padding()
}

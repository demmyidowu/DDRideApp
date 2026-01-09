//
//  EmptyStateView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable empty state view with icon, title, message, and optional action
///
/// Usage:
/// ```swift
/// EmptyStateView(
///     icon: "car.fill",
///     title: "No Active Rides",
///     message: "Request a ride to get started"
/// )
/// ```
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    VStack(spacing: 40) {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "All Caught Up!",
            message: "No rides in queue. You'll be notified when someone needs a ride."
        )

        EmptyStateView(
            icon: "car.fill",
            title: "No Active Rides",
            message: "Request a ride to get started",
            action: {},
            actionTitle: "Request Ride"
        )
    }
}

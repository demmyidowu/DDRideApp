//
//  StatusBadge.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable status badge with color coding
///
/// Usage:
/// ```swift
/// StatusBadge(status: .queued)
/// StatusBadge(status: .enroute)
/// ```
struct StatusBadge: View {
    let status: RideStatus

    private var backgroundColor: Color {
        switch status {
        case .queued:
            return Color.yellow.opacity(0.2)
        case .assigned:
            return Color.blue.opacity(0.2)
        case .enroute:
            return Color.green.opacity(0.2)
        case .completed:
            return Color.gray.opacity(0.2)
        case .cancelled:
            return Color.red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .queued:
            return Color.yellow.opacity(0.8)
        case .assigned:
            return Color.blue
        case .enroute:
            return Color.green
        case .completed:
            return Color.gray
        case .cancelled:
            return Color.red
        }
    }

    private var icon: String {
        switch status {
        case .queued:
            return "clock.fill"
        case .assigned:
            return "checkmark.circle.fill"
        case .enroute:
            return "car.fill"
        case .completed:
            return "flag.checkered.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)

            Text(status.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.displayName)")
    }
}

/// Emergency badge for emergency rides
struct EmergencyBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)

            Text("EMERGENCY")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red)
        .cornerRadius(8)
        .accessibilityLabel("Emergency ride")
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .queued)
        StatusBadge(status: .assigned)
        StatusBadge(status: .enroute)
        StatusBadge(status: .completed)
        StatusBadge(status: .cancelled)
        EmergencyBadge()
    }
    .padding()
}

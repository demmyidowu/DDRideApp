//
//  DDStatusBadge.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Badge showing DD active/inactive status
///
/// Usage:
/// ```swift
/// DDStatusBadge(isActive: true)
/// DDStatusBadge(isActive: false, showText: false)
/// ```
struct DDStatusBadge: View {
    let isActive: Bool
    var showText: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            if showText {
                Text(isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(isActive ? .green : .gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .accessibilityLabel(isActive ? "Active" : "Inactive")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Larger DD status indicator for headers
struct DDStatusIndicator: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(isActive ? Color.green : Color.gray)
                    .frame(width: 16, height: 16)

                if isActive {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 32, height: 32)
                        .scaleEffect(1.0)
                        .opacity(0.5)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isActive)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isActive ? "You're Active" : "You're Inactive")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(isActive ? "Ready to accept rides" : "Not accepting rides")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isActive ? "You're active and ready to accept rides" : "You're inactive and not accepting rides")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Small badges
        HStack(spacing: 16) {
            DDStatusBadge(isActive: true)
            DDStatusBadge(isActive: false)
        }

        HStack(spacing: 16) {
            DDStatusBadge(isActive: true, showText: false)
            DDStatusBadge(isActive: false, showText: false)
        }

        Divider()

        // Large indicators
        DDStatusIndicator(isActive: true)
        DDStatusIndicator(isActive: false)
    }
    .padding()
}

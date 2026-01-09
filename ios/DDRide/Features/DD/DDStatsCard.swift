//
//  DDStatsCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Statistics card component for DD dashboard
///
/// Displays a stat with icon, title, and count
struct DDStatsCard: View {
    let title: String
    let count: Int
    let icon: String // SF Symbol name

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            // Count
            Text("\(count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count) rides")
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        DDStatsCard(
            title: "Tonight",
            count: 8,
            icon: "moon.stars.fill"
        )

        DDStatsCard(
            title: "Total",
            count: 127,
            icon: "car.fill"
        )
    }
    .padding()
}

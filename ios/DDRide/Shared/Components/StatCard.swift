//
//  StatCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable stat card for displaying metrics
///
/// Usage:
/// ```swift
/// StatCard(title: "Tonight", value: "12")
/// StatCard(title: "Total", value: "156", icon: "car.fill")
/// ```
struct StatCard: View {
    let title: String
    let value: String
    var icon: String? = nil
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.card)
        .shadow(
            color: AppTheme.Shadow.sm.color,
            radius: AppTheme.Shadow.sm.radius,
            x: AppTheme.Shadow.sm.x,
            y: AppTheme.Shadow.sm.y
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Horizontal stat card with icon
struct HorizontalStatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.card)
        .shadow(
            color: AppTheme.Shadow.sm.color,
            radius: AppTheme.Shadow.sm.radius,
            x: AppTheme.Shadow.sm.x,
            y: AppTheme.Shadow.sm.y
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Compact stat row for lists
struct StatRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Vertical stat cards
            HStack(spacing: 16) {
                StatCard(title: "Tonight", value: "12", icon: "car.fill", color: .blue)
                StatCard(title: "Total", value: "156", icon: "chart.bar.fill", color: .green)
            }

            // Horizontal stat cards
            HorizontalStatCard(title: "Active Rides", value: "8", icon: "car.fill", color: .blue)
            HorizontalStatCard(title: "Queue Length", value: "5", icon: "list.bullet", color: .orange)
            HorizontalStatCard(title: "Active DDs", value: "3", icon: "person.2.fill", color: .green)

            // Stat rows
            VStack(spacing: 12) {
                StatRow(label: "Completed Today", value: "24", icon: "checkmark.circle.fill")
                Divider()
                StatRow(label: "Average Wait Time", value: "8 min", icon: "clock.fill")
                Divider()
                StatRow(label: "Total Members", value: "42", icon: "person.3.fill")
            }
            .padding()
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.card)
        }
        .padding()
    }
}

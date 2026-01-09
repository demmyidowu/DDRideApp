//
//  InfoCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable info card for displaying important information
///
/// Usage:
/// ```swift
/// InfoCard(type: .info, message: "Ride assigned to you")
/// InfoCard(type: .warning, message: "Low battery detected")
/// ```
struct InfoCard: View {
    enum CardType {
        case info
        case success
        case warning
        case error

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }

    let type: CardType
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(type.color)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .accessibilityLabel("Dismiss")
            }
        }
        .padding()
        .background(type.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(AppTheme.CornerRadius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(typeLabel): \(message)")
    }

    private var typeLabel: String {
        switch type {
        case .info: return "Info"
        case .success: return "Success"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

/// Large info card with title
struct LargeInfoCard: View {
    let icon: String
    let title: String
    let message: String
    var color: Color = .blue
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(color)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(color)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.card)
        .shadow(
            color: AppTheme.Shadow.md.color,
            radius: AppTheme.Shadow.md.radius,
            x: AppTheme.Shadow.md.x,
            y: AppTheme.Shadow.md.y
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

/// Queue position card
struct QueuePositionCard: View {
    let position: Int
    let estimatedWait: Int // in minutes

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're \(position.ordinal) in line")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Estimated wait: \(estimatedWait) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(position)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.card)
        .shadow(
            color: AppTheme.Shadow.md.color,
            radius: AppTheme.Shadow.md.radius,
            x: AppTheme.Shadow.md.x,
            y: AppTheme.Shadow.md.y
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You're \(position.ordinal) in line. Estimated wait: \(estimatedWait) minutes")
    }
}

// MARK: - Helper Extension

extension Int {
    var ordinal: String {
        let suffix: String
        switch self % 10 {
        case 1 where self % 100 != 11:
            suffix = "st"
        case 2 where self % 100 != 12:
            suffix = "nd"
        case 3 where self % 100 != 13:
            suffix = "rd"
        default:
            suffix = "th"
        }
        return "\(self)\(suffix)"
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Info cards
            InfoCard(type: .info, message: "Your ride has been assigned")
            InfoCard(type: .success, message: "Profile updated successfully", onDismiss: {})
            InfoCard(type: .warning, message: "Your estimated wait time has increased")
            InfoCard(type: .error, message: "Failed to connect to server", onDismiss: {})

            // Large info card
            LargeInfoCard(
                icon: "checkmark.circle.fill",
                title: "Ride Complete!",
                message: "Thank you for using DD Ride. Please rate your experience.",
                color: .green,
                action: {},
                actionTitle: "Rate Ride"
            )

            // Queue position card
            QueuePositionCard(position: 3, estimatedWait: 8)
        }
        .padding()
    }
}

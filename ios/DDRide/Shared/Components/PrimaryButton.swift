//
//  PrimaryButton.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable primary button with loading state
///
/// Usage:
/// ```swift
/// PrimaryButton(title: "Request Ride", action: requestRide)
/// PrimaryButton(title: "Loading...", isLoading: true) { }
/// ```
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var style: ButtonStyleType = .primary
    var icon: String? = nil

    enum ButtonStyleType {
        case primary
        case secondary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary:
                return .accentColor
            case .secondary:
                return Color(.systemGray5)
            case .destructive:
                return .red
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive:
                return .white
            case .secondary:
                return .primary
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.headline)
                    }

                    Text(title)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding()
            .background(isLoading ? style.backgroundColor.opacity(0.6) : style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Loading" : title)
        .accessibilityHint(isLoading ? "" : "Double tap to \(title.lowercased())")
    }
}

/// Circular action button (for large center button)
struct CircularActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var size: CGFloat = 200

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: size / 3.5))

                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isLoading ? Color.accentColor.opacity(0.6) : Color.accentColor)
            )
            .foregroundColor(.white)
            .shadow(color: .accentColor.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isLoading)
        .accessibilityLabel(isLoading ? "Loading" : title)
        .accessibilityHint(isLoading ? "" : "Double tap to \(title.lowercased())")
    }
}

#Preview {
    VStack(spacing: 24) {
        PrimaryButton(title: "Request Ride", icon: "car.fill", action: {})

        PrimaryButton(title: "Loading...", isLoading: true, action: {})

        PrimaryButton(
            title: "Cancel Ride",
            style: .destructive,
            icon: "xmark",
            action: {}
        )

        PrimaryButton(
            title: "Secondary Action",
            style: .secondary,
            action: {}
        )

        Spacer().frame(height: 40)

        CircularActionButton(
            icon: "car.fill",
            title: "Request Ride",
            action: {}
        )
    }
    .padding()
}

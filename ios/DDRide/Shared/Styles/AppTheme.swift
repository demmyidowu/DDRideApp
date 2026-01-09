//
//  AppTheme.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

// MARK: - App Theme

/// Centralized theme system for DD Ride App
/// Provides colors, typography, spacing, and styling
struct AppTheme {

    // MARK: - Colors

    struct Colors {
        // Primary brand colors
        static let primary = Color.blue
        static let secondary = Color.gray
        static let accent = Color.teal

        // Semantic colors
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let info = Color.blue

        // Background colors (adapts to light/dark mode)
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let cardBackground = Color(.systemGray6)

        // Text colors
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(.tertiaryLabel)

        // Ride status colors
        static let rideQueued = Color.orange
        static let rideAssigned = Color.blue
        static let rideEnroute = Color.green
        static let rideCompleted = Color.gray
        static let rideCancelled = Color.red.opacity(0.7)

        // DD status colors
        static let ddActive = Color.green
        static let ddInactive = Color.gray

        // Emergency color
        static let emergency = Color.red
    }

    // MARK: - Typography

    struct Typography {
        // Standard text styles
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2

        // Custom styles
        static let button = Font.headline
        static let badge = Font.caption2.weight(.semibold)
        static let sectionHeader = Font.headline
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48

        // Specific use cases
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let listItemSpacing: CGFloat = 12
        static let buttonPadding: CGFloat = 16
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20

        // Specific use cases
        static let button: CGFloat = 12
        static let card: CGFloat = 12
        static let badge: CGFloat = 6
        static let textField: CGFloat = 12
    }

    // MARK: - Shadows

    struct Shadow {
        static let sm = ShadowStyle(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let md = ShadowStyle(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        static let lg = ShadowStyle(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card style with padding, background, and shadow
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    /// Apply primary button style
    func primaryButtonStyle() -> some View {
        self
            .font(AppTheme.Typography.button)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.primary)
            .cornerRadius(AppTheme.CornerRadius.button)
    }

    /// Apply section header style
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Text Field Styles

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.textField)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Card Modifier

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Spacing.cardPadding)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.card)
            .shadow(
                color: AppTheme.Shadow.md.color,
                radius: AppTheme.Shadow.md.radius,
                x: AppTheme.Shadow.md.x,
                y: AppTheme.Shadow.md.y
            )
    }
}

// MARK: - Section Header Style

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.sectionHeader)
            .foregroundColor(AppTheme.Colors.primaryText)
            .textCase(nil)
    }
}

// MARK: - Legacy Theme Extension (for backward compatibility)

extension Color {
    struct theme {
        static let text = AppTheme.Colors.primaryText
        static let textSecondary = AppTheme.Colors.secondaryText
        static let background = AppTheme.Colors.background
        static let cardBackground = AppTheme.Colors.cardBackground
        static let error = AppTheme.Colors.danger
        static let success = AppTheme.Colors.success
        static let warning = AppTheme.Colors.warning
    }
}

//
//  Extensions.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

// MARK: - Date Extensions

extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    func formattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - String Extensions

extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }

    var isValidKSUEmail: Bool {
        return isValidEmail && lowercased().hasSuffix(Constants.Validation.emailDomain)
    }

    var isValidPhoneNumber: Bool {
        let phoneRegex = Constants.Validation.phoneNumberRegex
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }

    func formattedPhoneNumber() -> String {
        let digits = self.filter { $0.isNumber }

        guard digits.count == 11, digits.hasPrefix("1") else {
            return self
        }

        let areaCode = digits[digits.index(digits.startIndex, offsetBy: 1)..<digits.index(digits.startIndex, offsetBy: 4)]
        let prefix = digits[digits.index(digits.startIndex, offsetBy: 4)..<digits.index(digits.startIndex, offsetBy: 7)]
        let suffix = digits[digits.index(digits.startIndex, offsetBy: 7)..<digits.index(digits.startIndex, offsetBy: 11)]

        return "+1 (\(areaCode)) \(prefix)-\(suffix)"
    }
}

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Custom Shapes

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Color Extensions

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    let primary = Color("PrimaryColor")
    let secondary = Color("SecondaryColor")
    let background = Color("BackgroundColor")
    let cardBackground = Color("CardBackgroundColor")
    let text = Color("TextColor")
    let textSecondary = Color("TextSecondaryColor")
    let success = Color.green
    let warning = Color.orange
    let error = Color.red
}

// MARK: - Double Extensions

extension Double {
    func formattedDistance() -> String {
        if self < 1000 {
            return String(format: "%.0f m", self)
        } else {
            return String(format: "%.1f km", self / 1000)
        }
    }

    func formattedDuration() -> String {
        let minutes = Int(self / 60)

        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
}

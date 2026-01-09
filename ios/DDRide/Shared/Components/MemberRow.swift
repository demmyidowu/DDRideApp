//
//  MemberRow.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable member row component for displaying users in lists
///
/// Usage:
/// ```swift
/// MemberRow(user: user)
/// MemberRow(user: user, onTap: { selectedUser = user })
/// ```
struct MemberRow: View {
    let user: User
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Profile photo or initials
                initialsView

                // Member info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        // Role badge
                        RoleBadge(role: user.role)
                    }

                    HStack {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        // Class year badge
                        ClassYearBadge(classYear: user.classYear)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.name), \(user.role.displayName), \(yearName(for: user.classYear))")
    }

    private var initialsView: some View {
        Text(user.initials)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private func yearName(for classYear: Int) -> String {
        switch classYear {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "Unknown"
        }
    }
}

// MARK: - Helper Components

/// Role badge component
struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
            .accessibilityLabel("Role: \(role.displayName)")
    }

    private var backgroundColor: Color {
        switch role {
        case .admin: return .purple
        case .member: return .blue
        }
    }
}

/// Class year badge component
struct ClassYearBadge: View {
    let classYear: Int

    var body: some View {
        Text(yearName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(4)
            .accessibilityLabel("Year: \(yearName)")
    }

    private var yearName: String {
        switch classYear {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "Unknown"
        }
    }
}

// MARK: - User Extension

extension User {
    /// Generate initials from user's name
    var initials: String {
        let components = name.components(separatedBy: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return initials.joined()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        MemberRow(user: User(
            id: "1",
            name: "John Doe",
            email: "john.doe@ksu.edu",
            phoneNumber: "+15551234567",
            chapterId: "chapter1",
            role: .admin,
            classYear: 3,
            isEmailVerified: true,
            createdAt: Date(),
            updatedAt: Date()
        ))

        MemberRow(user: User(
            id: "2",
            name: "Jane Smith",
            email: "jane.smith@ksu.edu",
            phoneNumber: "+15559876543",
            chapterId: "chapter1",
            role: .member,
            classYear: 1,
            isEmailVerified: true,
            createdAt: Date(),
            updatedAt: Date()
        ))

        Divider()

        HStack {
            RoleBadge(role: .admin)
            RoleBadge(role: .member)
            ClassYearBadge(classYear: 4)
            ClassYearBadge(classYear: 1)
        }
    }
    .padding()
}

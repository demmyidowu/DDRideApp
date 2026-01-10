//
//  RoleBadge.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(AppTheme.Typography.badge)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(AppTheme.CornerRadius.badge)
    }

    private var badgeColor: Color {
        switch role {
        case .admin:
            return AppTheme.Colors.primary
        case .member:
            return AppTheme.Colors.secondary
        }
    }
}

struct ClassYearBadge: View {
    let classYear: Int

    var body: some View {
        Text(classYearName)
            .font(AppTheme.Typography.badge)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(AppTheme.CornerRadius.badge)
    }

    private var classYearName: String {
        switch classYear {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "Unknown"
        }
    }

    private var badgeColor: Color {
        switch classYear {
        case 1: return Color.green
        case 2: return Color.blue
        case 3: return Color.orange
        case 4: return Color.purple
        default: return Color.gray
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            RoleBadge(role: .admin)
            RoleBadge(role: .member)
        }

        HStack {
            ClassYearBadge(classYear: 1)
            ClassYearBadge(classYear: 2)
            ClassYearBadge(classYear: 3)
            ClassYearBadge(classYear: 4)
        }
    }
    .padding()
}

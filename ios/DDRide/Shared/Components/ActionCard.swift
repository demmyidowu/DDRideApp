//
//  ActionCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color
    var badgeCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(color)

                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 12, y: -12)
                    }
                }

                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(badgeCount > 0 ? "\(badgeCount) notifications" : "")
    }
}

#Preview {
    VStack {
        ActionCard(
            title: "Create Event",
            icon: "calendar.badge.plus",
            color: .blue,
            action: {}
        )

        ActionCard(
            title: "View Alerts",
            icon: "bell.fill",
            color: .orange,
            badgeCount: 5,
            action: {}
        )
    }
    .padding()
}

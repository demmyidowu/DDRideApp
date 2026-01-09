//
//  NextRideCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI
import FirebaseFirestore

/// Card component showing the next ride in queue
///
/// Displays a smaller preview of the upcoming ride
struct NextRideCard: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Next Ride")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if ride.isEmergency {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Pickup location
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pickup")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(ride.pickupAddress)
                        .font(.subheadline)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Time info
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Requested \(formatRelativeTime(ride.requestedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next ride: \(ride.pickupAddress). Requested \(formatRelativeTime(ride.requestedAt))")
    }

    // MARK: - Helper Methods

    /// Format relative time (e.g., "5 min ago", "just now")
    private func formatRelativeTime(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        let minutes = Int(seconds / 60)

        if minutes < 1 {
            return "just now"
        } else if minutes == 1 {
            return "1 min ago"
        } else if minutes < 60 {
            return "\(minutes) min ago"
        } else {
            let hours = minutes / 60
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        NextRideCard(
            ride: Ride(
                id: "2",
                riderId: "rider2",
                ddId: "dd1",
                chapterId: "chapter1",
                eventId: "event1",
                pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717),
                pickupAddress: "789 Fraternity Row, Manhattan, KS 66502",
                dropoffAddress: "Campus Area",
                status: .assigned,
                priority: 35.0,
                isEmergency: false,
                requestedAt: Date().addingTimeInterval(-180), // 3 min ago
                assignedAt: nil,
                enrouteAt: nil,
                completedAt: nil,
                cancelledAt: nil,
                cancellationReason: nil,
                notes: nil
            )
        )

        NextRideCard(
            ride: Ride(
                id: "3",
                riderId: "rider3",
                ddId: "dd1",
                chapterId: "chapter1",
                eventId: "event1",
                pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717),
                pickupAddress: "Emergency Location, Manhattan, KS 66502",
                dropoffAddress: nil,
                status: .assigned,
                priority: 9999,
                isEmergency: true,
                requestedAt: Date().addingTimeInterval(-60),
                assignedAt: nil,
                enrouteAt: nil,
                completedAt: nil,
                cancelledAt: nil,
                cancellationReason: nil,
                notes: nil
            )
        )
    }
    .padding()
}

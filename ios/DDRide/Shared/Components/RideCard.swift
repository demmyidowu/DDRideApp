//
//  RideCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Reusable ride card component for displaying rides in lists
///
/// Usage:
/// ```swift
/// RideCard(ride: ride)
/// RideCard(ride: ride, showDD: false, onTap: { selectedRide = ride })
/// ```
struct RideCard: View {
    let ride: Ride
    var showDD: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Rider name and status
                HStack {
                    Text(riderName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    RideStatusBadge(status: ride.status, isEmergency: ride.isEmergency)
                }

                // Pickup address
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.body)
                        .accessibilityHidden(true)

                    Text(ride.pickupAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Dropoff address (if available)
                if let dropoffAddress = ride.dropoffAddress {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "flag.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                            .accessibilityHidden(true)

                        Text(dropoffAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // DD info (if assigned and showDD is true)
                if showDD, ride.ddId != nil, ride.status != .queued {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.green)
                            .accessibilityHidden(true)

                        Text("Assigned to DD")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let eta = ride.estimatedWaitTime {
                            Text("• ETA: \(eta) min")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Priority indicator (for high priority or emergency)
                if ride.isEmergency || ride.priority > 100 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .accessibilityHidden(true)

                        Text(ride.isEmergency ? "EMERGENCY" : "High Priority (\(Int(ride.priority)))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }

                // Bottom row: Timestamp and queue position
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .accessibilityHidden(true)

                    Text(ride.requestedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let queuePosition = ride.queuePosition, ride.status == .queued {
                        Text("Position: \(queuePosition)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var riderName: String {
        // In a real app, you'd fetch the rider's name from the User document
        // For now, we'll show "Rider" as placeholder
        return "Rider"
    }

    private var accessibilityDescription: String {
        var description = "\(riderName), \(ride.status.displayName)"

        if ride.isEmergency {
            description += ", Emergency"
        }

        description += ", Pickup: \(ride.pickupAddress)"

        if let queuePosition = ride.queuePosition, ride.status == .queued {
            description += ", Position \(queuePosition) in queue"
        }

        return description
    }
}

// MARK: - Ride Status Badge

/// Badge showing ride status with color coding
struct RideStatusBadge: View {
    let status: RideStatus
    let isEmergency: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isEmergency {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
            }
            Text(status.displayName)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(6)
        .accessibilityLabel(isEmergency ? "Emergency, \(status.displayName)" : status.displayName)
    }

    private var backgroundColor: Color {
        if isEmergency { return .red }

        switch status {
        case .queued: return .orange
        case .assigned: return .blue
        case .enroute: return .green
        case .completed: return .gray
        case .cancelled: return .red.opacity(0.7)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Queued ride
            RideCard(ride: Ride(
                id: "1",
                riderId: "rider1",
                ddId: nil,
                chapterId: "chapter1",
                eventId: "event1",
                pickupLocation: .init(latitude: 39.1836, longitude: -96.5717),
                pickupAddress: "1234 College Ave, Manhattan, KS 66502",
                dropoffAddress: nil,
                status: .queued,
                priority: 45.5,
                isEmergency: false,
                estimatedWaitTime: nil,
                queuePosition: 3,
                requestedAt: Date().addingTimeInterval(-600)
            ))

            // Emergency ride
            RideCard(ride: Ride(
                id: "2",
                riderId: "rider2",
                ddId: "dd1",
                chapterId: "chapter1",
                eventId: "event1",
                pickupLocation: .init(latitude: 39.1836, longitude: -96.5717),
                pickupAddress: "5678 University Dr, Manhattan, KS 66502",
                dropoffAddress: "999 Campus Way, Manhattan, KS 66502",
                status: .assigned,
                priority: 9999,
                isEmergency: true,
                estimatedWaitTime: 5,
                queuePosition: nil,
                requestedAt: Date().addingTimeInterval(-300)
            ))

            // En route ride
            RideCard(ride: Ride(
                id: "3",
                riderId: "rider3",
                ddId: "dd2",
                chapterId: "chapter1",
                eventId: "event1",
                pickupLocation: .init(latitude: 39.1836, longitude: -96.5717),
                pickupAddress: "789 Fraternity Ln, Manhattan, KS 66502",
                dropoffAddress: "456 Sorority Row, Manhattan, KS 66502",
                status: .enroute,
                priority: 35.0,
                isEmergency: false,
                estimatedWaitTime: 8,
                queuePosition: nil,
                requestedAt: Date().addingTimeInterval(-900),
                assignedAt: Date().addingTimeInterval(-600),
                enrouteAt: Date().addingTimeInterval(-300)
            ))

            // Badge examples
            HStack(spacing: 12) {
                RideStatusBadge(status: .queued, isEmergency: false)
                RideStatusBadge(status: .assigned, isEmergency: false)
                RideStatusBadge(status: .enroute, isEmergency: false)
                RideStatusBadge(status: .completed, isEmergency: false)
                RideStatusBadge(status: .queued, isEmergency: true)
            }
        }
        .padding()
    }
}

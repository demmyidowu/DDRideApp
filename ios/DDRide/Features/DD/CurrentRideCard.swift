//
//  CurrentRideCard.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI
import MapKit
import FirebaseFirestore

/// Card component displaying current ride with action buttons
///
/// Props:
/// - ride: The current ride
/// - riderName: Rider's name (cached for performance)
/// - onMarkEnRoute: Callback when DD marks en route
/// - onComplete: Callback when DD completes ride
/// - isLoading: Loading state for buttons
struct CurrentRideCard: View {
    let ride: Ride
    let riderName: String
    let onMarkEnRoute: () -> Void
    let onComplete: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rider info header
            riderInfoSection

            Divider()

            // Location info
            locationInfoSection

            // Notes (if provided)
            if let notes = ride.notes, !notes.isEmpty {
                Divider()
                notesSection(notes: notes)
            }

            Divider()

            // Action buttons
            actionButtonsSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Rider Info Section

    private var riderInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(riderName)
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)

                    Text("Requested \(formatRelativeTime(ride.requestedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rider: \(riderName). Requested \(formatRelativeTime(ride.requestedAt))")
    }

    // MARK: - Location Info Section

    private var locationInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pickup location
            LocationRow(
                icon: "mappin.circle.fill",
                iconColor: .green,
                title: "Pickup",
                address: ride.pickupAddress
            )

            // Dropoff location (if provided)
            if let dropoffAddress = ride.dropoffAddress, !dropoffAddress.isEmpty {
                LocationRow(
                    icon: "mappin.circle.fill",
                    iconColor: .blue,
                    title: "Dropoff",
                    address: dropoffAddress
                )
            }

            // ETA display (if en route)
            if ride.status == .enroute, let eta = ride.estimatedWaitTime {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)

                    Text("ETA: \(eta) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Notes Section

    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)

                Text("Notes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(notes)
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if ride.status == .assigned {
                // "On My Way" button
                Button(action: onMarkEnRoute) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "car.fill")
                            Text("On My Way")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .accessibilityLabel("Mark as on my way")
                .accessibilityHint("Captures your location and notifies the rider")
            } else if ride.status == .enroute {
                // "Complete Ride" button
                Button(action: onComplete) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Ride")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .accessibilityLabel("Complete ride")
                .accessibilityHint("Marks the ride as completed")
            }

            // "Open in Maps" button (always available)
            Button(action: openInAppleMaps) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("Open in Maps")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
            }
            .accessibilityLabel("Open pickup location in Apple Maps")
        }
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

    /// Open pickup location in Apple Maps for navigation
    private func openInAppleMaps() {
        let coordinate = ride.pickupLocation.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = ride.pickupAddress

        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        mapItem.openInMaps(launchOptions: launchOptions)
    }
}

// MARK: - Supporting Views

/// Location row component (reusable for pickup/dropoff)
struct LocationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let address: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(address)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(address)")
    }
}

// MARK: - Preview

#Preview("Assigned Ride") {
    CurrentRideCard(
        ride: Ride(
            id: "1",
            riderId: "rider1",
            ddId: "dd1",
            chapterId: "chapter1",
            eventId: "event1",
            pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            pickupAddress: "123 Main St, Manhattan, KS 66502",
            dropoffAddress: "456 College Ave, Manhattan, KS 66502",
            status: .assigned,
            priority: 42.5,
            isEmergency: false,
            requestedAt: Date().addingTimeInterval(-300), // 5 min ago
            assignedAt: Date().addingTimeInterval(-60),
            enrouteAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            cancellationReason: nil,
            notes: "Please hurry!"
        ),
        riderName: "John Doe",
        onMarkEnRoute: { print("Mark en route") },
        onComplete: { print("Complete") },
        isLoading: false
    )
    .padding()
}

#Preview("En Route") {
    CurrentRideCard(
        ride: Ride(
            id: "1",
            riderId: "rider1",
            ddId: "dd1",
            chapterId: "chapter1",
            eventId: "event1",
            pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            pickupAddress: "123 Main St, Manhattan, KS 66502",
            dropoffAddress: nil,
            status: .enroute,
            priority: 42.5,
            isEmergency: false,
            estimatedWaitTime: 8,
            requestedAt: Date().addingTimeInterval(-600),
            assignedAt: Date().addingTimeInterval(-300),
            enrouteAt: Date().addingTimeInterval(-120),
            completedAt: nil,
            cancelledAt: nil,
            cancellationReason: nil,
            notes: nil
        ),
        riderName: "Jane Smith",
        onMarkEnRoute: { print("Mark en route") },
        onComplete: { print("Complete") },
        isLoading: false
    )
    .padding()
}

#Preview("Emergency") {
    CurrentRideCard(
        ride: Ride(
            id: "1",
            riderId: "rider1",
            ddId: "dd1",
            chapterId: "chapter1",
            eventId: "event1",
            pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            pickupAddress: "789 Emergency Lane, Manhattan, KS 66502",
            dropoffAddress: "Emergency Room, Manhattan, KS 66502",
            status: .assigned,
            priority: 9999,
            isEmergency: true,
            requestedAt: Date().addingTimeInterval(-60),
            assignedAt: Date(),
            enrouteAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            cancellationReason: nil,
            notes: "EMERGENCY: Safety concern!"
        ),
        riderName: "Emergency Rider",
        onMarkEnRoute: { print("Mark en route") },
        onComplete: { print("Complete") },
        isLoading: false
    )
    .padding()
}

//
//  ActiveRideView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI
import MapKit

/// Detail view for an active ride
///
/// Shows:
/// - Ride status badge
/// - DD information (when assigned)
/// - Pickup/dropoff locations
/// - ETA countdown (when en route)
/// - Map preview (when en route)
/// - Actions (cancel, call DD, report issue)
struct ActiveRideView: View {
    let ride: Ride
    @ObservedObject var viewModel: RiderViewModel

    @State private var ddInfo: User?
    @State private var showCancelConfirmation = false
    @State private var showReportIssue = false
    @State private var region = MKCoordinateRegion()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with status
                statusHeader

                // Emergency badge if applicable
                if ride.isEmergency {
                    EmergencyBadge()
                }

                // DD Information (when assigned)
                if ride.ddId != nil {
                    ddInformationSection
                }

                // Location information
                locationSection

                // Status-specific content
                statusContent

                // Actions
                actionsSection

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Your Ride")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDDInfo()
        }
        .alert("Cancel Ride", isPresented: $showCancelConfirmation) {
            Button("Cancel Ride", role: .destructive) {
                Task {
                    await viewModel.cancelRide()
                }
            }
            Button("Keep Ride", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this ride?")
        }
        .sheet(isPresented: $showReportIssue) {
            ReportIssueView(rideId: ride.id)
        }
    }

    // MARK: - Subviews

    private var statusHeader: some View {
        VStack(spacing: 12) {
            StatusBadge(status: ride.status)
                .font(.headline)

            if let position = viewModel.queuePosition, ride.status == .queued {
                Text("Position in Queue")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(position.ordinal)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            if let waitTime = viewModel.estimatedWaitTime {
                Text("Estimated wait: ~\(waitTime) min")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var ddInformationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Driver")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 16) {
                // Profile photo or placeholder
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    if let dd = ddInfo {
                        Text(dd.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        // TODO: Add car description from DD profile
                        // Text("Red Honda Civic")
                        //     .font(.subheadline)
                        //     .foregroundColor(.secondary)

                        if ride.status == .enroute || ride.status == .assigned {
                            Button {
                                callDD()
                            } label: {
                                Label("Call Driver", systemImage: "phone.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                            }
                            .accessibilityLabel("Call driver \(dd.name)")
                        }
                    } else {
                        ProgressView()
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location Details")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            // Pickup location
            LocationRow(
                icon: "mappin.circle.fill",
                title: "Pickup",
                address: ride.pickupAddress,
                color: .green
            )

            // Dropoff location (if provided)
            if let dropoffAddress = ride.dropoffAddress {
                LocationRow(
                    icon: "mappin.circle.fill",
                    title: "Dropoff",
                    address: dropoffAddress,
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var statusContent: some View {
        Group {
            switch ride.status {
            case .queued:
                queuedContent
            case .assigned:
                assignedContent
            case .enroute:
                enRouteContent
            case .completed, .cancelled:
                EmptyView()
            }
        }
    }

    private var queuedContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Finding a driver...")
                .font(.headline)

            Text("You'll be notified when a DD accepts your ride")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var assignedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("Driver Assigned!")
                .font(.headline)

            Text("Your DD is preparing to pick you up")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var enRouteContent: some View {
        VStack(spacing: 16) {
            // ETA display
            if let waitTime = viewModel.estimatedWaitTime {
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)

                    Text("On the way!")
                        .font(.headline)

                    Text("~\(waitTime) min")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.accentColor)

                    Text("Estimated arrival time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // TODO: Add map preview when DD location is available
            // For now, show placeholder
            // mapPreview
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Cancel ride button
            if ride.status == .queued || ride.status == .assigned {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Label("Cancel Ride", systemImage: "xmark.circle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Cancel ride")
            }

            // Report issue button
            Button {
                showReportIssue = true
            } label: {
                Label("Report Issue", systemImage: "exclamationmark.bubble")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Report issue")
        }
    }

    // MARK: - Helper Methods

    private func loadDDInfo() async {
        guard let ddId = ride.ddId else { return }

        do {
            ddInfo = try await FirestoreService.shared.fetchUser(id: ddId)
        } catch {
            print("Failed to load DD info: \(error.localizedDescription)")
        }
    }

    private func callDD() {
        guard let dd = ddInfo else { return }

        // Remove non-numeric characters and format for tel: URL
        let phoneNumber = dd.phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        if let url = URL(string: "tel://\(phoneNumber)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Supporting Views

/// Location row with icon and address
struct LocationRow: View {
    let icon: String
    let title: String
    let address: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(address)
                    .font(.subheadline)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(address)")
    }
}

/// Simple report issue view (placeholder)
struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    let rideId: String

    @State private var issue: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Describe the issue you're experiencing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                TextEditor(text: $issue)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                Spacer()

                Button {
                    // TODO: Submit issue report
                    dismiss()
                } label: {
                    Text("Submit Report")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .disabled(issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Extensions

extension Int {
    /// Convert number to ordinal string (1st, 2nd, 3rd, etc.)
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    NavigationStack {
        ActiveRideView(
            ride: Ride(
                id: "preview-ride",
                riderId: "user123",
                ddId: "dd123",
                chapterId: "chapter123",
                eventId: "event123",
                pickupLocation: .init(latitude: 39.1836, longitude: -96.5717),
                pickupAddress: "123 Main St, Manhattan, KS",
                dropoffAddress: "456 Oak Ave, Manhattan, KS",
                status: .enroute,
                priority: 42.5,
                isEmergency: false,
                estimatedWaitTime: 12,
                queuePosition: 3,
                requestedAt: Date(),
                assignedAt: Date(),
                enrouteAt: Date(),
                completedAt: nil,
                cancelledAt: nil,
                cancellationReason: nil,
                notes: nil
            ),
            viewModel: RiderViewModel()
        )
    }
}

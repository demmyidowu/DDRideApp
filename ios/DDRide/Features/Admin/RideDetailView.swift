//
//  RideDetailView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI
import MapKit

struct RideDetailView: View {
    let rideId: String

    @StateObject private var viewModel = RideDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView(message: "Loading ride details...")
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error, retryAction: {
                    Task { await viewModel.loadRide(rideId: rideId) }
                })
            } else if let ride = viewModel.ride {
                VStack(spacing: 20) {
                    // Status Header
                    statusHeader(ride: ride)

                    // Emergency Badge
                    if ride.isEmergency {
                        emergencyBanner
                    }

                    // Rider Information
                    riderSection(ride: ride)

                    // DD Information
                    if let ddId = ride.ddId {
                        ddSection(ddId: ddId, ride: ride)
                    }

                    // Location Information
                    locationSection(ride: ride)

                    // Timeline
                    timelineSection(ride: ride)

                    // Priority Information
                    prioritySection(ride: ride)

                    // Notes
                    if let notes = ride.notes {
                        notesSection(notes: notes)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRide(rideId: rideId)
        }
    }

    private func statusHeader(ride: Ride) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ride #\(String(ride.id.prefix(8)))")
                    .font(.title3)
                    .bold()

                Text("Requested \(ride.requestedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            StatusBadge(status: ride.status)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emergencyBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text("EMERGENCY RIDE")
                    .font(.headline)
                    .bold()

                Text("High priority - immediate response required")
                    .font(.caption)
            }

            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func riderSection(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rider")
                .font(.headline)

            if let rider = viewModel.rider {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Text(rider.name.prefix(2).uppercased())
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rider.name)
                            .font(.subheadline)
                            .bold()

                        Text(rider.email)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(rider.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            ClassYearBadge(classYear: rider.classYear)
                        }
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func ddSection(ddId: String, ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Designated Driver")
                .font(.headline)

            if let dd = viewModel.dd {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Text(dd.name.prefix(2).uppercased())
                            .font(.headline)
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(dd.name)
                            .font(.subheadline)
                            .bold()

                        Text(dd.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let assignment = viewModel.ddAssignment {
                            if let car = assignment.carDescription {
                                Label(car, systemImage: "car.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if let estimatedWait = ride.estimatedWaitTime {
                        VStack {
                            Text("\(estimatedWait)")
                                .font(.title2)
                                .bold()
                            Text("min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func locationSection(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(ride.pickupAddress)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                }

                if let dropoff = ride.dropoffAddress {
                    Label {
                        Text(dropoff)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func timelineSection(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                TimelineItem(
                    title: "Requested",
                    time: ride.requestedAt,
                    isCompleted: true
                )

                if let assignedAt = ride.assignedAt {
                    TimelineItem(
                        title: "Assigned",
                        time: assignedAt,
                        isCompleted: true
                    )
                }

                if let enrouteAt = ride.enrouteAt {
                    TimelineItem(
                        title: "En Route",
                        time: enrouteAt,
                        isCompleted: true
                    )
                }

                if let completedAt = ride.completedAt {
                    TimelineItem(
                        title: "Completed",
                        time: completedAt,
                        isCompleted: true
                    )
                } else if let cancelledAt = ride.cancelledAt {
                    TimelineItem(
                        title: "Cancelled",
                        time: cancelledAt,
                        isCompleted: true,
                        color: .red
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func prioritySection(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priority Information")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Priority Score")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f", ride.priority))
                        .font(.title2)
                        .bold()
                }

                Spacer()

                if let position = ride.queuePosition {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Queue Position")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("#\(position)")
                            .font(.title2)
                            .bold()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func notesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            Text(notes)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let title: String
    let time: Date
    let isCompleted: Bool
    var color: Color = .blue

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(isCompleted ? color : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - View Model

@MainActor
class RideDetailViewModel: ObservableObject {
    @Published var ride: Ride?
    @Published var rider: User?
    @Published var dd: User?
    @Published var ddAssignment: DDAssignment?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared

    func loadRide(rideId: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Load ride
            ride = try await firestoreService.fetchRide(id: rideId)

            guard let ride else { return }

            // Load rider
            rider = try await firestoreService.fetchUser(id: ride.riderId)

            // Load DD if assigned
            if let ddId = ride.ddId {
                dd = try await firestoreService.fetchUser(id: ddId)

                // Load DD assignment
                ddAssignment = try? await firestoreService.fetchDDAssignment(id: ddId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RideDetailView(rideId: "preview-ride-id")
    }
}

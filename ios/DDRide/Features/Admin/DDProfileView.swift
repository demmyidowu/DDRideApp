//
//  DDProfileView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

struct DDProfileView: View {
    let ddId: String
    let eventId: String

    @StateObject private var viewModel = DDProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView(message: "Loading profile...")
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error, retryAction: {
                    Task { await viewModel.loadData(ddId: ddId, eventId: eventId) }
                })
            } else if let dd = viewModel.dd, let assignment = viewModel.assignment {
                VStack(spacing: 20) {
                    // Profile Header
                    profileHeader(dd: dd, assignment: assignment)

                    // Status Section
                    statusSection(assignment: assignment)

                    // Statistics
                    statisticsSection(assignment: assignment)

                    // Current Rides
                    if !viewModel.currentRides.isEmpty {
                        currentRidesSection
                    }

                    // Recent Rides
                    if !viewModel.recentRides.isEmpty {
                        recentRidesSection
                    }

                    // Activity Monitoring
                    activitySection(assignment: assignment)
                }
                .padding()
            }
        }
        .navigationTitle("DD Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData(ddId: ddId, eventId: eventId)
        }
        .refreshable {
            await viewModel.loadData(ddId: ddId, eventId: eventId)
        }
    }

    private func profileHeader(dd: User, assignment: DDAssignment) -> some View {
        VStack(spacing: 16) {
            // Photo
            if let photoURL = assignment.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))

                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .padding(20)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Text(dd.name.prefix(2).uppercased())
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.accentColor)
                }
            }

            // Name and Info
            VStack(spacing: 4) {
                Text(dd.name)
                    .font(.title2)
                    .bold()

                Text(dd.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(dd.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    ClassYearBadge(classYear: dd.classYear)
                    RoleBadge(role: dd.role)
                }
                .padding(.top, 4)
            }

            // Car Info
            if let car = assignment.carDescription {
                Label(car, systemImage: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No car description provided")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusSection(assignment: DDAssignment) -> some View {
        HStack(spacing: 20) {
            StatusItem(
                title: "Status",
                value: assignment.isActive ? "Active" : "Inactive",
                color: assignment.isActive ? .green : .gray
            )

            Divider()

            StatusItem(
                title: "Last Active",
                value: assignment.lastActiveTimestamp?.formatted(date: .omitted, time: .shortened) ?? "Never",
                color: .blue
            )
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statisticsSection(assignment: DDAssignment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                StatBox(
                    title: "Total Rides",
                    value: "\(assignment.totalRidesCompleted)",
                    icon: "car.fill",
                    color: .blue
                )

                StatBox(
                    title: "Tonight",
                    value: "\(viewModel.ridesCompletedTonight)",
                    icon: "moon.stars.fill",
                    color: .purple
                )

                StatBox(
                    title: "Current",
                    value: "\(viewModel.currentRides.count)",
                    icon: "timer",
                    color: .orange
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var currentRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Rides")
                .font(.headline)

            ForEach(viewModel.currentRides) { ride in
                NavigationLink {
                    RideDetailView(rideId: ride.id)
                } label: {
                    RideCompactRow(ride: ride)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rides")
                .font(.headline)

            ForEach(viewModel.recentRides.prefix(5)) { ride in
                NavigationLink {
                    RideDetailView(rideId: ride.id)
                } label: {
                    RideCompactRow(ride: ride)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func activitySection(assignment: DDAssignment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Monitoring")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Label("Inactive Toggles", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)

                    Spacer()

                    Text("\(assignment.inactiveToggles)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(assignment.inactiveToggles > 5 ? .orange : .primary)
                }

                if assignment.inactiveToggles > 5 {
                    Text("High number of inactive toggles - may require attention")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                if let lastInactive = assignment.lastInactiveTimestamp {
                    HStack {
                        Label("Last Inactive", systemImage: "clock")
                            .font(.subheadline)

                        Spacer()

                        Text(lastInactive.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

struct StatusItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .bold()

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct RideCompactRow: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.pickupAddress)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(ride.requestedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            StatusBadge(status: ride.status)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class DDProfileViewModel: ObservableObject {
    @Published var dd: User?
    @Published var assignment: DDAssignment?
    @Published var currentRides: [Ride] = []
    @Published var recentRides: [Ride] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared

    var ridesCompletedTonight: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return recentRides.filter { ride in
            guard let completedAt = ride.completedAt else { return false }
            return completedAt >= today
        }.count
    }

    func loadData(ddId: String, eventId: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Load DD user
            dd = try await firestoreService.fetchUser(id: ddId)

            // Load DD assignment
            assignment = try await firestoreService.fetchDDAssignment(id: ddId)

            // Load DD rides
            let allRides = try await firestoreService.fetchDDRides(ddId: ddId, eventId: eventId)

            // Separate current and recent
            currentRides = allRides.filter {
                $0.status == .queued || $0.status == .assigned || $0.status == .enroute
            }

            recentRides = allRides.filter {
                $0.status == .completed || $0.status == .cancelled
            }.sorted { ($0.completedAt ?? $0.cancelledAt ?? Date.distantPast) > ($1.completedAt ?? $1.cancelledAt ?? Date.distantPast) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DDProfileView(ddId: "preview-dd-id", eventId: "preview-event-id")
    }
}

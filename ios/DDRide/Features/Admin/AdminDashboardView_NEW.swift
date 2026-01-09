//
//  AdminDashboardView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Main admin dashboard showing event overview, active rides, DD status, and quick actions
/// Features real-time updates and pull-to-refresh
struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showingDeactivateAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Loading dashboard...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(error: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Active Event Section
                            activeEventSection

                            // Quick Actions Grid
                            quickActionsGrid

                            // Active Rides Section
                            activeRidesSection

                            // DD Status Section
                            ddStatusSection
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Admin Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            // Navigate to settings (future implementation)
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("More options")
                    }
                }
            }
            .alert("Deactivate Event", isPresented: $showingDeactivateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Deactivate", role: .destructive) {
                    Task { await viewModel.deactivateEvent() }
                }
            } message: {
                Text("Are you sure you want to deactivate this event? Active rides will be marked as completed.")
            }
            .task {
                await viewModel.loadDashboardData()
            }
        }
    }

    // MARK: - Active Event Section

    @ViewBuilder
    private var activeEventSection: some View {
        if let event = viewModel.activeEvent {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Event")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    StatusBadge(status: event.status)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(event.name)
                        .font(.title2)
                        .bold()

                    Label(event.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let location = event.location {
                        Label(location, systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Quick stats
                    HStack(spacing: 20) {
                        StatLabel(value: "\(viewModel.activeRidesCount)", label: "Active Rides")
                        StatLabel(value: "\(viewModel.activeDDsCount)", label: "DDs Active")
                    }
                    .padding(.top, 8)
                }

                // Deactivate button
                Button {
                    showingDeactivateAlert = true
                } label: {
                    Text("Deactivate Event")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .accessibilityLabel("Deactivate event")
                .accessibilityHint("Marks the event as completed")
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 2)
        } else {
            // No Active Event - Empty State
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "No Active Event",
                message: "Create an event to start managing rides and DDs.",
                action: nil,
                actionTitle: nil
            )
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }

    // MARK: - Quick Actions Grid

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: EventCreationView()) {
                    ActionCard(
                        icon: "calendar.badge.plus",
                        title: "Create Event",
                        badgeCount: nil
                    )
                }

                NavigationLink(destination: MemberManagementView()) {
                    ActionCard(
                        icon: "person.3.fill",
                        title: "Manage Members",
                        badgeCount: nil
                    )
                }

                NavigationLink(destination: AdminAlertsView()) {
                    ActionCard(
                        icon: "bell.fill",
                        title: "View Alerts",
                        badgeCount: viewModel.unreadAlertCount > 0 ? viewModel.unreadAlertCount : nil
                    )
                }

                // Placeholder for future reports
                ActionCard(
                    icon: "chart.bar.fill",
                    title: "Reports",
                    badgeCount: nil
                )
                .opacity(0.5)
                .accessibilityLabel("Reports - Coming soon")
            }
        }
    }

    // MARK: - Active Rides Section

    private var activeRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Rides (\(viewModel.activeRidesCount))")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if viewModel.activeRides.isEmpty {
                EmptyStateView(
                    icon: "car.fill",
                    title: "No Active Rides",
                    message: "All riders have been served."
                )
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.activeRides) { ride in
                        NavigationLink(destination: RideDetailView(ride: ride)) {
                            ActiveRideRow(ride: ride, rider: viewModel.getRider(for: ride), dd: viewModel.getDD(for: ride))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - DD Status Section

    private var ddStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DDs (\(viewModel.activeDDsCount) active / \(viewModel.ddAssignments.count - viewModel.activeDDsCount) inactive)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if viewModel.ddAssignments.isEmpty {
                EmptyStateView(
                    icon: "person.fill.questionmark",
                    title: "No DDs Assigned",
                    message: "Assign DDs to the active event to get started."
                )
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.ddAssignments) { assignment in
                        if let dd = viewModel.getUser(userId: assignment.userId) {
                            NavigationLink(destination: DDProfileView(userId: dd.id)) {
                                DDStatusRow(assignment: assignment, dd: dd)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components

/// Action card for quick actions grid
struct ActionCard: View {
    let icon: String
    let title: String
    let badgeCount: Int?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.subheadline)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 2)

            // Badge overlay
            if let count = badgeCount, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// Active ride row showing rider, status, DD, and priority
struct ActiveRideRow: View {
    let ride: Ride
    let rider: User?
    let dd: User?

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(rider?.name ?? "Unknown Rider")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(ride.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let dd = dd {
                        Text("• DD: \(dd.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if ride.isEmergency {
                    Label("EMERGENCY", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Priority badge
            VStack(alignment: .trailing, spacing: 4) {
                Text("Priority")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f", ride.priority))
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(ride.isEmergency ? Color.red.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private var statusColor: Color {
        switch ride.status {
        case .queued: return .orange
        case .assigned: return .blue
        case .enroute: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

/// DD status row showing name, active status, and ride count
struct DDStatusRow: View {
    let assignment: DDAssignment
    let dd: User

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(assignment.isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(dd.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(assignment.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let car = assignment.carDescription {
                        Text("• \(car)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Ride count
            VStack(alignment: .trailing, spacing: 4) {
                Text("Rides Tonight")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(assignment.totalRidesCompleted)")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

/// Status badge for events
struct StatusBadge: View {
    let status: EventStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }

    private var backgroundColor: Color {
        switch status {
        case .scheduled: return .blue
        case .active: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

/// Stat label for displaying counts
struct StatLabel: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2)
                .bold()
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Error")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Try Again", action: retryAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2)
                .bold()

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    AdminDashboardView()
}

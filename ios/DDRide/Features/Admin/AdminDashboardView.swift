//
//  AdminDashboardView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showingDeactivateConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Loading dashboard...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error, retryAction: {
                        Task { await viewModel.loadDashboardData() }
                    })
                } else {
                    contentView
                }
            }
            .navigationTitle("Admin Dashboard")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $viewModel.showingCreateEvent) {
                EventCreationView()
            }
            .sheet(isPresented: $viewModel.showingManageMembers) {
                MemberManagementView()
            }
            .sheet(isPresented: $viewModel.showingAlerts) {
                AdminAlertsView()
            }
            .alert("Deactivate Event", isPresented: $showingDeactivateConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Deactivate", role: .destructive) {
                    Task { await viewModel.deactivateEvent() }
                }
            } message: {
                Text("Are you sure you want to deactivate the current event? All active rides will be affected.")
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
        }
        .task {
            await viewModel.loadDashboardData()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Event Section
                activeEventSection

                // Quick Actions Grid
                quickActionsGrid

                // Active Rides Section
                if !viewModel.activeRides.isEmpty {
                    activeRidesSection
                }

                // DD Status Section
                if !viewModel.ddAssignments.isEmpty {
                    ddStatusSection
                }
            }
            .padding()
        }
    }

    private var activeEventSection: some View {
        Group {
            if let event = viewModel.activeEvent {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.name)
                                .font(.title2)
                                .bold()

                            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let location = event.location {
                                Label(location, systemImage: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            StatusBadge(status: event.status)

                            Button {
                                showingDeactivateConfirmation = true
                            } label: {
                                Text("Deactivate")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()

                    Divider()

                    HStack(spacing: 40) {
                        StatItemView(
                            title: "Active Rides",
                            value: "\(viewModel.activeRidesCount)",
                            icon: "car.fill",
                            color: .blue
                        )

                        StatItemView(
                            title: "Active DDs",
                            value: "\(viewModel.activeDDsCount)",
                            icon: "person.fill.checkmark",
                            color: .green
                        )
                    }
                    .padding()
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Active Event",
                    message: "Create an event to start accepting ride requests",
                    action: { viewModel.showingCreateEvent = true },
                    actionTitle: "Create Event"
                )
            }
        }
    }

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActionCard(
                    title: "Create Event",
                    icon: "calendar.badge.plus",
                    color: .blue
                ) {
                    viewModel.showingCreateEvent = true
                }

                ActionCard(
                    title: "Manage Members",
                    icon: "person.3.fill",
                    color: .purple
                ) {
                    viewModel.showingManageMembers = true
                }

                ActionCard(
                    title: "View Alerts",
                    icon: "bell.fill",
                    color: .orange,
                    badgeCount: viewModel.unreadAlertCount
                ) {
                    viewModel.showingAlerts = true
                }

                ActionCard(
                    title: "View Reports",
                    icon: "chart.bar.fill",
                    color: .green
                ) {
                    // TODO: Navigate to reports
                }
            }
        }
    }

    private var activeRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Rides")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(viewModel.activeRides.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.activeRides) { ride in
                    NavigationLink {
                        RideDetailView(rideId: ride.id)
                    } label: {
                        RideRowView(ride: ride, viewModel: viewModel)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var ddStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Designated Drivers")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(viewModel.activeDDsCount)/\(viewModel.ddAssignments.count) Active")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.ddAssignments) { assignment in
                    NavigationLink {
                        DDProfileView(ddId: assignment.userId, eventId: assignment.eventId)
                    } label: {
                        DDRowView(assignment: assignment, viewModel: viewModel)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    viewModel.showingCreateEvent = true
                } label: {
                    Label("Create Event", systemImage: "calendar.badge.plus")
                }

                Button {
                    viewModel.showingManageMembers = true
                } label: {
                    Label("Manage Members", systemImage: "person.3.fill")
                }

                Divider()

                Button {
                    // TODO: Navigate to settings
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("More options")
            }
        }

        if viewModel.unreadAlertCount > 0 {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.showingAlerts = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)

                        if viewModel.unreadAlertCount > 0 {
                            Text("\(viewModel.unreadAlertCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .accessibilityLabel("Alerts")
                .accessibilityHint("\(viewModel.unreadAlertCount) unread alerts")
            }
        }
    }
}

// MARK: - Supporting Views

struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .bold()

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct RideRowView: View {
    let ride: Ride
    @ObservedObject var viewModel: AdminViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(ride.isEmergency ? Color.red : priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.getRiderName(riderId: ride.riderId))
                        .font(.subheadline)
                        .bold()

                    if ride.isEmergency {
                        Text("EMERGENCY")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }

                Text(ride.pickupAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: ride.status)

                if let ddId = ride.ddId {
                    Text(viewModel.getDDName(ddId: ddId))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(ride.isEmergency ? Color.red.opacity(0.1) : Color.clear)
    }

    private var priorityColor: Color {
        if ride.priority > 50 {
            return .orange
        } else if ride.priority > 30 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct DDRowView: View {
    let assignment: DDAssignment
    @ObservedObject var viewModel: AdminViewModel

    var body: some View {
        HStack(spacing: 12) {
            // DD Photo
            if let photoURL = assignment.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.getDDName(ddId: assignment.userId))
                    .font(.subheadline)
                    .bold()

                if let car = assignment.carDescription {
                    Text(car)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(assignment.isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(assignment.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(assignment.isActive ? .green : .secondary)
                }

                Text("\(viewModel.getDDRideCount(ddId: assignment.userId)) rides")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct StatusBadge: View {
    let status: any RawRepresentable

    var body: some View {
        Text(displayText)
            .font(.caption2)
            .bold()
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }

    private var displayText: String {
        if let rideStatus = status as? RideStatus {
            return rideStatus.displayName.uppercased()
        } else if let eventStatus = status as? EventStatus {
            return eventStatus.displayName.uppercased()
        }
        return "UNKNOWN"
    }

    private var backgroundColor: Color {
        if let rideStatus = status as? RideStatus {
            switch rideStatus {
            case .queued: return .blue
            case .assigned: return .orange
            case .enroute: return .purple
            case .completed: return .green
            case .cancelled: return .gray
            }
        } else if let eventStatus = status as? EventStatus {
            switch eventStatus {
            case .scheduled: return .blue
            case .active: return .green
            case .completed: return .gray
            case .cancelled: return .red
            }
        }
        return .gray
    }
}

#Preview {
    AdminDashboardView()
}

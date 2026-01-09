//
//  AdminAlertsView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

struct AdminAlertsView: View {
    @StateObject private var viewModel = AdminAlertsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Loading alerts...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error, retryAction: {
                        Task { await viewModel.loadAlerts() }
                    })
                } else {
                    contentView
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .refreshable {
                await viewModel.loadAlerts()
            }
        }
        .task {
            await viewModel.loadAlerts()
        }
    }

    private var contentView: some View {
        Group {
            if viewModel.filteredAlerts.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Alerts",
                    message: viewModel.filterType == nil ? "You're all caught up!" : "No \(viewModel.filterType?.displayName.lowercased() ?? "") alerts"
                )
            } else {
                alertsList
            }
        }
    }

    private var alertsList: some View {
        List {
            // Filter section
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: viewModel.filterType == nil,
                            count: viewModel.alerts.count
                        ) {
                            viewModel.filterType = nil
                        }

                        ForEach(AlertType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.displayName,
                                isSelected: viewModel.filterType == type,
                                count: viewModel.getAlertCount(for: type),
                                color: colorForAlertType(type)
                            ) {
                                viewModel.filterType = type
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Alerts
            ForEach(viewModel.filteredAlerts) { alert in
                NavigationLink {
                    AlertDetailView(alert: alert, viewModel: viewModel)
                } label: {
                    AlertRow(alert: alert)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                dismiss()
            }
        }

        if !viewModel.alerts.filter({ !$0.isRead }).isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button("Mark All Read") {
                    Task {
                        await viewModel.markAllAsRead()
                    }
                }
            }
        }
    }

    private func colorForAlertType(_ type: AlertType) -> Color {
        switch type {
        case .emergencyRide: return .red
        case .ddInactiveToggle: return .orange
        case .ddProlongedInactive: return .yellow
        case .systemError: return .gray
        }
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let alert: AdminAlert

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconForType(alert.type))
                .font(.title2)
                .foregroundColor(colorForType(alert.type))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.message)
                    .font(.subheadline)
                    .lineLimit(2)

                Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !alert.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: AlertType) -> String {
        switch type {
        case .emergencyRide: return "exclamationmark.triangle.fill"
        case .ddInactiveToggle: return "arrow.triangle.2.circlepath"
        case .ddProlongedInactive: return "clock.badge.exclamationmark"
        case .systemError: return "xmark.octagon.fill"
        }
    }

    private func colorForType(_ type: AlertType) -> Color {
        switch type {
        case .emergencyRide: return .red
        case .ddInactiveToggle: return .orange
        case .ddProlongedInactive: return .yellow
        case .systemError: return .gray
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var count: Int = 0
    var color: Color = .blue

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("(\(count))")
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Alert Detail View

struct AlertDetailView: View {
    let alert: AdminAlert
    @ObservedObject var viewModel: AdminAlertsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Alert Type Badge
                HStack {
                    Image(systemName: iconForType(alert.type))
                        .font(.title)
                        .foregroundColor(colorForType(alert.type))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.type.displayName)
                            .font(.title3)
                            .bold()

                        Text(alert.createdAt.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)

                    Text(alert.message)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Related Information
                if alert.ddId != nil || alert.rideId != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Related")
                            .font(.headline)

                        if let ddId = alert.ddId {
                            NavigationLink {
                                // DD Profile View - placeholder
                                Text("DD Profile: \(ddId)")
                            } label: {
                                Label("View DD Profile", systemImage: "person.circle")
                            }
                        }

                        if let rideId = alert.rideId {
                            NavigationLink {
                                RideDetailView(rideId: rideId)
                            } label: {
                                Label("View Ride Details", systemImage: "car.circle")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Actions
                if !alert.isRead {
                    Button {
                        Task {
                            await viewModel.markAsRead(alert)
                            dismiss()
                        }
                    } label: {
                        Text("Mark as Read")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Alert Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !alert.isRead {
                await viewModel.markAsRead(alert)
            }
        }
    }

    private func iconForType(_ type: AlertType) -> String {
        switch type {
        case .emergencyRide: return "exclamationmark.triangle.fill"
        case .ddInactiveToggle: return "arrow.triangle.2.circlepath"
        case .ddProlongedInactive: return "clock.badge.exclamationmark"
        case .systemError: return "xmark.octagon.fill"
        }
    }

    private func colorForType(_ type: AlertType) -> Color {
        switch type {
        case .emergencyRide: return .red
        case .ddInactiveToggle: return .orange
        case .ddProlongedInactive: return .yellow
        case .systemError: return .gray
        }
    }
}

// MARK: - View Model

@MainActor
class AdminAlertsViewModel: ObservableObject {
    @Published var alerts: [AdminAlert] = []
    @Published var filterType: AlertType?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    var filteredAlerts: [AdminAlert] {
        if let filterType {
            return alerts.filter { $0.type == filterType }
        }
        return alerts
    }

    func getAlertCount(for type: AlertType) -> Int {
        alerts.filter { $0.type == type }.count
    }

    func loadAlerts() async {
        guard let chapterId = authService.currentUser?.chapterId else {
            errorMessage = "No chapter ID found"
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            alerts = try await firestoreService.fetchAdminAlerts(chapterId: chapterId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAsRead(_ alert: AdminAlert) async {
        do {
            try await firestoreService.markAlertAsRead(id: alert.id)

            // Update local state
            if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[index].isRead = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        for alert in alerts where !alert.isRead {
            try? await firestoreService.markAlertAsRead(id: alert.id)
        }

        // Reload alerts
        await loadAlerts()
    }
}

#Preview {
    AdminAlertsView()
}

//
//  DDDashboardView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Main DD dashboard view
///
/// Features:
/// - Large "I'm Active" toggle switch
/// - Profile requirements warning (if needed)
/// - Current ride card with actions
/// - Next ride preview
/// - Statistics (tonight and total rides)
struct DDDashboardView: View {
    @StateObject private var viewModel = DDViewModel()
    @State private var showPhotoUpload = false
    @State private var showInactiveToggleAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.ddAssignment == nil {
                    LoadingView(message: "Loading dashboard...")
                } else if viewModel.ddAssignment == nil {
                    noAssignmentView
                } else {
                    mainContent
                }
            }
            .navigationTitle("DD Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPhotoUpload) {
                DDPhotoUploadView(viewModel: viewModel)
            }
            .alert("Excessive Toggle Warning", isPresented: $showInactiveToggleAlert) {
                Button("I Understand", role: .cancel) {}
            } message: {
                Text("You've toggled inactive multiple times. Please speak with an admin if you're having issues.")
            }
            .task {
                await viewModel.loadDDAssignment()
            }
            .onChange(of: viewModel.inactiveToggleCount) { _, newCount in
                if newCount > 5 {
                    showInactiveToggleAlert = true
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Active toggle section
                activeToggleSection

                // Profile requirements warning
                if viewModel.showPhotoUploadRequired {
                    profileRequirementsWarning
                }

                // Current ride section
                if let currentRide = viewModel.currentRide {
                    currentRideSection(ride: currentRide)
                } else if viewModel.isActive {
                    // No rides - all caught up
                    allCaughtUpView
                }

                // Next ride preview
                if let nextRide = viewModel.nextRide, viewModel.currentRide != nil {
                    nextRideSection(ride: nextRide)
                }

                // Statistics
                if viewModel.isActive || viewModel.tonightRidesCount > 0 {
                    statisticsSection
                }

                Spacer(minLength: 32)
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDDAssignment()
            await viewModel.fetchStats()
        }
    }

    // MARK: - Active Toggle Section

    private var activeToggleSection: some View {
        VStack(spacing: 16) {
            // Large toggle with haptic feedback
            Toggle(isOn: Binding(
                get: { viewModel.isActive },
                set: { _ in
                    Task {
                        await viewModel.toggleActiveStatus()
                    }
                }
            )) {
                HStack {
                    Image(systemName: viewModel.isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.isActive ? .green : .gray)

                    Text(viewModel.isActive ? "Active" : "Inactive")
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
            .toggleStyle(.switch)
            .tint(.green)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewModel.isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(viewModel.isActive ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .disabled(viewModel.isLoading)

            // Status message
            if viewModel.isActive {
                Text("You're ready to accept rides")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("Toggle on to start accepting rides")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isActive ? "You are active and accepting rides" : "You are inactive")
        .accessibilityHint("Double tap to toggle active status")
    }

    // MARK: - Profile Requirements Warning

    private var profileRequirementsWarning: some View {
        Button {
            showPhotoUpload = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Incomplete")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Add your photo and car description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Profile incomplete. Add your photo and car description.")
    }

    // MARK: - Current Ride Section

    private func currentRideSection(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Ride")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if ride.isEmergency {
                    Label("EMERGENCY", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }

            CurrentRideCard(
                ride: ride,
                riderName: viewModel.currentRiderName,
                onMarkEnRoute: {
                    Task {
                        await viewModel.markEnRoute()
                    }
                },
                onComplete: {
                    Task {
                        await viewModel.completeRide()
                    }
                },
                isLoading: viewModel.isLoading
            )
        }
    }

    // MARK: - Next Ride Section

    private func nextRideSection(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coming Up Next")
                .font(.headline)
                .foregroundColor(.secondary)

            NextRideCard(ride: ride)
        }
    }

    // MARK: - All Caught Up View

    private var allCaughtUpView: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "All Caught Up!",
            message: "No rides in queue. You'll be notified when someone needs a ride."
        )
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                DDStatsCard(
                    title: "Tonight",
                    count: viewModel.tonightRidesCount,
                    icon: "moon.stars.fill"
                )

                DDStatsCard(
                    title: "Total",
                    count: viewModel.totalRidesCount,
                    icon: "car.fill"
                )
            }
        }
    }

    // MARK: - No Assignment View

    private var noAssignmentView: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "Not Assigned",
            message: "You are not currently assigned as a DD for any active event. Check with your chapter admin."
        )
    }
}

// MARK: - Supporting Views

/// Loading view with spinner and message
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty state view with icon, title, and message
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    DDDashboardView()
}

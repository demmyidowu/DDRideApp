//
//  RiderDashboardView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

/// Main rider dashboard view
///
/// Two states:
/// 1. Idle State (No Active Ride):
///    - Large circular "Request Ride" button
///    - Queue position display
///    - Emergency button
///    - Optional notes field
///
/// 2. Active Ride State:
///    - Navigate to ActiveRideView
///    - Show queue position, status, ETA
struct RiderDashboardView: View {
    @StateObject private var viewModel = RiderViewModel()
    @State private var showEmergencyAlert = false
    @State private var showNotesField = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.currentRide == nil {
                    LoadingView(message: "Loading...")
                } else if let ride = viewModel.currentRide {
                    // Active ride state
                    ActiveRideView(ride: ride, viewModel: viewModel)
                } else {
                    // Idle state - no active ride
                    idleStateContent
                }
            }
            .navigationTitle("Request Ride")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
            .overlay(alignment: .top) {
                if viewModel.showError, let error = viewModel.errorMessage {
                    ErrorBanner(message: error, isPresented: $viewModel.showError)
                }
            }
            .sheet(isPresented: $showEmergencyAlert) {
                EmergencyAlertView { reason in
                    Task {
                        await viewModel.requestEmergencyRide(reason: reason)
                    }
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    // MARK: - Idle State Content

    private var idleStateContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Event name at top
                    if let event = viewModel.currentEvent {
                        eventHeader(event: event)
                            .padding(.top, 20)
                            .padding(.horizontal)
                    }

                    Spacer()
                        .frame(height: geometry.size.height * 0.15)

                    // Main request ride button
                    requestRideButton

                    Spacer()
                        .frame(height: 40)

                    // Optional notes field
                    notesSection
                        .padding(.horizontal)

                    Spacer()
                        .frame(height: geometry.size.height * 0.15)

                    // Emergency button at bottom
                    emergencyButton
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    private func eventHeader(event: Event) -> some View {
        VStack(spacing: 8) {
            Text("Current Event")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(event.name)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current event: \(event.name)")
    }

    private var requestRideButton: some View {
        VStack(spacing: 20) {
            CircularActionButton(
                icon: "car.fill",
                title: "Request Ride",
                action: {
                    Task {
                        await viewModel.requestRide()
                    }
                },
                isLoading: viewModel.isLoading,
                size: 200
            )

            // Queue info (if available)
            if let position = viewModel.queuePosition {
                VStack(spacing: 8) {
                    Text("You're \(position.ordinal) in line")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let waitTime = viewModel.estimatedWaitTime {
                        Text("Estimated wait: ~\(waitTime) min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if viewModel.currentEvent == nil {
                Text("No active event")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showNotesField.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showNotesField ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Add pickup notes (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            if showNotesField {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "e.g., Outside main entrance, North side",
                        text: $viewModel.notes,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .accessibilityLabel("Pickup notes")
                    .accessibilityHint("Add any specific instructions for your driver")

                    Text("Help your driver find you faster")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var emergencyButton: some View {
        Button {
            showEmergencyAlert = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)

                Text("Emergency")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
            )
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("Request emergency ride")
        .accessibilityHint("This will alert the risk manager and prioritize your ride")
    }
}

// MARK: - Preview

#Preview("Idle State") {
    RiderDashboardView()
}

#Preview("With Event") {
    let viewModel = RiderViewModel()
    viewModel.currentEvent = Event(
        id: "event123",
        name: "Friday Night Social",
        chapterId: "chapter123",
        date: Date(),
        allowedChapterIds: ["ALL"],
        status: .active,
        createdAt: Date(),
        updatedAt: Date(),
        createdBy: "admin123"
    )

    return RiderDashboardView()
}

#Preview("Loading") {
    let viewModel = RiderViewModel()
    viewModel.isLoading = true

    return RiderDashboardView()
}

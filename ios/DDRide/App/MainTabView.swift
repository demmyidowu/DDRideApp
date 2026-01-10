//
//  MainTabView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct MainTabView: View {
    let user: User

    @StateObject private var viewModel: MainTabViewModel
    @State private var selectedTab = 0

    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: MainTabViewModel(user: user))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main dashboard based on primary role
            mainDashboard
                .tabItem {
                    Label(viewModel.dashboardTabTitle, systemImage: viewModel.dashboardTabIcon)
                }
                .tag(0)

            // Profile tab (always available)
            ProfileView(user: user)
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(1)
        }
        .tint(AppTheme.Colors.primary)
        .task {
            await viewModel.determinePrimaryRole()
        }
    }

    @ViewBuilder
    private var mainDashboard: some View {
        if viewModel.isLoading {
            LoadingView(message: "Loading dashboard...")
        } else {
            NavigationStack {
                switch viewModel.primaryRole {
                case .admin:
                    AdminDashboardView()

                case .dd:
                    DDDashboardView()

                case .rider:
                    RiderDashboardView()
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class MainTabViewModel: ObservableObject {
    let user: User

    @Published var primaryRole: PrimaryRole = .rider
    @Published var isLoading = true
    @Published var isDDTonight = false

    enum PrimaryRole {
        case admin, dd, rider
    }

    init(user: User) {
        self.user = user
    }

    var dashboardTabTitle: String {
        switch primaryRole {
        case .admin:
            return "Dashboard"
        case .dd:
            return "DD"
        case .rider:
            return "Rides"
        }
    }

    var dashboardTabIcon: String {
        switch primaryRole {
        case .admin:
            return "person.3.fill"
        case .dd:
            return "car.fill"
        case .rider:
            return "location.fill"
        }
    }

    func determinePrimaryRole() async {
        isLoading = true
        defer { isLoading = false }

        // 1. If user.role == .admin, show admin dashboard
        if user.role == .admin {
            primaryRole = .admin
            return
        }

        // 2. Check if user is assigned as DD for any active event tonight
        do {
            let activeEvents = try await FirestoreService.shared.fetchEvents(chapterId: user.chapterId)

            for event in activeEvents where event.status == .active {
                let ddAssignments = try await FirestoreService.shared.fetchActiveDDAssignments(eventId: event.id)

                if ddAssignments.contains(where: { $0.userId == user.id }) {
                    primaryRole = .dd
                    isDDTonight = true
                    print("✅ User is assigned as DD for event: \(event.name)")
                    return
                }
            }

            // 3. Default to rider
            primaryRole = .rider
            print("✅ User role determined: Rider")
        } catch {
            print("❌ Error determining role: \(error.localizedDescription)")
            primaryRole = .rider
        }
    }
}

#Preview {
    MainTabView(user: User(
        id: "123",
        name: "Test User",
        email: "test@ksu.edu",
        phoneNumber: "+15551234567",
        chapterId: "sigma-chi",
        role: .member,
        classYear: 2,
        isEmailVerified: true,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthService.shared)
}

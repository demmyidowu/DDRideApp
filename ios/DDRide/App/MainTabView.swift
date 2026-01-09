//
//  MainTabView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct MainTabView: View {
    let user: User

    var body: some View {
        TabView {
            Group {
                switch user.role {
                case .admin:
                    AdminDashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "person.3.fill")
                        }
                case .dd:
                    DDDashboardView()
                        .tabItem {
                            Label("DD", systemImage: "car.fill")
                        }
                case .rider:
                    RiderDashboardView()
                        .tabItem {
                            Label("Rides", systemImage: "location.fill")
                        }
                }
            }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

#Preview {
    MainTabView(user: User(
        id: "1",
        name: "Test User",
        email: "test@ksu.edu",
        phoneNumber: "+15551234567",
        chapterId: "chapter1",
        role: .admin,
        classYear: 3,
        isEmailVerified: true,
        createdAt: Date(),
        updatedAt: Date()
    ))
}

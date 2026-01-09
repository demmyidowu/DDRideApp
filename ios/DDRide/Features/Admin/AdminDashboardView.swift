//
//  AdminDashboardView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct AdminDashboardView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Management") {
                    NavigationLink {
                        Text("Member Management")
                    } label: {
                        Label("Members", systemImage: "person.2.fill")
                    }

                    NavigationLink {
                        Text("Event Management")
                    } label: {
                        Label("Events", systemImage: "calendar.badge.plus")
                    }

                    NavigationLink {
                        Text("DD Assignment")
                    } label: {
                        Label("DD Assignments", systemImage: "car.circle")
                    }
                }

                Section("Monitoring") {
                    NavigationLink {
                        Text("Active Rides")
                    } label: {
                        Label("Active Rides", systemImage: "location.fill")
                    }

                    NavigationLink {
                        Text("Ride History")
                    } label: {
                        Label("Ride History", systemImage: "clock.fill")
                    }
                }
            }
            .navigationTitle("Admin Dashboard")
        }
    }
}

#Preview {
    AdminDashboardView()
}

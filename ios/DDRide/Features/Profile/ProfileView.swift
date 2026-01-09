//
//  ProfileView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    Section("Account") {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.name)
                                .foregroundColor(.theme.textSecondary)
                        }

                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.theme.textSecondary)
                        }

                        HStack {
                            Text("Role")
                            Spacer()
                            Text(user.role.displayName)
                                .foregroundColor(.theme.textSecondary)
                        }

                        HStack {
                            Text("Class Year")
                            Spacer()
                            Text(classYearName(user.classYear))
                                .foregroundColor(.theme.textSecondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: { showingSignOutAlert = true }) {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    try? authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func classYearName(_ year: Int) -> String {
        switch year {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "Unknown"
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService.shared)
}

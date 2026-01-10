//
//  ContentView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView(message: "Loading...")
                    .transition(.opacity)
            } else if let user = authService.currentUser {
                if !user.isEmailVerified {
                    EmailVerificationView()
                        .transition(.opacity)
                } else {
                    MainTabView(user: user)
                        .transition(.opacity)
                }
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isLoading)
        .animation(.easeInOut(duration: 0.3), value: authService.currentUser?.id)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}

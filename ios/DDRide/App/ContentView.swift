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
                LoadingView()
            } else if let user = authService.currentUser {
                MainTabView(user: user)
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}

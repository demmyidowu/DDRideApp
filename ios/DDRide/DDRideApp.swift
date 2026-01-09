//
//  DDRideApp.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI
import FirebaseCore

@main
struct DDRideApp: App {
    @StateObject private var authService = AuthService.shared

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

//
//  DDRideApp.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        #if DEBUG
        configureFirebaseEmulators()
        #endif

        return true
    }

    #if DEBUG
    private func configureFirebaseEmulators() {
        print("🔧 Configuring Firebase Emulators...")

        // Firestore emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        // Auth emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        print("✅ Firebase Emulators configured")
        print("   - Firestore: localhost:8080")
        print("   - Auth: localhost:9099")
    }
    #endif

    // Handle remote notifications registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert device token to string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 Device Token: \(token)")

        // Save FCM token to user's Firestore document
        Task {
            if let userId = Auth.auth().currentUser?.uid {
                do {
                    try await FirestoreService.shared.updateUserFCMToken(userId: userId, token: token)
                    print("✅ FCM token saved to user profile")
                } catch {
                    print("❌ Failed to save FCM token: \(error.localizedDescription)")
                }
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

@main
struct DDRideApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var authService = AuthService.shared

    init() {
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

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

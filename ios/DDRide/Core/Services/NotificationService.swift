//
//  NotificationService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var fcmToken: String?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        Messaging.messaging().delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

        if granted {
            await registerForRemoteNotifications()
        }

        await checkAuthorizationStatus()
    }

    func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func scheduleLocalNotification(title: String, body: String, delay: TimeInterval = 0) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped with userInfo: \(userInfo)")
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            print("FCM Token: \(fcmToken ?? "nil")")

            // Send token to backend if needed
            if let token = fcmToken {
                await self.sendTokenToBackend(token)
            }
        }
    }

    private func sendTokenToBackend(_ token: String) async {
        // Update user's FCM token in Firestore
        guard let userId = AuthService.shared.currentUser?.id else { return }

        do {
            try await FirestoreService.shared.updateUserFCMToken(userId: userId, token: token)
        } catch {
            print("Error updating FCM token: \(error.localizedDescription)")
        }
    }
}

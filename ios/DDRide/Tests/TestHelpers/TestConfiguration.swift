//
//  TestConfiguration.swift
//  DDRideTests
//
//  Created on 2026-01-09.
//

import XCTest
import Firebase
import FirebaseFirestore
import FirebaseAuth
@testable import DDRide

/// Singleton configuration for Firebase emulator setup in tests
///
/// This class manages:
/// - Firebase emulator connection (Firestore on localhost:8080, Auth on localhost:9099)
/// - Test data cleanup between tests
/// - One-time configuration
///
/// Usage:
/// ```swift
/// class MyTestCase: DDRideTestCase {
///     // setUp() and tearDown() are handled by base class
/// }
/// ```
class TestConfiguration {
    static let shared = TestConfiguration()

    private var isConfigured = false

    private init() {}

    /// Configure Firebase to use emulators
    ///
    /// This method is idempotent - safe to call multiple times
    func configure() {
        guard !isConfigured else { return }

        // Configure Firebase for testing if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Connect to emulators
        configureFirestoreEmulator()
        configureAuthEmulator()

        isConfigured = true
        print("✅ Test configuration complete - Using Firebase Emulators")
    }

    /// Configure Firestore to use local emulator
    private func configureFirestoreEmulator() {
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
    }

    /// Configure Auth to use local emulator
    private func configureAuthEmulator() {
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
    }

    /// Clear all test data from Firestore emulator
    ///
    /// Deletes all documents from test collections:
    /// - users
    /// - chapters
    /// - events
    /// - rides
    /// - ddAssignments
    /// - adminAlerts
    /// - yearTransitionLogs
    ///
    /// - Throws: FirestoreError if deletion fails
    func clearFirestore() async throws {
        let db = Firestore.firestore()
        let collections = [
            "users",
            "chapters",
            "events",
            "rides",
            "ddAssignments",
            "adminAlerts",
            "yearTransitionLogs"
        ]

        for collection in collections {
            let snapshot = try await db.collection(collection).getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
            }
        }

        print("🧹 Cleared Firestore test data")
    }
}

/// Base test case that all DD Ride tests should inherit from
///
/// Provides:
/// - Automatic Firebase emulator configuration
/// - Automatic data cleanup before and after each test
/// - Access to shared services
///
/// Usage:
/// ```swift
/// final class MyTests: DDRideTestCase {
///     func testSomething() async throws {
///         // Test code here
///         // Firestore is already configured and clean
///     }
/// }
/// ```
class DDRideTestCase: XCTestCase {

    /// Configure emulators and clear data before each test
    override func setUp() async throws {
        try await super.setUp()
        TestConfiguration.shared.configure()
        try await TestConfiguration.shared.clearFirestore()
    }

    /// Clear data after each test to prevent state pollution
    override func tearDown() async throws {
        try await TestConfiguration.shared.clearFirestore()
        try await super.tearDown()
    }
}

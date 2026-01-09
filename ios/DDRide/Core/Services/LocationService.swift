//
//  LocationService.swift
//  DDRide
//
//  Created on 2026-01-08.
//  Updated on 2026-01-09 - Battery-efficient one-time location capture
//

import Foundation
import CoreLocation
import Combine
import FirebaseFirestore

/// Custom error types for location operations
enum LocationError: LocalizedError {
    case unauthorized
    case restricted
    case timeout
    case unavailable
    case geocodingFailed
    case invalidCoordinate

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Location permission is required to request a ride. Please enable location access in Settings."
        case .restricted:
            return "Location services are restricted on this device."
        case .timeout:
            return "Could not get your location. Please try again."
        case .unavailable:
            return "Location services are currently unavailable."
        case .geocodingFailed:
            return "Could not determine your address from location."
        case .invalidCoordinate:
            return "The provided location is invalid."
        }
    }
}

/// Battery-efficient location service with ONE-TIME capture only
///
/// This service implements location capture for the DD Ride app with strict battery efficiency:
/// - Captures location ONCE per request (no continuous tracking)
/// - Uses "When In Use" permission only (NOT "Always")
/// - 10-second timeout to prevent battery drain
/// - Stops location manager immediately after capture
///
/// Two Location Captures Per Ride:
/// 1. Rider's pickup location - captured once when requesting ride
/// 2. DD's location - captured once when DD marks "en route" (for ETA calculation)
///
/// Example Usage:
/// ```swift
/// // Request permission first
/// let authorized = await LocationService.shared.requestLocationPermission()
///
/// // Capture location once
/// let coordinate = try await LocationService.shared.captureLocationOnce()
///
/// // Convert to address
/// let address = try await LocationService.shared.geocodeAddress(coordinate: coordinate)
/// ```
///
/// Testing Notes:
/// - Use Simulator > Features > Location to simulate locations
/// - Test permission states: denied, restricted, authorized
/// - Test timeout by simulating "None" location
/// - Test geocoding fallback by using invalid coordinates
@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // Published properties for SwiftUI observation
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastCapturedLocation: CLLocationCoordinate2D?
    @Published var lastCapturedAddress: String?
    @Published var errorMessage: String?

    // Continuation for async/await location capture
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    // Timeout configuration
    private let timeoutSeconds: TimeInterval = 10.0
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        // Use .best accuracy for one-time captures (okay since infrequent)
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }

    // MARK: - Permission Management

    /// Request "When In Use" location authorization
    ///
    /// This method requests permission to access location only when the app is in use.
    /// We do NOT request "Always" permission as we don't need background location tracking.
    ///
    /// - Returns: True if authorized, false otherwise
    func requestLocationPermission() async -> Bool {
        // Check current status
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // Request permission
            locationManager.requestWhenInUseAuthorization()

            // Wait for authorization to change
            return await withCheckedContinuation { continuation in
                // Use a timer to check authorization status changes
                var checkCount = 0
                let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                    checkCount += 1
                    let newStatus = self.locationManager.authorizationStatus

                    if newStatus != .notDetermined {
                        timer.invalidate()
                        continuation.resume(returning: newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways)
                    } else if checkCount > 20 { // 10 second timeout
                        timer.invalidate()
                        continuation.resume(returning: false)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
            }

        case .restricted:
            return false

        case .denied:
            return false

        case .authorizedWhenInUse, .authorizedAlways:
            return true

        @unknown default:
            return false
        }
    }

    /// Check if location services are currently authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - One-Time Location Capture

    /// Capture location ONCE and immediately stop updates (battery efficient)
    ///
    /// This method:
    /// 1. Checks authorization status
    /// 2. Requests a single location update
    /// 3. Times out after 10 seconds if no location received
    /// 4. Stops location manager immediately after capture
    /// 5. Caches result in lastCapturedLocation
    ///
    /// - Returns: Coordinate of current location
    /// - Throws: LocationError if permission denied, timeout, or unavailable
    func captureLocationOnce() async throws -> CLLocationCoordinate2D {
        // Check authorization
        guard isAuthorized else {
            if authorizationStatus == .restricted {
                throw LocationError.restricted
            } else {
                throw LocationError.unauthorized
            }
        }

        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation for delegate callback
            self.locationContinuation = continuation

            // Set up timeout
            self.timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))

                // If continuation still exists, we timed out
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(throwing: LocationError.timeout)
                    self.locationContinuation = nil
                    self.locationManager.stopUpdatingLocation()
                }
            }

            // Request single location update
            // This is more battery efficient than startUpdatingLocation()
            self.locationManager.requestLocation()
        }
    }

    // MARK: - Geocoding

    /// Convert coordinate to human-readable address
    ///
    /// Returns formatted address in the format:
    /// "123 Main St, Manhattan, KS 66502"
    ///
    /// - Parameter coordinate: The coordinate to geocode
    /// - Returns: Formatted address string
    /// - Throws: LocationError.geocodingFailed if geocoding fails
    func geocodeAddress(coordinate: CLLocationCoordinate2D) async throws -> String {
        // Validate coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw LocationError.invalidCoordinate
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            guard let placemark = placemarks.first else {
                throw LocationError.geocodingFailed
            }

            let address = formatAddress(from: placemark)

            // Cache result
            self.lastCapturedAddress = address

            return address
        } catch {
            // If geocoding fails, throw error
            throw LocationError.geocodingFailed
        }
    }

    /// Format placemark into readable address
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        // Street number and name
        if let streetNumber = placemark.subThoroughfare, let street = placemark.thoroughfare {
            components.append("\(streetNumber) \(street)")
        } else if let street = placemark.thoroughfare {
            components.append(street)
        }

        // City
        if let city = placemark.locality {
            components.append(city)
        }

        // State
        if let state = placemark.administrativeArea {
            components.append(state)
        }

        // ZIP code
        if let zip = placemark.postalCode {
            components.append(zip)
        }

        // If no components found, use name or return coordinates
        if components.isEmpty {
            if let name = placemark.name {
                return name
            }
            return "Unknown location"
        }

        return components.joined(separator: ", ")
    }

    // MARK: - Convenience Methods

    /// Capture location and geocode in one call
    ///
    /// - Returns: Tuple of (coordinate, address)
    /// - Throws: LocationError if capture or geocoding fails
    func captureLocationAndAddress() async throws -> (coordinate: CLLocationCoordinate2D, address: String) {
        let coordinate = try await captureLocationOnce()
        let address = try await geocodeAddress(coordinate: coordinate)
        return (coordinate, address)
    }

    /// Get coordinate as formatted string (for debugging)
    func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            // Get the most accurate location
            guard let location = locations.last else { return }

            let coordinate = location.coordinate

            // Validate coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else {
                locationContinuation?.resume(throwing: LocationError.invalidCoordinate)
                locationContinuation = nil
                timeoutTask?.cancel()
                manager.stopUpdatingLocation()
                return
            }

            // Cache location
            lastCapturedLocation = coordinate

            // Resume continuation with result
            locationContinuation?.resume(returning: coordinate)
            locationContinuation = nil

            // Cancel timeout
            timeoutTask?.cancel()
            timeoutTask = nil

            // CRITICAL: Stop location updates immediately to save battery
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Map CLError to LocationError
            let locationError: LocationError

            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = .unauthorized
                case .locationUnknown:
                    locationError = .unavailable
                case .network:
                    locationError = .unavailable
                default:
                    locationError = .unavailable
                }
            } else {
                locationError = .unavailable
            }

            // Set error message
            errorMessage = locationError.localizedDescription

            // Resume continuation with error
            locationContinuation?.resume(throwing: locationError)
            locationContinuation = nil

            // Cancel timeout
            timeoutTask?.cancel()
            timeoutTask = nil

            // Stop location updates
            manager.stopUpdatingLocation()
        }
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    /// Convert to Firebase GeoPoint
    var geoPoint: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }
}

extension GeoPoint {
    /// Convert to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

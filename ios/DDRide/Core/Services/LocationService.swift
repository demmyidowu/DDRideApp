//
//  LocationService.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import Foundation
import CoreLocation
import MapKit

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func captureCurrentLocation() async throws -> CLLocation {
        // Check authorization status
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            locationManager.requestLocation()

            // Set a timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if !didResume {
                    didResume = true
                    continuation.resume(throwing: LocationError.timeout)
                }
            }

            // Wait for location update in delegate
            NotificationCenter.default.addObserver(
                forName: .didReceiveLocation,
                object: nil,
                queue: .main
            ) { notification in
                guard !didResume else { return }
                didResume = true

                if let location = notification.object as? CLLocation {
                    continuation.resume(returning: location)
                } else if let error = notification.object as? Error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func reverseGeocode(location: CLLocation) async throws -> String {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }

        return formatAddress(from: placemark)
    }

    func calculateDistance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        return from.distance(from: to)
    }

    func calculateETA(from: CLLocation, to: CLLocation) async throws -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw LocationError.routeCalculationFailed
        }

        return route.expectedTravelTime
    }

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let streetNumber = placemark.subThoroughfare {
            components.append(streetNumber)
        }

        if let street = placemark.thoroughfare {
            components.append(street)
        }

        if let city = placemark.locality {
            components.append(city)
        }

        if let state = placemark.administrativeArea {
            components.append(state)
        }

        if let zipCode = placemark.postalCode {
            components.append(zipCode)
        }

        return components.joined(separator: ", ")
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
        guard let location = locations.last else { return }

        Task { @MainActor in
            currentLocation = location
            NotificationCenter.default.post(name: .didReceiveLocation, object: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
            NotificationCenter.default.post(name: .didReceiveLocation, object: error)
        }
    }
}

// MARK: - Location Error

enum LocationError: LocalizedError {
    case notAuthorized
    case timeout
    case geocodingFailed
    case routeCalculationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access not authorized. Please enable in Settings."
        case .timeout:
            return "Location request timed out. Please try again."
        case .geocodingFailed:
            return "Unable to determine address from location."
        case .routeCalculationFailed:
            return "Unable to calculate route."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didReceiveLocation = Notification.Name("didReceiveLocation")
}

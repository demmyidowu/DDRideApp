//
//  ETAService.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import Foundation
import CoreLocation
import MapKit

/// Custom error types for ETA calculations
enum ETAError: LocalizedError {
    case routeNotFound
    case networkError(Error)
    case invalidAddress
    case invalidCoordinate

    var errorDescription: String? {
        switch self {
        case .routeNotFound:
            return "Could not find a route to the destination."
        case .networkError(let error):
            return "Network error calculating route: \(error.localizedDescription)"
        case .invalidAddress:
            return "The provided address is invalid."
        case .invalidCoordinate:
            return "The provided coordinates are invalid."
        }
    }
}

/// ETA calculation service using MapKit driving directions
///
/// This service calculates estimated travel times between two locations using
/// MapKit's MKDirections API with driving transport type.
///
/// Features:
/// - Calculate ETA between two coordinates
/// - Calculate ETA from coordinate to address (with geocoding)
/// - Default fallback ETA of 15 minutes on failure
/// - Error handling for network issues and invalid routes
///
/// Example Usage:
/// ```swift
/// // Calculate ETA between two coordinates
/// let eta = try await ETAService.shared.calculateETA(
///     from: ddLocation,
///     to: riderLocation
/// )
/// print("ETA: \(eta) minutes")
///
/// // Calculate ETA to an address
/// let eta = try await ETAService.shared.calculateETA(
///     from: ddLocation,
///     to: "123 Main St, Manhattan, KS"
/// )
/// ```
///
/// Testing Notes:
/// - Test with real locations in simulator
/// - Test with invalid coordinates (should throw error)
/// - Test with no route available (remote locations)
/// - Test network error handling (airplane mode)
@MainActor
class ETAService: ObservableObject {
    static let shared = ETAService()

    private let geocoder = CLGeocoder()

    // Default fallback ETA in minutes
    private let defaultFallbackETA: Int = 15

    private init() {}

    // MARK: - ETA Calculation (Coordinates)

    /// Calculate driving ETA between two coordinates
    ///
    /// Uses MapKit Directions API to calculate the fastest driving route
    /// and returns the expected travel time in minutes (rounded up).
    ///
    /// - Parameters:
    ///   - from: Source coordinate (e.g., DD's current location)
    ///   - to: Destination coordinate (e.g., rider's pickup location)
    /// - Returns: Estimated travel time in minutes (rounded up)
    /// - Throws: ETAError if calculation fails
    func calculateETA(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> Int {
        // Validate coordinates
        guard CLLocationCoordinate2DIsValid(from) else {
            throw ETAError.invalidCoordinate
        }
        guard CLLocationCoordinate2DIsValid(to) else {
            throw ETAError.invalidCoordinate
        }

        // Create directions request
        let request = MKDirections.Request()

        // Set source
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))

        // Set destination
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))

        // Configure for driving directions
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        // Calculate directions
        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()

            // Get the first (fastest) route
            guard let route = response.routes.first else {
                throw ETAError.routeNotFound
            }

            // Convert travel time to minutes (rounded up)
            let travelTimeSeconds = route.expectedTravelTime
            let etaMinutes = Int(ceil(travelTimeSeconds / 60.0))

            return etaMinutes
        } catch let error as ETAError {
            throw error
        } catch {
            throw ETAError.networkError(error)
        }
    }

    // MARK: - ETA Calculation (Address)

    /// Calculate driving ETA from coordinate to address
    ///
    /// First geocodes the destination address to coordinates,
    /// then calculates the driving route.
    ///
    /// - Parameters:
    ///   - from: Source coordinate (e.g., DD's current location)
    ///   - to: Destination address string
    /// - Returns: Estimated travel time in minutes (rounded up)
    /// - Throws: ETAError if geocoding or calculation fails
    func calculateETA(
        from: CLLocationCoordinate2D,
        to address: String
    ) async throws -> Int {
        // Validate source coordinate
        guard CLLocationCoordinate2DIsValid(from) else {
            throw ETAError.invalidCoordinate
        }

        // Geocode destination address
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)

            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                throw ETAError.invalidAddress
            }

            let toCoordinate = location.coordinate

            // Calculate ETA using coordinates
            return try await calculateETA(from: from, to: toCoordinate)
        } catch let error as ETAError {
            throw error
        } catch {
            throw ETAError.invalidAddress
        }
    }

    // MARK: - ETA with Fallback

    /// Calculate ETA with fallback to default value on error
    ///
    /// This method never throws - it returns the default ETA (15 minutes)
    /// if calculation fails. Useful for UI where you always need a value.
    ///
    /// - Parameters:
    ///   - from: Source coordinate
    ///   - to: Destination coordinate
    /// - Returns: Estimated travel time in minutes (or default 15 minutes)
    func calculateETAWithFallback(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> Int {
        do {
            return try await calculateETA(from: from, to: to)
        } catch {
            // Log error for debugging
            print("ETA calculation failed: \(error.localizedDescription). Using fallback: \(defaultFallbackETA) minutes")
            return defaultFallbackETA
        }
    }

    /// Calculate ETA to address with fallback to default value
    ///
    /// - Parameters:
    ///   - from: Source coordinate
    ///   - to: Destination address
    /// - Returns: Estimated travel time in minutes (or default 15 minutes)
    func calculateETAWithFallback(
        from: CLLocationCoordinate2D,
        to address: String
    ) async -> Int {
        do {
            return try await calculateETA(from: from, to: address)
        } catch {
            // Log error for debugging
            print("ETA calculation failed: \(error.localizedDescription). Using fallback: \(defaultFallbackETA) minutes")
            return defaultFallbackETA
        }
    }

    // MARK: - Distance Calculation

    /// Calculate straight-line distance between two coordinates (in meters)
    ///
    /// This is NOT the driving distance, but the direct "as the crow flies" distance.
    /// Useful for quick distance checks without network requests.
    ///
    /// - Parameters:
    ///   - from: Source coordinate
    ///   - to: Destination coordinate
    /// - Returns: Distance in meters
    func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)

        return fromLocation.distance(from: toLocation)
    }

    /// Convert distance in meters to miles
    ///
    /// - Parameter meters: Distance in meters
    /// - Returns: Distance in miles (rounded to 1 decimal place)
    func metersToMiles(_ meters: CLLocationDistance) -> Double {
        let miles = meters / 1609.344
        return round(miles * 10) / 10
    }

    /// Convert distance in meters to kilometers
    ///
    /// - Parameter meters: Distance in meters
    /// - Returns: Distance in kilometers (rounded to 1 decimal place)
    func metersToKilometers(_ meters: CLLocationDistance) -> Double {
        let kilometers = meters / 1000.0
        return round(kilometers * 10) / 10
    }
}

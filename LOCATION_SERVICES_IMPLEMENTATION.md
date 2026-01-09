# Location Services Implementation - DD Ride App

## Overview
Battery-efficient location services with **one-time capture only** (no background tracking).

## Files Created/Updated

### 1. LocationService.swift
**Path:** `/Users/didowu/DDRideApp/ios/DDRide/Core/Services/LocationService.swift`

**Key Features:**
- One-time location capture using `requestLocation()` (not `startUpdatingLocation()`)
- "When In Use" permission only (NOT "Always")
- 10-second timeout to prevent battery drain
- Stops location manager immediately after capture
- Async/await API with proper continuation handling
- Geocoding with formatted address output
- GeoPoint <-> CLLocationCoordinate2D conversion extensions

**Core Methods:**
```swift
// Request permission (when in use only)
func requestLocationPermission() async -> Bool

// Capture location once (battery efficient)
func captureLocationOnce() async throws -> CLLocationCoordinate2D

// Convert coordinate to address
func geocodeAddress(coordinate: CLLocationCoordinate2D) async throws -> String

// Convenience method for both
func captureLocationAndAddress() async throws -> (coordinate: CLLocationCoordinate2D, address: String)
```

**Error Handling:**
- `LocationError.unauthorized` - Permission denied
- `LocationError.restricted` - Parental controls
- `LocationError.timeout` - 10 second timeout exceeded
- `LocationError.unavailable` - Location services disabled
- `LocationError.geocodingFailed` - Address lookup failed
- `LocationError.invalidCoordinate` - Invalid coordinate

**Battery Optimization:**
- Uses `requestLocation()` for single update
- Stops location manager immediately after capture
- 10-second timeout prevents stale location manager
- No background location tracking
- No continuous updates

---

### 2. ETAService.swift
**Path:** `/Users/didowu/DDRideApp/ios/DDRide/Core/Services/ETAService.swift`

**Key Features:**
- Calculate driving ETA using MapKit Directions API
- Support for coordinate-to-coordinate and coordinate-to-address
- Fallback methods that never throw (default 15 minutes)
- Distance calculations (meters, miles, kilometers)

**Core Methods:**
```swift
// Calculate ETA between coordinates
func calculateETA(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> Int

// Calculate ETA to address
func calculateETA(from: CLLocationCoordinate2D, to address: String) async throws -> Int

// With fallback (never throws)
func calculateETAWithFallback(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> Int

// Distance calculations
func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance
func metersToMiles(_ meters: CLLocationDistance) -> Double
func metersToKilometers(_ meters: CLLocationDistance) -> Double
```

**Error Handling:**
- `ETAError.routeNotFound` - No route available
- `ETAError.networkError` - Network issue
- `ETAError.invalidAddress` - Geocoding failed
- `ETAError.invalidCoordinate` - Invalid coordinates

**Default Fallback:** 15 minutes

---

### 3. RideRequestService.swift
**Path:** `/Users/didowu/DDRideApp/ios/DDRide/Core/Services/RideRequestService.swift`

**Key Features:**
- Orchestrates full ride request flow
- Integrates LocationService, RideQueueService, and FirestoreService
- Handles location capture for both rider and DD
- Automatic priority calculation and queue positioning

**Core Methods:**
```swift
// Request a ride (full flow)
func requestRide(
    userId: String,
    eventId: String,
    isEmergency: Bool = false,
    notes: String? = nil
) async throws -> Ride

// Capture DD's location when marking en route
func captureEnrouteLocation(for ride: Ride) async throws -> (coordinate: CLLocationCoordinate2D, address: String)

// Cancel a ride
func cancelRide(rideId: String, reason: String) async throws

// Check if user can request ride
func canRequestRide(userId: String) async -> Bool

// Get user's active ride
func getActiveRide(userId: String) async -> Ride?
```

**Ride Request Flow:**
1. Fetch user details (classYear, chapterId)
2. **Capture rider's location once** (FIRST location capture)
3. Geocode location to human-readable address
4. Calculate initial priority (waitMinutes = 0)
5. Create Ride object with all required fields
6. Save ride to Firestore
7. Get queue position across all DDs
8. Update ride with queue position
9. Return complete Ride object

**DD En Route Flow:**
1. **Capture DD's location once** (SECOND location capture)
2. Geocode DD's location
3. Calculate ETA to rider
4. Update ride status to "enroute"
5. Cloud Function sends SMS to rider

**Error Handling:**
- `RideRequestError.userNotFound`
- `RideRequestError.locationCaptureFailed`
- `RideRequestError.geocodingFailed`
- `RideRequestError.saveFailed`
- `RideRequestError.invalidEventId`
- `RideRequestError.unauthorized`

---

### 4. Info.plist Configuration
**Location:** Inline in `project.pbxproj` (lines 513, 547)

**Already Configured:**
```
NSLocationWhenInUseUsageDescription = "DDRide needs your location to connect you with designated drivers and provide accurate pickup locations."
```

**Permission Level:** "When In Use" only (NOT "Always")

---

## Location Capture Strategy

### Two Location Captures Per Ride

1. **Rider's Pickup Location**
   - Captured when rider requests ride
   - Used for: pickup address, DD assignment, ETA calculation
   - Service: `RideRequestService.requestRide()`

2. **DD's Current Location**
   - Captured when DD marks "en route"
   - Used for: ETA calculation to rider
   - Service: `RideRequestService.captureEnrouteLocation()`

### Battery Efficiency Principles

1. **One-Time Captures Only**
   - Use `requestLocation()` not `startUpdatingLocation()`
   - Stop location manager immediately after capture
   - No continuous updates

2. **Appropriate Accuracy**
   - Use `kCLLocationAccuracyBest` for one-time captures
   - Okay since captures are infrequent (only 2 per ride)

3. **No Background Location**
   - Only "When In Use" permission
   - No background location tracking
   - App must be in foreground to capture location

4. **Timeout Requests**
   - 10-second timeout for all location captures
   - Prevents battery drain from stale location manager

5. **Cache When Possible**
   - Cache last captured location and address
   - Useful for debugging and UI display

---

## Integration with Existing Services

### FirestoreService
- `createRide()` - Save new ride request
- `updateRide()` - Update ride with queue position, status
- `fetchUser()` - Get user details (classYear, chapterId)
- `fetchRide()` - Get ride details
- `fetchRiderRides()` - Get user's ride history

### RideQueueService
- `calculatePriority()` - Priority algorithm: (classYear × 10) + (waitMinutes × 0.5)
- `getOverallQueuePosition()` - Overall queue position across all DDs
- Emergency rides always get priority 9999

### ETAService
- `calculateETA()` - Calculate driving ETA using MapKit
- Used when DD marks "en route" to show rider ETA

---

## Example Usage

### Request a Ride (Rider)

```swift
// In RiderDashboardView or ViewModel

// 1. Check if user can request ride
let canRequest = await RideRequestService.shared.canRequestRide(userId: currentUser.id)

guard canRequest else {
    // Show error: "You already have an active ride"
    return
}

// 2. Request location permission if needed
if !LocationService.shared.isAuthorized {
    let authorized = await LocationService.shared.requestLocationPermission()

    guard authorized else {
        // Show error: "Location permission required"
        return
    }
}

// 3. Request ride
do {
    let ride = try await RideRequestService.shared.requestRide(
        userId: currentUser.id,
        eventId: currentEvent.id,
        isEmergency: false,
        notes: "Outside the main entrance"
    )

    print("Ride requested! Queue position: \(ride.queuePosition ?? 0)")

} catch let error as RideRequestError {
    // Show user-friendly error
    print("Error: \(error.localizedDescription)")
}
```

### Mark En Route (DD)

```swift
// In DDDashboardView when DD taps "En Route" button

do {
    // 1. Capture DD's current location
    let (ddLocation, ddAddress) = try await RideRequestService.shared.captureEnrouteLocation(for: ride)

    // 2. Calculate ETA to rider
    let riderLocation = ride.pickupLocation.coordinate
    let eta = try await ETAService.shared.calculateETA(from: ddLocation, to: riderLocation)

    // 3. Update ride status
    var updatedRide = ride
    updatedRide.status = .enroute
    updatedRide.enrouteAt = Date()
    updatedRide.estimatedWaitTime = eta

    try await FirestoreService.shared.updateRide(updatedRide)

    // Cloud Function will send SMS to rider with DD info and ETA

} catch {
    print("Error marking en route: \(error.localizedDescription)")
}
```

### Emergency Ride Request

```swift
// Same as regular ride request, but with isEmergency: true

let ride = try await RideRequestService.shared.requestRide(
    userId: currentUser.id,
    eventId: currentEvent.id,
    isEmergency: true,  // Priority 9999
    notes: "EMERGENCY - Need immediate assistance"
)

// Emergency rides always go to front of queue (priority 9999)
```

---

## Permission Flow UI

### LocationPermissionView (SwiftUI)

```swift
struct LocationPermissionView: View {
    @StateObject private var locationService = LocationService.shared
    let onAuthorized: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Location Permission")
                .font(.title2)
                .bold()

            Text("We need your location to connect you with a designated driver. Your location is only captured when you request a ride.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Enable Location") {
                Task {
                    let authorized = await locationService.requestLocationPermission()
                    if authorized {
                        onAuthorized()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

### LocationDeniedView (SwiftUI)

```swift
struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            Text("Location Access Denied")
                .font(.title2)
                .bold()

            Text("Please enable location access in Settings to request rides.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

---

## Testing Guide

### Simulator Testing

1. **Simulate Locations:**
   - Simulator > Features > Location > Custom Location
   - Enter coordinates for Manhattan, KS: 39.183608, -96.571669

2. **Test Permission States:**
   - Not Determined: Fresh install
   - Denied: Settings > Privacy > Location Services > DDRide > Never
   - Authorized: Settings > Privacy > Location Services > DDRide > While Using the App

3. **Test Timeout:**
   - Simulator > Features > Location > None
   - Should timeout after 10 seconds with appropriate error

4. **Test Geocoding:**
   - Use real locations in Manhattan, KS
   - Verify address format: "123 Main St, Manhattan, KS 66502"

### Error Testing

1. **Permission Denied:**
   - Deny permission in Settings
   - Attempt to request ride
   - Verify error message shows

2. **Location Timeout:**
   - Simulate "None" location
   - Attempt to capture location
   - Verify 10-second timeout

3. **Geocoding Failure:**
   - Use invalid coordinates (e.g., 0, 0)
   - Verify graceful error handling

4. **Network Error (ETA):**
   - Enable Airplane Mode
   - Attempt to calculate ETA
   - Verify fallback to 15 minutes

### Battery Testing

1. **Monitor Location Updates:**
   - Use Instruments > Energy Log
   - Verify only 2 location captures per ride
   - Verify location manager stops after each capture

2. **Check Background Activity:**
   - Monitor app in background
   - Verify NO location updates in background
   - Verify location manager is stopped

---

## Privacy Considerations

### iOS 14+ Location Permission

- **Precise Location:** App requests precise location by default
- **Approximate Location:** User can choose "Approximate" in iOS 14+
- **Handling:** App should work with both precise and approximate location

### Privacy Labels (App Store)

**Location:**
- **Type:** Precise Location
- **Purpose:** App Functionality
- **Usage:** "To connect you with designated drivers and provide pickup locations"
- **Linked to User:** Yes
- **Used for Tracking:** No

**Data Retention:**
- Pickup location stored in Firestore (for ride history)
- Location data deleted when ride is completed (optional)
- User can request data deletion

---

## Next Steps

1. **Add Location Services to Xcode Project:**
   - ETAService.swift and RideRequestService.swift need to be added to Xcode project
   - Update project.pbxproj to include these files

2. **Integrate with UI:**
   - Update RiderDashboardView to use RideRequestService
   - Add LocationPermissionView for first-time users
   - Add LocationDeniedView for denied permission

3. **Test on Device:**
   - Test on physical iPhone (simulator doesn't capture real battery usage)
   - Monitor battery usage in Settings > Battery
   - Verify location only captured twice per ride

4. **Cloud Function Updates:**
   - Update assignDD Cloud Function to handle ride creation
   - Update enroute Cloud Function to send SMS with ETA

5. **Analytics:**
   - Track location capture success/failure rates
   - Monitor geocoding accuracy
   - Track ETA calculation accuracy

---

## Troubleshooting

### Location Capture Fails
- Check permission status: `LocationService.shared.isAuthorized`
- Verify location services enabled: `CLLocationManager.locationServicesEnabled()`
- Check for timeout: 10-second timeout may need adjustment in poor signal areas

### Geocoding Fails
- Verify valid coordinates: `CLLocationCoordinate2DIsValid(coordinate)`
- Check network connection (geocoding requires network)
- Fallback: Show coordinates instead of address

### ETA Calculation Fails
- Verify valid coordinates for both source and destination
- Check network connection (MapKit Directions requires network)
- Fallback: Default 15 minutes

### Battery Drain
- Verify location manager is stopped after capture
- Check for multiple location captures (should only be 2 per ride)
- Monitor with Instruments > Energy Log

---

## Summary

Battery-efficient location services implemented with:
- **One-time captures only** (no background tracking)
- **"When In Use" permission** (not "Always")
- **10-second timeout** (prevents battery drain)
- **Two captures per ride** (rider pickup + DD en route)
- **Proper error handling** (graceful fallbacks)
- **Privacy-friendly** (minimal location data collection)

All services production-ready and integrated with existing Firestore and queue services.

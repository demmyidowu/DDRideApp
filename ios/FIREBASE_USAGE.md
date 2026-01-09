# Firebase Service Usage Guide

This guide shows how to use the `FirebaseService` in your iOS app.

## Getting Started

The `FirebaseService` is a singleton that provides type-safe access to Firestore.

```swift
import SwiftUI

struct MyView: View {
    let firebase = FirebaseService.shared

    var body: some View {
        // Your view code
    }
}
```

## User Operations

### Create User (During Signup)

```swift
let newUser = User(
    id: Auth.auth().currentUser!.uid,
    name: "John Doe",
    email: "john.doe@ksu.edu",
    phoneNumber: "+15551234567",
    chapterId: selectedChapterId,
    role: .member,
    classYear: 3, // Junior
    isEmailVerified: true,
    createdAt: Date(),
    updatedAt: Date()
)

try await firebase.createUser(newUser)
```

### Fetch Current User

```swift
guard let userId = Auth.auth().currentUser?.uid else { return }
let user = try await firebase.fetchUser(id: userId)
print("User: \(user.name), Class: \(user.classYear)")
```

### Update User Profile

```swift
var user = try await firebase.fetchUser(id: userId)
user.phoneNumber = "+15559876543"
try await firebase.updateUser(user)
```

### Fetch Chapter Members

```swift
let members = try await firebase.fetchChapterMembers(chapterId: user.chapterId)
print("Chapter has \(members.count) members")
```

## Event Operations

### Create Event (Admin Only)

```swift
let eventId = firebase.generateDocumentId(for: "events")
let newEvent = Event(
    id: eventId,
    name: "Saturday Night",
    chapterId: user.chapterId,
    date: Date(),
    allowedChapterIds: ["ALL"], // or specific chapter IDs
    status: .active,
    location: "Downtown",
    description: "Weekend event",
    createdAt: Date(),
    createdBy: user.id
)

try await firebase.createEvent(newEvent)
```

### Fetch Active Events

```swift
let events = try await firebase.fetchActiveEvents(chapterId: user.chapterId)
for event in events {
    print("Event: \(event.name) on \(event.date)")
}
```

### End Event (Admin)

```swift
var event = try await firebase.fetchEvent(id: eventId)
event.status = .completed
try await firebase.updateEvent(event)
```

## DD Assignment Operations

### Assign DD to Event (Admin)

```swift
let assignmentId = ddUserId // Use userId as assignment ID
let assignment = DDAssignment(
    id: assignmentId,
    userId: ddUserId,
    eventId: eventId,
    photoURL: ddPhotoURL,
    carDescription: "Blue Toyota Camry",
    isActive: true,
    inactiveToggles: 0,
    totalRidesCompleted: 0,
    createdAt: Date(),
    updatedAt: Date()
)

try await firebase.createDDAssignment(assignment, eventId: eventId)
```

### Toggle DD Active Status

```swift
var assignment = try await firebase.fetchDDAssignment(id: userId, eventId: eventId)
assignment.isActive.toggle()

if assignment.isActive {
    assignment.lastActiveTimestamp = Date()
} else {
    assignment.lastInactiveTimestamp = Date()
    assignment.inactiveToggles += 1
}

try await firebase.updateDDAssignment(assignment, eventId: eventId)
```

### Fetch Active DDs

```swift
let activeDDs = try await firebase.fetchActiveDDAssignments(eventId: eventId)
print("\(activeDDs.count) DDs are currently active")
```

## Ride Operations

### Request Ride (Rider)

```swift
import CoreLocation

// Get user's location (use LocationService)
let pickupCoordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)

// Calculate priority: (classYear × 10) + (waitTime × 0.5)
let priority = Double(user.classYear * 10)

let rideId = firebase.generateDocumentId(for: "rides")
let ride = Ride(
    id: rideId,
    eventId: currentEventId,
    riderId: user.id,
    riderName: user.name,
    riderPhoneNumber: user.phoneNumber,
    pickupAddress: "123 Main St, Manhattan, KS",
    pickupCoordinate: pickupCoordinate,
    priority: priority,
    isEmergency: false
)

try await firebase.createRide(ride)
```

### Request Emergency Ride

```swift
let ride = Ride(
    id: firebase.generateDocumentId(for: "rides"),
    eventId: currentEventId,
    riderId: user.id,
    riderName: user.name,
    riderPhoneNumber: user.phoneNumber,
    pickupAddress: "123 Main St",
    pickupCoordinate: pickupCoordinate,
    priority: 9999, // Emergency priority
    isEmergency: true,
    emergencyReason: "Safety concern"
)

try await firebase.createRide(ride)
```

### Fetch Active Rides (Queue)

```swift
// Fetches all queued, assigned, and en route rides
// Sorted by priority (highest first)
let rides = try await firebase.fetchActiveRides(eventId: eventId)

for (index, ride) in rides.enumerated() {
    print("Position \(index + 1): \(ride.riderName) - Priority: \(ride.priority)")
}
```

### Update Ride Status (DD)

```swift
// DD accepts ride
var ride = try await firebase.fetchRide(id: rideId)
ride.status = .assigned
ride.assignedTime = Date()
ride.ddId = currentUser.id
ride.ddName = currentUser.name
ride.ddPhoneNumber = currentUser.phoneNumber
try await firebase.updateRide(ride)

// DD starts driving
ride.status = .enroute
ride.enrouteTime = Date()
ride.estimatedETA = 10 // minutes
try await firebase.updateRide(ride)

// DD completes ride
ride.status = .completed
ride.completionTime = Date()
try await firebase.updateRide(ride)
```

### Fetch DD's Current Rides

```swift
let ddRides = try await firebase.fetchDDRides(ddId: user.id, eventId: eventId)
print("DD has \(ddRides.count) active rides")
```

### Fetch Rider's Ride History

```swift
let riderHistory = try await firebase.fetchRiderRides(riderId: user.id, limit: 20)
for ride in riderHistory {
    print("Ride: \(ride.pickupAddress) - \(ride.status.displayName)")
}
```

## Real-Time Listeners

### Listen to Active Rides (Admin Dashboard)

```swift
import Combine

class AdminViewModel: ObservableObject {
    @Published var activeRides: [Ride] = []
    private var listener: ListenerRegistration?

    func startListening(eventId: String) {
        listener = FirebaseService.shared.listenToActiveRides(eventId: eventId) { [weak self] rides in
            self?.activeRides = rides
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        stopListening()
    }
}
```

### Listen to User Changes

```swift
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    private var listener: ListenerRegistration?

    func startListening(userId: String) {
        listener = FirebaseService.shared.listenToUser(userId: userId) { [weak self] user in
            self?.user = user
        }
    }

    func stopListening() {
        listener?.remove()
    }
}
```

### Listen to Unread Alerts (Admin)

```swift
class AlertsViewModel: ObservableObject {
    @Published var alerts: [AdminAlert] = []
    private var listener: ListenerRegistration?

    func startListening(chapterId: String) {
        listener = FirebaseService.shared.listenToUnreadAlerts(chapterId: chapterId) { [weak self] alerts in
            self?.alerts = alerts
        }
    }

    func stopListening() {
        listener?.remove()
    }
}
```

## Admin Operations

### Create Admin Alert

```swift
let alert = AdminAlert(
    id: firebase.generateDocumentId(for: "adminAlerts"),
    chapterId: user.chapterId,
    type: .ddInactive,
    message: "DD John has toggled inactive 6 times",
    ddId: ddId,
    rideId: nil,
    isRead: false,
    createdAt: Date()
)

try await firebase.createAdminAlert(alert)
```

### Fetch Unread Alerts

```swift
let alerts = try await firebase.fetchUnreadAlerts(chapterId: user.chapterId)
print("You have \(alerts.count) unread alerts")
```

### Mark Alert as Read

```swift
try await firebase.markAlertAsRead(alertId: alert.id)
```

### Fetch Year Transition Logs

```swift
let logs = try await firebase.fetchYearTransitionLogs(limit: 10)
for log in logs {
    print("\(log.executionDate): \(log.seniorsRemoved) seniors removed, \(log.usersAdvanced) advanced")
}
```

## Batch Operations

### Batch Write Example

```swift
let batch = firebase.batch()

// Create multiple rides
for i in 1...5 {
    let rideId = firebase.generateDocumentId(for: "rides")
    let ride = Ride(/* ... */)

    do {
        try firebase.ridesCollection().document(rideId).setData(from: ride)
    } catch {
        print("Error encoding ride: \(error)")
    }
}

// Commit batch
try await batch.commit()
```

## Transaction Example

### Transfer DD Assignment

```swift
try await firebase.runTransaction { transaction in
    // Read old assignment
    let oldAssignmentRef = firebase.ddAssignmentsCollection(eventId: eventId)
        .document(oldDDId)
    let oldAssignment = try transaction.getDocument(oldAssignmentRef).data(as: DDAssignment.self)

    // Update old assignment
    var updatedOld = oldAssignment
    updatedOld.isActive = false
    try transaction.setData(from: updatedOld, forDocument: oldAssignmentRef)

    // Create new assignment
    let newAssignmentRef = firebase.ddAssignmentsCollection(eventId: eventId)
        .document(newDDId)
    let newAssignment = DDAssignment(/* ... */)
    try transaction.setData(from: newAssignment, forDocument: newAssignmentRef)

    return true
}
```

## Error Handling

```swift
do {
    let user = try await firebase.fetchUser(id: userId)
    print("User: \(user.name)")
} catch FirebaseError.userNotFound {
    print("User not found")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Priority Queue Implementation

Here's how to implement the priority queue with automatic priority updates:

```swift
class RideQueueViewModel: ObservableObject {
    @Published var rides: [Ride] = []
    private var listener: ListenerRegistration?
    private var timer: Timer?

    func startListening(eventId: String) {
        // Listen to rides
        listener = FirebaseService.shared.listenToActiveRides(eventId: eventId) { [weak self] rides in
            self?.rides = rides
        }

        // Update priorities every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.updatePriorities()
            }
        }
    }

    func updatePriorities() async {
        for var ride in rides where ride.status == .queued {
            // Calculate wait time in minutes
            let waitTime = Date().timeIntervalSince(ride.requestTime) / 60.0

            // Get rider to access classYear
            if let rider = try? await FirebaseService.shared.fetchUser(id: ride.riderId) {
                // Calculate priority: (classYear × 10) + (waitTime × 0.5)
                let newPriority = Double(rider.classYear * 10) + (waitTime * 0.5)

                if abs(ride.priority - newPriority) > 0.1 {
                    ride.priority = newPriority
                    try? await FirebaseService.shared.updateRide(ride)
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        timer?.invalidate()
    }

    deinit {
        stopListening()
    }
}
```

## Best Practices

### 1. Always Use Listeners for Real-Time Data

```swift
// ✅ Good - Real-time updates
listener = firebase.listenToActiveRides(eventId: eventId) { rides in
    self.rides = rides
}

// ❌ Bad - Polling
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
    Task {
        self.rides = try await firebase.fetchActiveRides(eventId: eventId)
    }
}
```

### 2. Remove Listeners When Done

```swift
class MyViewModel: ObservableObject {
    private var listeners: [ListenerRegistration] = []

    func cleanup() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    deinit {
        cleanup()
    }
}
```

### 3. Handle Errors Gracefully

```swift
func loadData() async {
    do {
        let user = try await firebase.fetchUser(id: userId)
        self.user = user
    } catch {
        self.errorMessage = "Failed to load user data"
        print("Error: \(error)")
    }
}
```

### 4. Use Offline Persistence

Firestore automatically caches data for offline use. Access cached data:

```swift
let user = try await firebase.fetchUser(id: userId)
// This will return cached data if offline
```

### 5. Optimize Reads

```swift
// ✅ Good - Limit results
let rides = try await firebase.fetchRiderRides(riderId: userId, limit: 20)

// ❌ Bad - No limit
let snapshot = try await firebase.ridesCollection()
    .whereField("riderId", isEqualTo: userId)
    .getDocuments()
```

## Testing with Emulators

When running in DEBUG mode, the app automatically connects to emulators:

```bash
# Start emulators
firebase emulators:start

# Run iOS app in simulator
# It will connect to localhost:8080 (Firestore) and localhost:9099 (Auth)
```

## Common Patterns

### Loading State

```swift
class DataViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadData() async {
        isLoading = true
        error = nil

        do {
            data = try await fetchData()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
```

### Pagination

```swift
class PaginatedViewModel: ObservableObject {
    @Published var items: [Item] = []
    private var lastDocument: DocumentSnapshot?

    func loadMore() async {
        let query = firebase.ridesCollection()
            .order(by: "createdAt", descending: true)
            .limit(to: 20)

        let finalQuery = if let lastDoc = lastDocument {
            query.start(afterDocument: lastDoc)
        } else {
            query
        }

        let snapshot = try await finalQuery.getDocuments()
        lastDocument = snapshot.documents.last

        let newItems = snapshot.documents.compactMap { try? $0.data(as: Item.self) }
        items.append(contentsOf: newItems)
    }
}
```

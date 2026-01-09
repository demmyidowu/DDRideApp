# Service Layer Documentation

This directory contains the core service layer for the DD Ride App, implementing all Firebase backend operations and critical business logic.

## Services Overview

### 1. FirestoreService.swift (ENHANCED)
**Purpose**: Core Firestore database operations with generic CRUD, batch operations, and real-time listeners.

**Key Features**:
- Generic CRUD operations for all models
- Query builder with filters
- Batch operations (max 500 per batch)
- Transaction support with retry logic
- Real-time listeners with Combine publishers
- Comprehensive error handling
- Offline persistence support

**Example Usage**:
```swift
// Generic CRUD
let user = try await FirestoreService.shared.fetch(User.self, id: userId, from: "users")
try await FirestoreService.shared.save(user, to: "users")

// Query with filters
let activeRides = try await FirestoreService.shared.query(
    Ride.self,
    from: "rides",
    filters: [
        .equals("eventId", eventId),
        .in("status", ["queued", "assigned", "enroute"])
    ],
    orderBy: "priority",
    descending: true
)

// Real-time listener
FirestoreService.shared.observeActiveRides(eventId: eventId)
    .sink(receiveValue: { rides in
        // Handle updates
    })
    .store(in: &cancellables)

// Batch operations
let operations = [
    BatchOperation.update(collection: "users", id: userId, data: ["classYear": 2]),
    BatchOperation.delete(collection: "users", id: seniorId)
]
try await FirestoreService.shared.executeBatch(operations)
```

**Error Types**:
- `FirestoreError.documentNotFound`
- `FirestoreError.permissionDenied`
- `FirestoreError.networkError`
- `FirestoreError.decodingFailed`
- `FirestoreError.batchLimitExceeded`

---

### 2. RideQueueService.swift (NEW)
**Purpose**: Ride queue management and priority calculations.

**Critical Business Rules**:
- Priority formula: `(classYear × 10) + (waitMinutes × 0.5)`
- Emergency rides: priority = 9999
- Queue position is **OVERALL** across all DDs, not per-DD
- Average ride time: 15 minutes

**Key Features**:
- Priority calculation
- Overall queue position tracking
- Estimated wait time calculation
- Real-time queue updates
- Queue statistics

**Example Usage**:
```swift
// Calculate priority
let priority = RideQueueService.shared.calculatePriority(
    classYear: 4,        // Senior
    waitMinutes: 5.0,    // 5 minutes waiting
    isEmergency: false
)
// Result: (4 × 10) + (5 × 0.5) = 42.5

// Get overall queue position
let position = try await RideQueueService.shared.getOverallQueuePosition(
    rideId: rideId,
    eventId: eventId
)
// Result: 3 (3rd overall, not per-DD)

// Get estimated wait time
let waitMinutes = try await RideQueueService.shared.getEstimatedWaitTime(
    rideId: rideId,
    eventId: eventId
)

// Real-time queue updates
RideQueueService.shared.observeQueueUpdates(eventId: eventId)
    .sink(receiveValue: { sortedRides in
        // Handle queue updates
    })
    .store(in: &cancellables)

// Get queue statistics
let stats = try await RideQueueService.shared.getQueueStats(eventId: eventId)
print("Active rides: \(stats.totalActive)")
print("Active DDs: \(stats.activeDDs)")
print("Average wait: \(stats.averageWaitMinutes) min")
```

**Priority Examples**:
- Senior (4) waiting 5 min: 42.5
- Junior (3) waiting 10 min: 35.0
- Sophomore (2) waiting 20 min: 30.0
- Freshman (1) waiting 15 min: 17.5
- Emergency: 9999

---

### 3. DDAssignmentService.swift (NEW)
**Purpose**: DD assignment logic and activity monitoring.

**Critical Business Rules**:
- Always assign to DD with **SHORTEST WAIT TIME** (not lowest ride count)
- Alert if DD toggles inactive >5 times in 30 minutes
- Alert if DD inactive >15 minutes during shift
- Average ride time: 15 minutes

**Key Features**:
- Wait time calculation for DDs
- Find best DD algorithm
- Atomic ride assignment
- DD activity monitoring
- Admin alert generation
- DD statistics

**Example Usage**:
```swift
// Find best DD (shortest wait time)
let bestDD = try await DDAssignmentService.shared.findBestDD(
    for: event,
    rides: allActiveRides
)

// Assign ride to DD
try await DDAssignmentService.shared.assignRide(ride, to: bestDD)

// Toggle DD status and check for alerts
let alerts = try await DDAssignmentService.shared.toggleDDStatus(
    ddAssignment: assignment,
    isActive: false
)
// Returns alerts if thresholds exceeded

// Check for inactive toggle alerts
if let alert = try await DDAssignmentService.shared.checkInactiveToggles(
    ddAssignment: assignment
) {
    // Alert: DD toggled inactive >5 times
}

// Check for prolonged inactivity
if let alert = try await DDAssignmentService.shared.checkProlongedInactivity(
    ddAssignment: assignment
) {
    // Alert: DD inactive >15 minutes
}

// Get DD statistics
let stats = try await DDAssignmentService.shared.getDDStats(
    ddId: ddId,
    eventId: eventId
)
print("Completed rides: \(stats.totalRidesCompleted)")
print("Avg completion: \(stats.averageCompletionMinutes) min")
```

**Wait Time Calculation**:
- No active rides → 0 minutes
- With active rides → (ride count × 15 minutes)
- Best DD = minimum wait time

---

### 4. YearTransitionService.swift (NEW)
**Purpose**: Annual year transition management.

**Critical Business Rules**:
- Remove all seniors (classYear == 4)
- Increment classYear for everyone else
- Scheduled for August 1st (backend Cloud Scheduler)
- Supports manual admin trigger
- Max 500 operations per batch

**Key Features**:
- Transition eligibility validation
- Batch deletion of seniors
- Batch advancement of remaining users
- Transition preview (dry run)
- Comprehensive logging
- Partial success tracking
- Emergency rollback

**Example Usage**:
```swift
// Validate eligibility
let eligible = try await YearTransitionService.shared.validateTransitionEligibility(
    for: chapter
)

// Preview transition (dry run)
let preview = try await YearTransitionService.shared.previewTransition(
    for: chapter
)
print(preview.summary)
// Output:
// - Seniors to remove: 12
// - Freshmen → Sophomores: 15
// - Sophomores → Juniors: 18
// - Juniors → Seniors: 14

// Execute transition
let log = try await YearTransitionService.shared.executeTransition(
    for: chapter
)
print("Status: \(log.status)")
print("Seniors removed: \(log.seniorsRemoved)")
print("Users advanced: \(log.usersAdvanced)")

// Emergency rollback (cannot restore deleted seniors!)
try await YearTransitionService.shared.rollbackTransition(log: log)
```

**Transition Process**:
1. Fetch all chapter members
2. Separate seniors from others
3. Batch delete seniors (500 at a time)
4. Batch update remaining users (increment classYear)
5. Create audit log
6. Handle partial failures gracefully

---

## Integration Points

### Service Dependencies
```
YearTransitionService → FirestoreService
DDAssignmentService → FirestoreService, RideQueueService
RideQueueService → FirestoreService
FirestoreService → (standalone)
```

### Data Flow
```
1. Ride Request
   └─> RideQueueService (calculate priority)
       └─> FirestoreService (save ride)
           └─> DDAssignmentService (find best DD)
               └─> FirestoreService (assign ride)

2. DD Toggle Inactive
   └─> DDAssignmentService (toggle status)
       └─> FirestoreService (update assignment)
           └─> DDAssignmentService (check alerts)
               └─> FirestoreService (create alerts)

3. Year Transition
   └─> YearTransitionService (execute)
       └─> FirestoreService (batch delete seniors)
           └─> FirestoreService (batch update users)
               └─> FirestoreService (create log)
```

---

## Error Handling

All services use consistent error handling:

```swift
do {
    let result = try await service.someOperation()
} catch FirestoreError.documentNotFound {
    // Handle not found
} catch FirestoreError.permissionDenied {
    // Handle permission error
} catch FirestoreError.networkError(let error) {
    // Handle network error
} catch {
    // Handle unknown error
}
```

---

## Real-time Updates

All services support real-time updates via Combine:

```swift
private var cancellables = Set<AnyCancellable>()

// Observe rides
FirestoreService.shared.observeActiveRides(eventId: eventId)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { rides in
            self.rides = rides
        }
    )
    .store(in: &cancellables)

// Observe queue position
RideQueueService.shared.observeRidePosition(rideId: rideId, eventId: eventId)
    .sink(receiveValue: { position in
        self.queuePosition = position
    })
    .store(in: &cancellables)

// Observe admin alerts
FirestoreService.shared.observeAdminAlerts(chapterId: chapterId)
    .sink(receiveValue: { alerts in
        self.unreadAlerts = alerts
    })
    .store(in: &cancellables)
```

---

## Testing

### Unit Test Examples

```swift
class RideQueueServiceTests: XCTestCase {
    func testPriorityCalculation() {
        let service = RideQueueService.shared

        // Test senior waiting 5 minutes
        let priority = service.calculatePriority(classYear: 4, waitMinutes: 5, isEmergency: false)
        XCTAssertEqual(priority, 42.5)

        // Test emergency
        let emergencyPriority = service.calculatePriority(classYear: 1, waitMinutes: 0, isEmergency: true)
        XCTAssertEqual(emergencyPriority, 9999)
    }
}

class DDAssignmentServiceTests: XCTestCase {
    func testFindBestDD() async throws {
        // Create test DDs with different ride counts
        // Verify shortest wait time is selected
    }
}

class YearTransitionServiceTests: XCTestCase {
    func testTransitionEligibility() async throws {
        // Test before August 1st → false
        // Test after August 1st → true
        // Test already transitioned → false
    }
}
```

---

## Best Practices

### 1. Always Use @MainActor
All services are marked `@MainActor` for SwiftUI integration:
```swift
@MainActor
class SomeService: ObservableObject {
    static let shared = SomeService()
}
```

### 2. Use Async/Await
Always use async/await for Firestore operations:
```swift
// ✅ Good
let user = try await firestoreService.fetchUser(id: userId)

// ❌ Bad (old callback style)
firestoreService.fetchUser(id: userId) { result in ... }
```

### 3. Handle Errors Properly
Use typed errors and provide user-friendly messages:
```swift
catch FirestoreError.permissionDenied {
    showAlert("You don't have permission to perform this action")
}
```

### 4. Use Combine for Real-time Updates
Prefer Combine publishers over callback listeners:
```swift
// ✅ Good
service.observeRides(eventId: id)
    .sink(receiveValue: { rides in ... })
    .store(in: &cancellables)

// ❌ Bad (callback style harder to manage)
let listener = service.listenToRides(eventId: id) { rides in ... }
```

### 5. Batch Operations When Possible
Use batch operations for multiple writes:
```swift
// ✅ Good
let operations = users.map { user in
    BatchOperation.update(collection: "users", id: user.id, data: [...])
}
try await firestoreService.executeBatch(operations)

// ❌ Bad (multiple individual writes)
for user in users {
    try await firestoreService.updateUser(user)
}
```

---

## Cost Optimization

### Read Optimization
- Use real-time listeners sparingly (only for active data)
- Implement client-side caching
- Use query limits when appropriate

### Write Optimization
- Batch writes when possible (500 max per batch)
- Avoid unnecessary updates
- Use merge: true for partial updates

### Firestore Pricing Impact
- Document reads: Most expensive operation
- Document writes: Moderate cost
- Real-time listeners: Counted as 1 read per document on attach + 1 read per change
- Batch operations: Same cost as individual operations, but more efficient

---

## Cloud Functions Integration

While these services run on the client, they integrate with Cloud Functions:

### 1. Ride Assignment Trigger
```typescript
// functions/src/rideAssignment.ts
export const assignRideToDD = functions.firestore
    .document('rides/{rideId}')
    .onCreate(async (snapshot, context) => {
        // Backend assignment logic
    });
```

### 2. Year Transition Scheduled Function
```typescript
// functions/src/yearTransition.ts
export const yearTransition = functions.pubsub
    .schedule('0 0 1 8 *') // August 1st at midnight
    .onRun(async (context) => {
        // Execute transition
    });
```

### 3. DD Monitoring Functions
```typescript
// functions/src/ddMonitoring.ts
export const monitorDDActivity = functions.firestore
    .document('ddAssignments/{ddId}')
    .onUpdate(async (change, context) => {
        // Monitor activity
    });
```

---

## Security Considerations

All Firestore operations respect security rules:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only update their own profile
    match /users/{userId} {
      allow update: if request.auth.uid == userId || isAdmin();
    }

    // Only admins can execute year transitions
    match /yearTransitionLogs/{logId} {
      allow read: if isAdmin();
      allow write: if false; // Only Cloud Functions
    }
  }
}
```

---

## Maintenance

### Regular Tasks
- **Every minute**: Update ride priorities (increasing wait times)
- **Every 30 minutes**: Reset DD inactive toggle counts
- **August 1st**: Execute year transition
- **Weekly**: Review transition logs and error rates

### Monitoring
- Track batch operation success rates
- Monitor real-time listener performance
- Review admin alerts for patterns
- Audit year transition logs

---

## File Summary

| File | Lines | Purpose |
|------|-------|---------|
| FirestoreService.swift | ~700 | Generic Firestore CRUD + real-time listeners |
| RideQueueService.swift | ~350 | Queue management + priority calculation |
| DDAssignmentService.swift | ~400 | DD assignment + activity monitoring |
| YearTransitionService.swift | ~400 | Year transition management |

**Total**: ~1,850 lines of production-ready service layer code

---

## Quick Reference

### Priority Calculation
```swift
priority = (classYear × 10) + (waitMinutes × 0.5)
emergency = 9999
```

### DD Assignment
```swift
bestDD = DD with minimum wait time
waitTime = activeRides × 15 minutes
```

### Queue Position
```swift
position = overall position across ALL DDs (1-indexed)
```

### Year Transition
```swift
Remove: classYear == 4
Advance: classYear++ for everyone else
```

---

For questions or issues, refer to the inline documentation in each service file.

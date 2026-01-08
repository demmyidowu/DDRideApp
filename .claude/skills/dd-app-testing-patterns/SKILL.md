---
name: dd-app-testing-patterns
description: Testing patterns specific to the DD Ride app. Use when writing tests for ride flows, queue algorithms, admin features, or year transitions.
---

# DD App Testing Patterns

## Firebase Emulator Setup

Always test with emulators before production:
```bash
# Start emulators
firebase emulators:start --only firestore,functions,auth

# In tests, connect to emulator
let settings = Firestore.firestore().settings
settings.host = "localhost:8080"
settings.isSSLEnabled = false
Firestore.firestore().settings = settings
```

## Test Data Factory
```swift
class TestDataFactory {
    static func createTestChapter() -> Chapter {
        Chapter(
            id: "test-sae-\(UUID().uuidString)",
            name: "Sigma Alpha Epsilon",
            universityId: "ksu",
            inviteCode: "TEST123",
            yearTransitionDate: "08-01"
        )
    }
    
    static func createTestUser(classYear: Int, role: UserRole = .member) -> User {
        User(
            id: UUID().uuidString,
            name: "Test User \(classYear)",
            email: "test\(Int.random(in: 1000...9999))@ksu.edu",
            phoneNumber: "+1555555\(String(format: "%04d", Int.random(in: 0...9999)))",
            chapterId: "test-sae",
            role: role,
            classYear: classYear
        )
    }
    
    static func createTestEvent(allowedChapters: [String] = ["ALL"]) -> Event {
        Event(
            id: UUID().uuidString,
            chapterId: "test-sae",
            name: "Thursday Party",
            date: Date(),
            allowedChapterIds: allowedChapters,
            status: .active
        )
    }
    
    static func createTestDDAssignment(userId: String, eventId: String) -> DDAssignment {
        DDAssignment(
            userId: userId,
            eventId: eventId,
            photoURL: "https://example.com/photo.jpg",
            carDescription: "Black Honda Civic, ABC123",
            isActive: true,
            inactiveToggles: 0,
            totalRidesCompleted: 0
        )
    }
    
    static func createTestRide(eventId: String, riderId: String, isEmergency: Bool = false) -> Ride {
        Ride(
            id: UUID().uuidString,
            eventId: eventId,
            riderId: riderId,
            riderName: "Test Rider",
            riderPhoneNumber: "+15555551234",
            pickupAddress: "123 Main St, Manhattan, KS",
            pickupLocation: GeoPoint(latitude: 39.1836, longitude: -96.5717),
            status: .queued,
            priority: isEmergency ? 9999 : 20.0,
            requestTime: Date(),
            isEmergency: isEmergency
        )
    }
}
```

## Critical Test Scenarios

### 1. Queue Priority Algorithm
```swift
import XCTest
@testable import DDRide

class QueuePriorityTests: XCTestCase {
    
    func testSeniorPriorityOverFreshman() {
        let senior5min = RideQueueService().calculatePriority(
            classYear: 4,
            waitMinutes: 5,
            isEmergency: false
        )
        
        let freshman15min = RideQueueService().calculatePriority(
            classYear: 1,
            waitMinutes: 15,
            isEmergency: false
        )
        
        XCTAssertGreaterThan(senior5min, freshman15min)
        // Expected: 42.5 > 17.5
    }
    
    func testEmergencyMaxPriority() {
        let emergency = RideQueueService().calculatePriority(
            classYear: 1,
            waitMinutes: 1,
            isEmergency: true
        )
        
        XCTAssertEqual(emergency, 9999)
    }
    
    func testPriorityIncreasesWithWaitTime() {
        let wait5 = RideQueueService().calculatePriority(
            classYear: 3,
            waitMinutes: 5,
            isEmergency: false
        )
        
        let wait15 = RideQueueService().calculatePriority(
            classYear: 3,
            waitMinutes: 15,
            isEmergency: false
        )
        
        XCTAssertGreaterThan(wait15, wait5)
    }
}
```

### 2. DD Assignment Based on Wait Time
```swift
class DDAssignmentTests: XCTestCase {
    var service: DDAssignmentService!
    
    override func setUp() {
        super.setUp()
        service = DDAssignmentService()
    }
    
    func testAssignToAvailableDD() async throws {
        // Create 3 DDs with different workloads
        let dd1 = TestDataFactory.createTestDDAssignment(userId: "dd1", eventId: "event1")
        let dd2 = TestDataFactory.createTestDDAssignment(userId: "dd2", eventId: "event1")
        let dd3 = TestDataFactory.createTestDDAssignment(userId: "dd3", eventId: "event1")
        
        // DD1 has 2 active rides
        let ride1 = TestDataFactory.createTestRide(eventId: "event1", riderId: "rider1")
        let ride2 = TestDataFactory.createTestRide(eventId: "event1", riderId: "rider2")
        var ride1Active = ride1
        ride1Active.ddId = "dd1"
        ride1Active.status = .enroute
        var ride2Active = ride2
        ride2Active.ddId = "dd1"
        ride2Active.status = .assigned
        
        // DD2 has 1 active ride
        let ride3 = TestDataFactory.createTestRide(eventId: "event1", riderId: "rider3")
        var ride3Active = ride3
        ride3Active.ddId = "dd2"
        ride3Active.status = .assigned
        
        // DD3 has no active rides
        
        let rides = [ride1Active, ride2Active, ride3Active]
        
        // Calculate wait times
        let wait1 = service.calculateWaitTime(for: dd1, with: rides)
        let wait2 = service.calculateWaitTime(for: dd2, with: rides)
        let wait3 = service.calculateWaitTime(for: dd3, with: rides)
        
        XCTAssertEqual(wait3, 0) // DD3 available immediately
        XCTAssertGreaterThan(wait1, wait2) // DD1 busier than DD2
        XCTAssertGreaterThan(wait1, wait3) // DD1 busier than DD3
    }
}
```

### 3. Overall Queue Position
```swift
class QueuePositionTests: XCTestCase {
    
    func testOverallQueuePosition() async throws {
        let service = RideQueueService()
        let event = TestDataFactory.createTestEvent()
        
        // Create 5 rides with different priorities
        let rides = [
            TestDataFactory.createTestRide(eventId: event.id, riderId: "rider1", isEmergency: true), // Priority 9999
            createRideWithPriority(42.5), // Senior, 5 min wait
            createRideWithPriority(35.0), // Junior, 5 min wait
            createRideWithPriority(25.5), // Sophomore, 5 min wait
            createRideWithPriority(17.5)  // Freshman, 15 min wait
        ]
        
        // Save to Firestore
        for ride in rides {
            try await saveRide(ride)
        }
        
        // Check positions
        let position1 = try await service.getOverallQueuePosition(for: rides[0].id, in: event.id)
        let position2 = try await service.getOverallQueuePosition(for: rides[1].id, in: event.id)
        let position5 = try await service.getOverallQueuePosition(for: rides[4].id, in: event.id)
        
        XCTAssertEqual(position1, 1) // Emergency first
        XCTAssertEqual(position2, 2) // Senior second
        XCTAssertEqual(position5, 5) // Freshman last
    }
}
```

### 4. Year Transition
```swift
class YearTransitionTests: XCTestCase {
    var service: YearTransitionService!
    
    override func setUp() {
        super.setUp()
        service = YearTransitionService()
    }
    
    func testYearTransition() async throws {
        let chapter = TestDataFactory.createTestChapter()
        
        // Create users of each class year
        let senior = TestDataFactory.createTestUser(classYear: 4)
        let junior = TestDataFactory.createTestUser(classYear: 3)
        let sophomore = TestDataFactory.createTestUser(classYear: 2)
        let freshman = TestDataFactory.createTestUser(classYear: 1)
        
        // Save to Firestore
        try await saveUsers([senior, junior, sophomore, freshman])
        
        // Execute transition
        let log = try await service.executeTransition(for: chapter)
        
        // Verify seniors deleted
        let seniorExists = try? await fetchUser(id: senior.id)
        XCTAssertNil(seniorExists)
        
        // Verify others advanced
        let juniorAfter = try await fetchUser(id: junior.id)
        let sophomoreAfter = try await fetchUser(id: sophomore.id)
        let freshmanAfter = try await fetchUser(id: freshman.id)
        
        XCTAssertEqual(juniorAfter.classYear, 4)
        XCTAssertEqual(sophomoreAfter.classYear, 3)
        XCTAssertEqual(freshmanAfter.classYear, 2)
        
        // Verify log
        XCTAssertEqual(log.seniorsRemoved, 1)
        XCTAssertEqual(log.usersAdvanced, 3)
        XCTAssertEqual(log.status, .success)
    }
}
```

### 5. DD Inactivity Monitoring
```swift
class DDMonitoringTests: XCTestCase {
    
    func testFrequentTogglesAlert() async throws {
        let service = DDMonitoringService()
        let dd = TestDataFactory.createTestDDAssignment(userId: "dd1", eventId: "event1")
        
        // Simulate 6 toggles
        for i in 0..<6 {
            var toggledDD = dd
            toggledDD.inactiveToggles = i + 1
            toggledDD.isActive = i % 2 == 0
            
            try await service.checkInactivityAbuse(for: toggledDD)
        }
        
        // Verify admin alert was created
        let alerts = try await fetchAdminAlerts(type: .ddInactive)
        XCTAssertGreaterThan(alerts.count, 0)
    }
    
    func testProlongedInactivityNotification() async throws {
        let service = DDMonitoringService()
        var dd = TestDataFactory.createTestDDAssignment(userId: "dd1", eventId: "event1")
        
        // Set DD as inactive 20 minutes ago
        dd.isActive = false
        dd.lastInactiveTimestamp = Date().addingTimeInterval(-20 * 60)
        
        try await service.checkProlongedInactivity(for: dd)
        
        // Verify notification was sent (check FCM or logs)
        // This would require mocking FCM service
    }
}
```

### 6. Emergency Request
```swift
class EmergencyRequestTests: XCTestCase {
    
    func testEmergencyImmediatePriority() async throws {
        let service = EmergencyService()
        
        let coordinate = CLLocationCoordinate2D(latitude: 39.1836, longitude: -96.5717)
        
        let ride = try await service.handleEmergencyRequest(
            riderId: "rider1",
            location: coordinate,
            reason: .safetyConcern
        )
        
        XCTAssertEqual(ride.priority, 9999)
        XCTAssertTrue(ride.isEmergency)
        XCTAssertEqual(ride.emergencyReason, "safetyConcern")
        
        // Verify admin was notified
        let alerts = try await fetchAdminAlerts(type: .emergency_request)
        XCTAssertEqual(alerts.count, 1)
    }
}
```

## Test Coverage Goals

- **Unit Tests**: 80%+ coverage
- **Integration Tests**: All critical user flows
- **UI Tests**: Main user journeys

## Running Tests
```bash
# Run all tests
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -only-testing:DDRideTests/QueuePriorityTests

# With Firebase emulators
firebase emulators:exec --only firestore,functions \
  "xcodebuild test -workspace ios/DDRide.xcworkspace -scheme DDRide"
```

## Best Practices

1. **Always use test data factory** for consistent test data
2. **Test with Firebase emulators** never real database
3. **Clean up after each test** to avoid state pollution
4. **Use async/await** for all Firebase operations
5. **Mock external services** (Twilio, push notifications)
6. **Test edge cases** (no DDs available, network errors, etc.)
7. **Write descriptive test names** that explain what's being tested

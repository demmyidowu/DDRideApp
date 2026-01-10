# Integration Tests - DD Ride App

This directory contains comprehensive integration tests for the DD Ride iOS app. These tests verify complete end-to-end workflows using Firebase emulators.

## Test Files

### 1. RideFlowIntegrationTests.swift
Tests the complete ride request lifecycle from request to completion.

**Test Coverage:**
- Complete ride flow: queued → assigned → enroute → completed
- Multiple riders with priority-based queuing
- Multiple DDs with load balancing (wait time based)
- Emergency rides get immediate priority
- Ride cancellation
- Cross-chapter rides have lower priority
- No available DDs scenario

**Key Business Logic Tested:**
- Queue priority algorithm: `priority = (classYear × 10) + (waitTime × 0.5)`
- Emergency priority: `9999` (always first)
- DD assignment: Based on shortest wait time
- Overall queue position across all DDs

### 2. EmergencyFlowTests.swift
Tests emergency ride request workflow and admin alert system.

**Test Coverage:**
- Emergency ride creation with priority 9999
- Admin alert generation on emergency requests
- Emergency rides bypass all normal rides (even seniors)
- Multiple emergencies ordered by time (FIFO)
- Emergency ride count tracking
- Error handling for invalid users

**Key Business Logic Tested:**
- Emergency rides always have priority 9999
- Admin alerts created immediately
- Emergency bypasses class year priority
- Multiple emergencies ordered by `requestedAt` timestamp

### 3. DDMonitoringTests.swift
Tests DD activity monitoring and alert system.

**Test Coverage:**
- Excessive inactive toggles detection (>5 in 30 minutes)
- Prolonged inactivity detection (>15 minutes during shift)
- Auto-reset toggle counter after 30 minutes
- Manual reset toggle counter
- Combined monitoring (both toggle and inactivity alerts)
- No alerts when event is inactive
- Monitoring statistics accuracy
- Reset all toggle counters for event

**Key Business Logic Tested:**
- Toggle threshold: 5 toggles in 30 minutes
- Inactivity threshold: 15 minutes during active shift
- Auto-reset: Every 30 minutes
- Alerts only during active events

### 4. AdminTransitionTests.swift
Tests admin role transition workflow and audit logging.

**Test Coverage:**
- Successful role transfer (atomic transaction)
- Transition audit log creation
- Transaction atomicity (both users updated or neither)
- Validation: Cannot transfer to different chapter
- Validation: Cannot transfer from non-admin
- Validation: Cannot transfer to nonexistent user
- Validation: Cannot transfer to same user
- Multiple transitions in sequence
- Fetch transition history
- Get current admins for chapter
- Preserve other user data during transition

**Key Business Logic Tested:**
- Atomic transaction: Both role changes succeed or both fail
- Audit trail: All transitions logged with timestamps
- Validation: Both users must be in same chapter
- Only current admin can transfer role

## Running the Tests

### Prerequisites
1. Firebase emulators must be running
2. Firestore emulator on `localhost:8080`
3. Auth emulator on `localhost:9099`

### Start Firebase Emulators
```bash
# Terminal 1: Start emulators
cd /Users/didowu/DDRideApp
firebase emulators:start --only firestore,auth
```

### Run All Integration Tests
```bash
# Terminal 2: Run all integration tests
cd /Users/didowu/DDRideApp/ios
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DDRideTests/EmergencyFlowTests \
  -only-testing:DDRideTests/DDMonitoringTests \
  -only-testing:DDRideTests/AdminTransitionTests \
  -only-testing:DDRideTests/RideFlowIntegrationTests
```

### Run Specific Test File
```bash
# Run only emergency flow tests
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DDRideTests/EmergencyFlowTests

# Run only DD monitoring tests
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DDRideTests/DDMonitoringTests

# Run only admin transition tests
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DDRideTests/AdminTransitionTests
```

### Run Specific Test Case
```bash
# Run a specific test method
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DDRideTests/EmergencyFlowTests/testEmergencyRequestFlow
```

## Test Structure

All integration tests follow this pattern:

```swift
final class MyIntegrationTests: DDRideTestCase {
    // Services under test
    var myService: MyService!

    // Test data
    var chapter: Chapter!
    var event: Event!
    var user: User!

    override func setUp() async throws {
        try await super.setUp()

        // Initialize services
        myService = MyService.shared

        // Create test data
        chapter = TestDataFactory.createTestChapter()
        try await saveChapter(chapter)

        // ... more setup
    }

    // Test cases
    func testMyFeature() async throws {
        // ARRANGE
        // Set up test conditions

        // ACT
        // Execute the action being tested

        // ASSERT
        // Verify the results
    }
}
```

## Test Helpers

### TestConfiguration
- Automatic Firebase emulator setup
- Firestore data cleanup before/after each test
- One-time configuration

### TestDataFactory
- Create consistent test data
- All data uses unique IDs
- Realistic data that matches production structure

**Available Methods:**
- `createTestChapter()`
- `createTestUser(classYear:role:chapterId:)`
- `createTestEvent(chapterId:status:)`
- `createTestDDAssignment(userId:eventId:isActive:)`
- `createTestRide(riderId:eventId:classYear:waitMinutes:isEmergency:)`
- `createTestAdminAlert(chapterId:type:message:)`

### FirestoreTestHelpers
Convenience methods for Firestore operations in tests.

**Save Methods:**
- `saveChapter(_:)`
- `saveUser(_:)`, `saveUsers(_:)`
- `saveEvent(_:)`
- `saveDDAssignment(_:)`, `saveDDAssignments(_:)`
- `saveRide(_:)`, `saveRides(_:)`
- `saveAdminAlert(_:)`
- `saveAdminTransitionLog(_:)`

**Fetch Methods:**
- `fetchChapter(id:)`
- `fetchUser(id:)`
- `fetchEvent(id:)`
- `fetchRide(id:)`
- `fetchDDAssignment(id:)`
- `fetchAdminAlerts(chapterId:type:)`
- `fetchAdminTransitionLogs(chapterId:)`
- `fetchUsersForChapter(_:)`
- `fetchRidesForEvent(_:)`
- `fetchDDAssignmentsForEvent(_:)`

**Utility Methods:**
- `deleteDocument(id:from:)`
- `countDocuments(in:whereField:isEqualTo:)`

## Test Principles

### 1. Isolation
Each test is independent and doesn't rely on other tests. Firestore is cleared before and after each test.

### 2. Arrange-Act-Assert
Tests follow AAA pattern:
- **Arrange**: Set up test data and conditions
- **Act**: Execute the action being tested
- **Assert**: Verify the results

### 3. Descriptive Names
Test names clearly explain what's being tested:
```swift
func testEmergencyRequestFlow()
func testFrequentTogglesCreatesAlert()
func testSuccessfulRoleTransfer()
```

### 4. End-to-End Testing
Integration tests verify complete workflows, not just individual methods:
- Create data → Execute workflow → Verify all state changes
- Check Firestore persistence
- Verify related entities are updated

### 5. Error Cases
Tests cover both success and failure scenarios:
- Valid inputs
- Invalid inputs
- Edge cases
- Transaction rollbacks

## Coverage Goals

- **Integration Tests**: All critical user flows
- **Business Logic**: All priority calculations, monitoring rules, atomic transactions
- **Error Handling**: All validation failures and error states
- **Data Persistence**: All Firestore operations

## Continuous Integration

These tests should be run:
- Before every commit
- In CI/CD pipeline
- Before deploying to TestFlight
- After any changes to business logic

## Debugging Tests

### View Test Output
```bash
# Verbose output
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DDRideTests/EmergencyFlowTests \
  | xcpretty --test
```

### Check Firestore Emulator
1. Open `http://localhost:4000` in browser
2. View Firestore tab
3. Inspect data created by tests
4. Verify data cleanup

### Common Issues

**Issue: Tests fail with "Firestore not configured"**
- Solution: Ensure Firebase emulators are running
- Check emulator is on correct port (8080 for Firestore)

**Issue: Tests fail intermittently**
- Solution: Ensure proper cleanup between tests
- Check for race conditions with async operations

**Issue: Test data persists between tests**
- Solution: Verify `setUp()` and `tearDown()` call `super`
- Check `TestConfiguration.shared.clearFirestore()` is working

## Future Enhancements

- [ ] Add performance benchmarks
- [ ] Test with slow network conditions
- [ ] Test with large data sets
- [ ] Add UI automation tests
- [ ] Test notification delivery (when FCM implemented)
- [ ] Test SMS sending (when Twilio integrated)

## Contributing

When adding new integration tests:

1. Follow the existing test structure
2. Use TestDataFactory for test data
3. Use FirestoreTestHelpers for persistence
4. Clean up after tests
5. Document complex test scenarios
6. Test both success and failure paths
7. Verify Firestore state changes

## Related Documentation

- `/ios/DDRide/Tests/README.md` - Overall testing strategy
- `/ios/DDRide/Tests/Services/` - Unit tests for services
- `/ios/DDRide/Tests/TestHelpers/` - Test helper documentation
- `/CLAUDE.md` - Project overview and business rules

# DD Ride App - Test Suite

Comprehensive unit and integration tests for the DD Ride iOS app.

## Test Structure

```
Tests/
├── TestHelpers/
│   ├── TestConfiguration.swift       # Firebase emulator setup
│   ├── TestDataFactory.swift         # Consistent test data creation
│   └── FirestoreTestHelpers.swift    # Firestore helper methods
├── Services/
│   ├── RideQueueServiceTests.swift   # Priority algorithm tests
│   ├── DDAssignmentServiceTests.swift # DD assignment tests
│   └── YearTransitionServiceTests.swift # Year transition tests
└── Integration/
    └── RideFlowIntegrationTests.swift # End-to-end ride flow tests
```

## Prerequisites

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Firebase Project

```bash
cd /Users/didowu/DDRideApp
firebase init emulators
```

Select:
- Firestore Emulator (port 8080)
- Authentication Emulator (port 9099)

## Running Tests

### Option 1: With Firebase Emulators (Recommended)

This is the **recommended** way to run tests. It uses local emulators so you never touch production data.

```bash
# Terminal 1: Start Firebase emulators
cd /Users/didowu/DDRideApp
firebase emulators:start --only firestore,auth

# Terminal 2: Run tests
cd /Users/didowu/DDRideApp/ios
xcodebuild test \
  -workspace DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Option 2: Run Tests with Emulator Auto-Start

Use Firebase CLI to automatically start/stop emulators:

```bash
cd /Users/didowu/DDRideApp
firebase emulators:exec --only firestore,auth \
  "cd ios && xcodebuild test -workspace DDRide.xcworkspace -scheme DDRide -destination 'platform=iOS Simulator,name=iPhone 15'"
```

### Option 3: Run from Xcode

1. Start Firebase emulators manually:
   ```bash
   cd /Users/didowu/DDRideApp
   firebase emulators:start --only firestore,auth
   ```

2. Open Xcode:
   ```bash
   cd ios
   open DDRide.xcworkspace
   ```

3. Run tests:
   - Press `Cmd+U` to run all tests
   - Or click the diamond icon next to individual test functions

## Test Categories

### Unit Tests

Test individual service methods in isolation:

#### RideQueueServiceTests
- **Priority Algorithm**: Verifies exact priority calculations
- **Same Chapter**: Tests `(classYear × 10) + (waitMinutes × 0.5)`
- **Cross Chapter**: Tests `waitMinutes × 0.5` (class year ignored)
- **Emergency**: Tests priority = 9999
- **Edge Cases**: Zero wait, negative wait, high wait times

**Run specific test:**
```bash
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -only-testing:DDRideTests/RideQueueServiceTests
```

#### DDAssignmentServiceTests
- **Wait Time Calculation**: DD with N rides has N × 15 minutes wait
- **Find Best DD**: Always assigns to DD with shortest wait time
- **Inactive DDs**: Ensures inactive DDs are not assigned
- **Load Balancing**: Tests with multiple DDs and varying workloads

**Run specific test:**
```bash
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -only-testing:DDRideTests/DDAssignmentServiceTests
```

#### YearTransitionServiceTests
- **Remove Seniors**: Deletes all users with classYear == 4
- **Advance Others**: Increments classYear for remaining users
- **Data Preservation**: Ensures other user fields remain unchanged
- **Multi-Chapter**: Only affects specified chapter
- **Audit Logs**: Creates transition logs

**Run specific test:**
```bash
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -only-testing:DDRideTests/YearTransitionServiceTests
```

### Integration Tests

Test complete workflows with multiple services:

#### RideFlowIntegrationTests
- **Complete Flow**: Request → Assigned → En Route → Completed
- **Multiple Riders**: Priority-based queue ordering
- **Multiple DDs**: Load balancing across DDs
- **Emergency Rides**: Emergency overtakes regular rides
- **Cross-Chapter**: Lower priority for cross-chapter riders
- **Cancellation**: Rider cancels queued ride

**Run specific test:**
```bash
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -only-testing:DDRideTests/RideFlowIntegrationTests
```

## Test Data Factory

All tests use `TestDataFactory` for consistent test data:

```swift
// Create chapter
let chapter = TestDataFactory.createTestChapter()

// Create user
let senior = TestDataFactory.createTestUser(classYear: 4, chapterId: chapter.id)

// Create event
let event = TestDataFactory.createTestEvent(chapterId: chapter.id)

// Create DD assignment
let assignment = TestDataFactory.createTestDDAssignment(userId: dd.id, eventId: event.id)

// Create ride
let ride = TestDataFactory.createTestRide(
    riderId: rider.id,
    eventId: event.id,
    classYear: 3,
    waitMinutes: 5.0,
    isEmergency: false
)
```

## Test Coverage

Run tests with coverage enabled:

```bash
xcodebuild test \
  -workspace ios/DDRide.xcworkspace \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# View coverage report
xcrun xccov view --report TestResults.xcresult
```

**Coverage Goals:**
- Unit Tests: 80%+ coverage
- Integration Tests: All critical user flows
- Priority: Business logic (queue, assignment, transitions)

## Debugging Tests

### View Firestore Data During Tests

Access the Firestore Emulator UI while tests are running:

```
http://localhost:4000
```

This shows all documents created during tests in real-time.

### Common Issues

#### 1. Emulators Not Running

**Error:**
```
Connection refused - localhost:8080
```

**Solution:**
```bash
firebase emulators:start --only firestore,auth
```

#### 2. Port Already in Use

**Error:**
```
Port 8080 is not open
```

**Solution:**
```bash
# Find and kill process on port 8080
lsof -ti:8080 | xargs kill -9

# Restart emulators
firebase emulators:start --only firestore,auth
```

#### 3. Test Data Not Cleaning Up

**Issue:** Tests fail because of leftover data from previous tests

**Solution:**
All tests inherit from `DDRideTestCase` which automatically clears Firestore before and after each test. If you create a test without inheriting from `DDRideTestCase`, you'll have this problem.

**Fix:**
```swift
// ✅ Correct
final class MyTests: DDRideTestCase { }

// ❌ Wrong
final class MyTests: XCTestCase { }
```

#### 4. Async Test Timeout

**Error:**
```
Asynchronous wait failed: Exceeded timeout
```

**Solution:**
Ensure you're using `async/await` correctly:

```swift
// ✅ Correct
func testSomething() async throws {
    let result = try await someAsyncFunction()
    XCTAssertNotNil(result)
}

// ❌ Wrong (missing async throws)
func testSomething() {
    let result = try await someAsyncFunction() // Won't compile
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: iOS Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3

      - name: Install Firebase CLI
        run: npm install -g firebase-tools

      - name: Run Tests with Emulators
        run: |
          firebase emulators:exec --only firestore,auth \
            "cd ios && xcodebuild test \
              -workspace DDRide.xcworkspace \
              -scheme DDRide \
              -destination 'platform=iOS Simulator,name=iPhone 15' \
              -enableCodeCoverage YES"
```

## Best Practices

1. **Always Use Emulators**: Never run tests against production Firebase
2. **Use TestDataFactory**: Create consistent test data
3. **Inherit from DDRideTestCase**: Automatic cleanup
4. **Test Business Logic**: Focus on critical algorithms (priority, assignment, transitions)
5. **Descriptive Names**: Test names should explain what's being tested
6. **One Assertion Per Test**: Each test should verify one behavior
7. **Async/Await**: All Firebase operations use async/await
8. **Clean State**: Each test starts with clean Firestore

## Writing New Tests

### Template for Unit Test

```swift
import XCTest
@testable import DDRide

final class MyServiceTests: DDRideTestCase {
    var service: MyService!

    override func setUp() async throws {
        try await super.setUp() // Important: calls parent setUp
        service = MyService.shared
    }

    func testSomething() async throws {
        // Given: Setup test data
        let user = TestDataFactory.createTestUser(classYear: 3)
        try await saveUser(user)

        // When: Execute the operation
        let result = try await service.doSomething(userId: user.id)

        // Then: Verify the result
        XCTAssertNotNil(result)
        XCTAssertEqual(result.id, user.id)
    }
}
```

### Template for Integration Test

```swift
import XCTest
@testable import DDRide

final class MyFlowIntegrationTests: DDRideTestCase {
    var chapter: Chapter!
    var event: Event!

    override func setUp() async throws {
        try await super.setUp()

        chapter = TestDataFactory.createTestChapter()
        event = TestDataFactory.createTestEvent(chapterId: chapter.id)

        try await saveChapter(chapter)
        try await saveEvent(event)
    }

    func testCompleteFlow() async throws {
        // Step 1: Do something
        // Step 2: Verify intermediate state
        // Step 3: Do next thing
        // Step 4: Verify final state
    }
}
```

## Additional Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Firebase Emulators](https://firebase.google.com/docs/emulator-suite)
- [Async Testing in Swift](https://developer.apple.com/documentation/xctest/asynchronous_tests_and_expectations)

## Questions?

If tests are failing or you need help:

1. Check that Firebase emulators are running: `http://localhost:4000`
2. Verify you're inheriting from `DDRideTestCase`
3. Check Firebase Emulator logs for errors
4. Review test output in Xcode or terminal

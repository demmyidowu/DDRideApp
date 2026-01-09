# DD Interface Testing Guide

Comprehensive testing scenarios for the DD (Designated Driver) interface.

## Prerequisites

Before testing:
1. Firebase project configured
2. Firebase emulators running (optional but recommended)
3. Info.plist permissions added (Camera, Photo Library, Location)
4. Test user account with:
   - Role: member
   - Chapter assigned
5. Test event created with status: active
6. Test user assigned as DD for event (DDAssignment document)

## Test Environment Setup

### Firebase Emulators
```bash
firebase emulators:start --only firestore,storage,auth
```

### Test Data
Create these Firestore documents in emulator:

**Event** (`events/{eventId}`):
```json
{
  "id": "test-event-1",
  "name": "Test Event",
  "chapterId": "test-chapter",
  "date": "2026-01-09T20:00:00Z",
  "allowedChapterIds": ["test-chapter"],
  "status": "active",
  "createdAt": "2026-01-09T18:00:00Z",
  "updatedAt": "2026-01-09T18:00:00Z",
  "createdBy": "admin-user-id"
}
```

**DD Assignment** (`ddAssignments/{userId}`):
```json
{
  "id": "test-dd-user-id",
  "userId": "test-dd-user-id",
  "eventId": "test-event-1",
  "photoURL": null,
  "carDescription": null,
  "isActive": false,
  "inactiveToggles": 0,
  "lastActiveTimestamp": null,
  "lastInactiveTimestamp": null,
  "totalRidesCompleted": 5,
  "createdAt": "2026-01-09T18:00:00Z",
  "updatedAt": "2026-01-09T18:00:00Z"
}
```

**Test Ride** (`rides/{rideId}`):
```json
{
  "id": "test-ride-1",
  "riderId": "test-rider-id",
  "ddId": null,
  "chapterId": "test-chapter",
  "eventId": "test-event-1",
  "pickupLocation": {
    "_latitude": 39.1836,
    "_longitude": -96.5717
  },
  "pickupAddress": "123 Test St, Manhattan, KS 66502",
  "dropoffAddress": "456 Destination Ave, Manhattan, KS 66502",
  "status": "queued",
  "priority": 42.5,
  "isEmergency": false,
  "requestedAt": "2026-01-09T20:00:00Z",
  "assignedAt": null,
  "enrouteAt": null,
  "completedAt": null,
  "cancelledAt": null,
  "cancellationReason": null,
  "notes": "Please hurry!"
}
```

## Test Scenarios

### 1. Initial Load

**Scenario**: DD opens dashboard for first time
**Steps**:
1. Launch app
2. Sign in as DD user
3. Navigate to DD Dashboard

**Expected Results**:
- [ ] Loading spinner appears
- [ ] DD assignment fetched from Firestore
- [ ] Active toggle shows OFF state
- [ ] Profile warning banner shows (no photo/car description)
- [ ] "Not Assigned" or "Toggle on" message displays
- [ ] Statistics show: Tonight: 0, Total: 5

**Edge Cases**:
- No active event → Shows "Not Assigned"
- No DD assignment → Shows "Not Assigned"
- Network error → Shows error message

---

### 2. Profile Upload - Photo

**Scenario**: DD uploads profile photo
**Steps**:
1. Tap profile warning banner
2. Sheet opens with DDPhotoUploadView
3. Tap "Add Photo" button
4. Select "Take Photo" or "Choose from Library"

**Expected Results - Camera**:
- [ ] Camera permission request appears
- [ ] If granted: Camera opens
- [ ] Take photo
- [ ] Crop interface appears (square crop)
- [ ] Cropped photo displays in circular frame
- [ ] "Add Photo" changes to "Change Photo"

**Expected Results - Library**:
- [ ] Photo Library permission request appears
- [ ] If granted: Photo picker opens
- [ ] Select photo
- [ ] Crop interface appears
- [ ] Selected photo displays

**Edge Cases**:
- Permission denied → Error alert with Settings link
- Photo > 1MB → Compression applied automatically
- Network error during upload → Error message, retry option
- Cancel crop → Returns to upload view, no photo selected

---

### 3. Profile Upload - Car Description

**Scenario**: DD enters car description
**Steps**:
1. In DDPhotoUploadView, scroll to car description
2. Tap text field
3. Enter description (e.g., "Red Honda Civic")
4. Verify character count updates

**Expected Results**:
- [ ] Keyboard appears
- [ ] Text entered shows in field
- [ ] Character count updates (X/50)
- [ ] Count turns red if > 50 characters
- [ ] Save button disabled until valid

**Edge Cases**:
- Empty description → Save disabled
- > 50 characters → Save disabled
- Only whitespace → Should be trimmed, treated as empty

---

### 4. Profile Save

**Scenario**: DD saves complete profile
**Steps**:
1. Upload photo
2. Enter car description
3. Tap "Save and Continue"

**Expected Results**:
- [ ] Button shows loading spinner
- [ ] Photo uploads to Firebase Storage
- [ ] DD assignment updated with photoURL
- [ ] Car description saved
- [ ] Sheet dismisses
- [ ] Profile warning banner disappears
- [ ] Active toggle enabled

**Edge Cases**:
- Network error → Error alert, stay on sheet
- Photo upload fails → Specific error message
- Firestore update fails → Error message

---

### 5. Toggle Active - Success

**Scenario**: DD toggles active status ON
**Steps**:
1. Complete profile
2. Tap active toggle

**Expected Results**:
- [ ] Toggle animates to ON
- [ ] Toggle background turns green
- [ ] Text changes to "Active"
- [ ] Status message: "You're ready to accept rides"
- [ ] Haptic feedback occurs
- [ ] DDAssignment updated in Firestore
- [ ] lastActiveTimestamp set to current time

**Firestore Verification**:
```javascript
ddAssignments/{userId}.isActive === true
ddAssignments/{userId}.lastActiveTimestamp !== null
```

---

### 6. Toggle Active - Failures

**Scenario 6a**: Toggle ON without complete profile
**Steps**:
1. Ensure profile incomplete (no photo or car description)
2. Tap active toggle

**Expected Results**:
- [ ] Error message appears
- [ ] Toggle stays OFF
- [ ] Message: "Please complete your profile..."

---

**Scenario 6b**: Toggle OFF with active ride
**Steps**:
1. Have active ride assigned (status: assigned or enroute)
2. Tap active toggle to OFF

**Expected Results**:
- [ ] Error message appears
- [ ] Toggle stays ON
- [ ] Message: "Cannot go inactive while you have an active ride"

---

**Scenario 6c**: Toggle OFF >5 times in 30 minutes
**Steps**:
1. Toggle OFF (count: 1)
2. Toggle ON
3. Repeat 5 more times rapidly

**Expected Results**:
- [ ] Toggle works for first 5 times
- [ ] After 6th toggle OFF, alert appears
- [ ] Alert message about excessive toggling
- [ ] Admin alert created in Firestore
- [ ] Alert type: `dd_inactive_toggle`

**Firestore Verification**:
```javascript
adminAlerts/{alertId}.type === "dd_inactive_toggle"
adminAlerts/{alertId}.ddId === userId
```

---

### 7. Receive Ride Assignment

**Scenario**: New ride assigned to DD
**Setup**:
1. DD is active
2. Admin/Cloud Function assigns ride to DD
3. Update ride document: `ddId = userId, status = "assigned"`

**Expected Results**:
- [ ] Current ride card appears within 2 seconds
- [ ] Rider name displays (fetched from users collection)
- [ ] Pickup address displays
- [ ] Dropoff address displays (if provided)
- [ ] Request time shows (e.g., "5 min ago")
- [ ] Notes display (if provided)
- [ ] Emergency badge shows (if emergency)
- [ ] "On My Way" button appears
- [ ] "Open in Maps" button appears

**Real-time Verification**:
- Listener fires on document change
- No page refresh needed
- Works even if app in background (when reopened)

---

### 8. Mark En Route

**Scenario**: DD taps "On My Way" button
**Steps**:
1. Have assigned ride
2. Tap "On My Way"

**Expected Results**:
- [ ] Location permission request (if first time)
- [ ] If granted: Button shows loading spinner
- [ ] Location captured (check console for coordinates)
- [ ] ETA calculated to rider location
- [ ] Button changes to "Complete Ride"
- [ ] ETA displays on card (e.g., "ETA: 8 min")
- [ ] Ride status updates to "enroute"
- [ ] enrouteAt timestamp set
- [ ] estimatedWaitTime updated
- [ ] Haptic feedback occurs
- [ ] (Cloud Function should send SMS to rider)

**Firestore Verification**:
```javascript
rides/{rideId}.status === "enroute"
rides/{rideId}.enrouteAt !== null
rides/{rideId}.estimatedWaitTime > 0
```

**Edge Cases**:
- Location permission denied → Error message with Settings link
- Location timeout (10 sec) → Error message
- ETA calculation fails → Falls back to 15 min default
- Network error → Error message, status stays "assigned"

---

### 9. Open in Maps

**Scenario**: DD taps "Open in Maps" for navigation
**Steps**:
1. Have assigned or enroute ride
2. Tap "Open in Maps" button

**Expected Results**:
- [ ] Apple Maps app opens
- [ ] Destination set to pickup address coordinates
- [ ] Navigation mode: Driving
- [ ] Route displayed
- [ ] Can start turn-by-turn navigation

**Edge Cases**:
- Maps not installed → Fallback to web maps (unlikely on iOS)
- Invalid coordinates → Error in Maps app

---

### 10. Complete Ride

**Scenario**: DD completes ride after dropping off rider
**Steps**:
1. Have enroute ride
2. Tap "Complete Ride" button

**Expected Results**:
- [ ] Button shows loading spinner
- [ ] Ride status updates to "completed"
- [ ] completedAt timestamp set
- [ ] DD assignment totalRidesCompleted increments
- [ ] Current ride card disappears
- [ ] Statistics update (Tonight +1, Total +1)
- [ ] Haptic feedback occurs
- [ ] If next ride exists, it becomes current
- [ ] If no rides, "All Caught Up" view shows

**Firestore Verification**:
```javascript
rides/{rideId}.status === "completed"
rides/{rideId}.completedAt !== null
ddAssignments/{userId}.totalRidesCompleted === previous + 1
```

---

### 11. Multiple Rides Queue

**Scenario**: DD has multiple rides assigned
**Setup**:
1. Assign 3 rides to DD
2. All status: "assigned"
3. Sorted by priority

**Expected Results**:
- [ ] Current ride shows highest priority ride
- [ ] Next ride preview shows second-highest priority
- [ ] Third ride not visible yet
- [ ] After completing current, second becomes current
- [ ] Third becomes next
- [ ] After completing second, third becomes current
- [ ] No next ride shown (queue empty)

**Priority Sorting**:
- Emergency (9999) always first
- Otherwise: (classYear × 10) + (waitTime × 0.5)

---

### 12. Emergency Ride

**Scenario**: Emergency ride assigned to DD
**Setup**:
1. Create ride with `isEmergency: true, priority: 9999`
2. Assign to DD

**Expected Results**:
- [ ] Ride appears as current immediately
- [ ] Red "EMERGENCY" badge shows on dashboard
- [ ] Red "EMERGENCY" badge shows in current ride card
- [ ] Emergency takes priority over all other rides
- [ ] (Risk Manager should be notified via admin alert)

---

### 13. Statistics Display

**Scenario**: Verify stats accuracy
**Setup**:
1. DD has `totalRidesCompleted: 5` in assignment
2. Complete 3 more rides during event

**Expected Results**:
- [ ] Initially: Tonight: 0, Total: 5
- [ ] After 1st ride: Tonight: 1, Total: 6
- [ ] After 2nd ride: Tonight: 2, Total: 7
- [ ] After 3rd ride: Tonight: 3, Total: 8
- [ ] Stats persist after app restart (Total only)
- [ ] Tonight resets for new events

---

### 14. No Active Rides

**Scenario**: DD active but no rides in queue
**Steps**:
1. Toggle active ON
2. Complete all rides (or no rides assigned)

**Expected Results**:
- [ ] "All Caught Up!" view appears
- [ ] Checkmark icon displays
- [ ] Message: "No rides in queue..."
- [ ] Statistics still show
- [ ] Toggle still enabled

---

### 15. Ride Cancellation

**Scenario**: Rider cancels while DD en route
**Setup**:
1. DD has enroute ride
2. Rider/Admin cancels ride
3. Ride status changed to "cancelled"

**Expected Results**:
- [ ] Current ride card disappears
- [ ] Next ride (if any) becomes current
- [ ] Or "All Caught Up" shows
- [ ] No stats increment
- [ ] DD receives notification (optional feature)

---

### 16. Network Interruption

**Scenario**: Network drops during operations
**Steps**:
1. Enable Airplane Mode
2. Try various actions:
   - Toggle active
   - Mark en route
   - Complete ride
   - Upload photo

**Expected Results**:
- [ ] Each action shows loading state
- [ ] After timeout, error message appears
- [ ] Error message user-friendly (not technical)
- [ ] Can retry after network restored
- [ ] No data corruption
- [ ] Firestore offline persistence works

---

### 17. Background/Foreground

**Scenario**: App backgrounded during active session
**Steps**:
1. DD active with current ride
2. Home button (background app)
3. Wait 5 minutes
4. Reopen app

**Expected Results**:
- [ ] Ride still shows (Firestore listener reconnects)
- [ ] Data is current (no stale info)
- [ ] Can still perform actions
- [ ] Location permission still valid (if "When In Use")

---

### 18. Pull to Refresh

**Scenario**: DD manually refreshes dashboard
**Steps**:
1. Pull down on dashboard ScrollView
2. Release

**Expected Results**:
- [ ] Refresh indicator appears
- [ ] DD assignment reloaded
- [ ] Stats refreshed
- [ ] Rides reloaded
- [ ] Refresh indicator disappears
- [ ] Data is up-to-date

---

### 19. Accessibility Testing

**VoiceOver**:
- [ ] Turn on VoiceOver
- [ ] Navigate through dashboard
- [ ] All elements have labels
- [ ] Hints provided for actions
- [ ] Toggle announces state change
- [ ] Cards read in logical order

**Dynamic Type**:
- [ ] Settings > Accessibility > Display & Text Size > Larger Text
- [ ] Set to maximum
- [ ] Reopen app
- [ ] All text scales appropriately
- [ ] No text truncated
- [ ] Layouts remain functional

**Color Contrast**:
- [ ] Light mode: sufficient contrast
- [ ] Dark mode: sufficient contrast
- [ ] High Contrast mode: still readable

---

### 20. Error Recovery

**Scenario**: App crashes during ride
**Steps**:
1. DD has enroute ride
2. Force quit app (swipe up in app switcher)
3. Reopen app

**Expected Results**:
- [ ] Dashboard loads
- [ ] Current ride still shows
- [ ] Can continue from where left off
- [ ] Status preserved (enroute)
- [ ] Can complete ride normally

---

## Performance Testing

### Load Time
- [ ] Dashboard loads in < 2 seconds
- [ ] Photo upload completes in < 5 seconds
- [ ] Location capture completes in < 5 seconds
- [ ] ETA calculation completes in < 3 seconds

### Battery Usage
- [ ] Location only captured once per ride
- [ ] No continuous GPS tracking
- [ ] Firestore listeners efficient
- [ ] Photo compression reduces upload time

### Memory
- [ ] No memory leaks (Instruments)
- [ ] Images released after upload
- [ ] Listeners cleaned up properly

---

## Security Testing

### Authentication
- [ ] Unauthenticated users cannot access dashboard
- [ ] DD can only see their own assignments
- [ ] DD cannot modify other DD's data

### Authorization
- [ ] DD can only update their own rides
- [ ] DD cannot create/delete rides
- [ ] DD cannot modify admin alerts
- [ ] Storage rules enforce userId match for photos

### Data Validation
- [ ] Car description limited to 50 chars (client-side)
- [ ] Photo size limited to 1MB (client-side)
- [ ] Invalid coordinates rejected
- [ ] Firestore rules validate server-side

---

## Automated Testing

### Unit Tests
```swift
// DDViewModelTests.swift
- testToggleActive_Success()
- testToggleActive_WithoutProfile_Fails()
- testToggleActive_WithActiveRide_Fails()
- testMarkEnRoute_UpdatesStatus()
- testCompleteRide_IncrementsStats()
- testUploadPhoto_Compression()
```

### Integration Tests
```swift
// DDDashboardIntegrationTests.swift
- testRideAssignment_UpdatesDashboard()
- testMultipleRides_ShowsCorrectOrder()
- testEmergencyRide_TakesPriority()
```

### UI Tests
```swift
// DDDashboardUITests.swift
- testToggleFlow()
- testPhotoUploadFlow()
- testRideCompletionFlow()
```

---

## Test Report Template

```
Test Date: ____________________
Tester: ____________________
Build: ____________________
Device: ____________________
iOS Version: ____________________

Test Results:
- Total Scenarios: ___
- Passed: ___
- Failed: ___
- Blocked: ___

Critical Issues:
1.
2.

Minor Issues:
1.
2.

Notes:


Tester Signature: ____________________
```

---

## Troubleshooting Common Issues

**Issue**: Location permission not requested
**Fix**: Check Info.plist has NSLocationWhenInUseUsageDescription

**Issue**: Photo picker doesn't open
**Fix**: Check camera/photo library permissions in Info.plist

**Issue**: Rides not appearing
**Fix**: Verify DD assignment exists and isActive = true

**Issue**: ETA always 15 minutes
**Fix**: Check MapKit API, may be falling back due to calculation error

**Issue**: Firebase Storage upload fails
**Fix**: Verify Storage rules allow write for authenticated user

**Issue**: Stats not updating
**Fix**: Check Firestore DDAssignment document updates correctly

**Issue**: Listener not firing
**Fix**: Verify network connection, check Firestore indexes

---

## Sign-off Checklist

Before releasing DD feature:
- [ ] All critical scenarios pass
- [ ] No P1/P2 bugs open
- [ ] Performance benchmarks met
- [ ] Accessibility verified
- [ ] Security audit completed
- [ ] Documentation complete
- [ ] Cloud Functions deployed
- [ ] Firebase rules deployed
- [ ] SMS integration tested
- [ ] TestFlight beta completed

---

## Contact

For testing issues or questions:
- Review README.md in DD folder
- Check CLAUDE.md for architecture
- Test with Firebase emulators first
- Verify Firestore rules and indexes

# DD (Designated Driver) Interface

Complete implementation of the Designated Driver dashboard for the DDRide app.

## Files Created

### Core Files
1. **DDViewModel.swift** - Main view model managing DD operations
2. **DDDashboardView.swift** - Main dashboard view with active toggle and ride management
3. **CurrentRideCard.swift** - Component displaying current assigned ride with actions
4. **NextRideCard.swift** - Component showing next ride in queue
5. **DDStatsCard.swift** - Statistics card component (Tonight/Total rides)
6. **DDPhotoUploadView.swift** - Photo and car description upload interface

### Documentation
7. **INFO_PLIST_REQUIREMENTS.md** - Required Info.plist entries for permissions
8. **README.md** - This file

## Features Implemented

### 1. Active/Inactive Toggle
- Large, prominent toggle switch
- Green when active, gray when inactive
- Haptic feedback on toggle
- Prevents going inactive with active ride
- Requires complete profile before activating
- Monitors excessive toggling (>5 times in 30 min)

### 2. Profile Requirements
- DD must upload photo and car description before going active
- Warning banner shown if profile incomplete
- Tapping banner opens photo upload sheet
- Photo upload supports camera and photo library
- Image cropping to square
- Compression to max 1MB
- Car description with 50 character limit

### 3. Current Ride Management
- Real-time listener for assigned rides
- Displays rider name, pickup/dropoff addresses
- Shows request time (relative format)
- Emergency badge for emergency rides
- Notes display if provided
- **Two action buttons:**
  - **"On My Way"** (when assigned):
    - Captures DD location once
    - Calculates ETA to rider
    - Updates ride status to "en route"
    - Sends SMS to rider (via Cloud Function)
  - **"Complete Ride"** (when en route):
    - Marks ride as completed
    - Increments DD stats
    - Updates dashboard
- **"Open in Maps"** button:
  - Opens Apple Maps with driving directions
  - Sets destination to pickup address

### 4. Next Ride Preview
- Shows second ride in DD's queue
- Smaller card with key info
- Helps DD prepare for next pickup

### 5. Statistics
- **Tonight**: Rides completed during current event
- **Total**: All-time rides completed
- Displayed in attractive stat cards
- Updated in real-time

### 6. Empty States
- "All Caught Up" when active but no rides
- "Not Assigned" when not assigned to active event
- Loading states with progress indicators

### 7. Error Handling
- Location permission errors with helpful messages
- Photo upload errors with retry options
- Network errors with graceful fallbacks
- User-friendly error messages throughout

## Business Rules Enforced

### DD Assignment
- DD must be assigned to active event
- Assignment fetched by user ID
- Verified against current event

### Active Status
- Cannot go inactive with active ride (assigned or en route)
- Cannot go active without complete profile (photo + car description)
- Inactive toggle monitoring creates admin alerts

### Location Capture
- **One-time only** when marking "en route"
- Uses "When In Use" permission (not "Always")
- 10-second timeout to prevent battery drain
- Falls back to default 15-min ETA if calculation fails

### Ride Lifecycle
1. **Assigned**: DD receives ride, sees "On My Way" button
2. **En Route**: DD location captured, ETA calculated, "Complete Ride" button shown
3. **Completed**: Stats incremented, next ride becomes current

### Priority Handling
- Rides sorted by priority (emergency = 9999)
- Current ride is highest priority assigned/en route
- Next ride is second in queue

## Integration Points

### Services Used
- **AuthService**: Current user authentication
- **FirestoreService**: CRUD operations for rides, assignments, users
- **DDAssignmentService**: Toggle status, monitoring, stats
- **LocationService**: One-time location capture
- **ETAService**: Calculate driving ETA to pickup
- **Firebase Storage**: Photo upload to cloud storage

### Firestore Collections
- `users` - Rider information
- `rides` - Ride documents
- `ddAssignments` - DD assignment documents
- `events` - Event documents

### Real-time Listeners
- Rides assigned to DD (status: assigned or enroute)
- Filtered by DD ID and event ID
- Sorted by priority descending

## User Flow

### Initial Setup
1. Admin assigns user as DD for event
2. DD opens app, navigates to DD Dashboard
3. DD sees profile requirements warning
4. DD taps warning, uploads photo and enters car description
5. DD toggles "I'm Active" to ON

### Accepting Rides
1. Ride assigned to DD (via Cloud Function)
2. Dashboard shows current ride card
3. DD reviews pickup address and rider info
4. DD taps "On My Way"
5. Location captured, ETA calculated
6. SMS sent to rider with DD info and ETA
7. DD can tap "Open in Maps" for navigation

### Completing Rides
1. DD picks up rider
2. DD navigates to destination
3. DD drops off rider
4. DD taps "Complete Ride"
5. Stats increment
6. Next ride becomes current (if available)

### Going Offline
1. DD finishes shift or needs break
2. DD ensures no active rides
3. DD toggles "I'm Active" to OFF
4. DD stops receiving new assignments

## Testing Checklist

### Profile Upload
- [ ] Take photo with camera (permission request)
- [ ] Select photo from library (permission request)
- [ ] Crop photo to square
- [ ] Upload photo (check Firebase Storage)
- [ ] Enter car description
- [ ] Save and verify profile complete

### Active Toggle
- [ ] Toggle ON (should work if profile complete)
- [ ] Toggle ON without profile (should show error)
- [ ] Toggle OFF with active ride (should show error)
- [ ] Toggle OFF without ride (should work)
- [ ] Toggle >5 times (should show admin alert)

### Ride Management
- [ ] Receive ride assignment (listener updates)
- [ ] View current ride details
- [ ] Tap "On My Way" (location permission request)
- [ ] Verify ETA calculated
- [ ] Verify ride status changed to "en route"
- [ ] Tap "Open in Maps" (opens with directions)
- [ ] Tap "Complete Ride"
- [ ] Verify stats increment
- [ ] Verify next ride becomes current

### Edge Cases
- [ ] No active event (shows "Not Assigned")
- [ ] Active but no rides (shows "All Caught Up")
- [ ] Location permission denied (shows error)
- [ ] Photo upload fails (shows error)
- [ ] Network error (graceful fallback)
- [ ] Rider cancels ride mid-journey
- [ ] Multiple DDs assigned (verify ride routing)

### Accessibility
- [ ] VoiceOver reads all elements correctly
- [ ] All buttons have accessibility labels
- [ ] Dynamic Type scaling works
- [ ] Color contrast sufficient
- [ ] Touch targets at least 44x44 points

## SwiftUI Best Practices

### Architecture
- MVVM pattern with `DDViewModel`
- Separated view components for reusability
- Proper state management with `@Published`
- Combine for reactive data flow

### Performance
- Lazy loading of rider information
- Efficient Firestore listeners
- One-time location capture (battery efficient)
- Image compression before upload

### UI/UX
- Card-based design with shadows
- Consistent spacing and padding
- Loading states for all async operations
- Error states with retry options
- Empty states with helpful messages
- Haptic feedback on important actions

### Accessibility
- Semantic labels for all elements
- VoiceOver hints for actions
- Dynamic Type support
- High contrast mode compatible

## Firebase Integration

### Storage Rules (Required)
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /dd_photos/{userId}.jpg {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
  }
}
```

### Firestore Security Rules
See main Firestore rules - DD operations require:
- Authenticated user
- User matches DD assignment userId
- DD assignment exists for active event

## Cloud Functions Integration

### SMS Notifications
When DD marks "en route", Cloud Function should:
1. Detect ride status change to `enroute`
2. Fetch DD and rider info
3. Send SMS to rider with:
   - DD name
   - DD car description
   - ETA in minutes
   - DD contact (optional)

Example message:
```
Your DD [Name] is on the way! [Car Description]. ETA: 8 minutes.
```

## Future Enhancements

### Potential Features
1. **Chat System**: In-app messaging between DD and rider
2. **Live Location Sharing**: Real-time DD location on rider's map
3. **Route History**: Track all routes driven during event
4. **Rating System**: Riders rate DD performance
5. **Multi-Stop Routes**: Support multiple pickups in one trip
6. **Voice Navigation**: Integrated turn-by-turn guidance
7. **Ride Notes**: DD can add notes to completed rides
8. **Shift Scheduling**: Pre-schedule DD availability

### Performance Optimizations
1. **Pagination**: Limit listener results if many rides
2. **Caching**: Cache rider info to reduce Firestore reads
3. **Prefetching**: Preload next ride details
4. **Background Updates**: Update location periodically while active

## Known Limitations

1. **Single Event Support**: DD can only be active for one event at a time
2. **No Offline Mode**: Requires network connection for all operations
3. **iOS Only**: No Android support (SwiftUI)
4. **No Route Recording**: Doesn't track actual path driven
5. **Manual Completion**: DD must manually mark ride complete

## Dependencies

- iOS 17.0+
- Swift 5.9+
- Firebase iOS SDK 10.0+
  - FirebaseFirestore
  - FirebaseStorage
  - FirebaseAuth
- Core Location
- MapKit
- Combine

## Support

For questions or issues:
1. Check CLAUDE.md in project root for architecture details
2. Review Firebase rules and Cloud Functions
3. Test with Firebase emulators before production
4. Verify all Info.plist entries added correctly

## License

Part of DDRide app for K-State fraternity and sorority DD management.

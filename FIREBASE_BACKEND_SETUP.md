# Firebase Backend Setup - DD Ride App

This document provides a complete overview of the Firebase backend configuration for the DD Ride App.

## Data Model Summary

### Collections

#### 1. `users/{userId}`
Stores user profiles for all chapter members.

```typescript
interface User {
  id: string;                    // Firebase Auth UID
  name: string;
  email: string;                 // Must be @ksu.edu
  phoneNumber: string;           // E.164 format: +15551234567
  chapterId: string;
  role: 'admin' | 'member';
  classYear: number;             // 4=senior, 3=junior, 2=soph, 1=fresh
  isEmailVerified: boolean;
  fcmToken?: string;             // For push notifications
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### 2. `chapters/{chapterId}`
Stores chapter (fraternity/sorority) information.

```typescript
interface Chapter {
  id: string;
  name: string;
  universityId: string;          // e.g., "ksu"
  inviteCode: string;
  yearTransitionDate: string;    // "MM-DD" format, e.g., "08-01"
  greekLetters?: string;
  organization: 'fraternity' | 'sorority';
  phoneNumber?: string;
  address?: string;
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### 3. `events/{eventId}`
Stores DD events (shifts).

```typescript
interface Event {
  id: string;
  name: string;
  chapterId: string;
  date: Timestamp;
  allowedChapterIds: string[];   // ["ALL"] or specific chapter IDs
  status: 'active' | 'completed';
  location?: string;
  description?: string;
  createdAt: Timestamp;
  createdBy: string;             // User ID
}
```

#### 4. `events/{eventId}/ddAssignments/{userId}`
Subcollection storing DD assignments for each event.

```typescript
interface DDAssignment {
  id: string;                    // Same as userId
  userId: string;
  eventId: string;
  photoURL?: string;
  carDescription?: string;
  isActive: boolean;
  inactiveToggles: number;
  lastActiveTimestamp?: Timestamp;
  lastInactiveTimestamp?: Timestamp;
  totalRidesCompleted: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### 5. `rides/{rideId}`
Stores ride requests.

```typescript
interface Ride {
  id: string;
  eventId: string;
  riderId: string;
  riderName: string;
  riderPhoneNumber: string;
  ddId?: string;
  ddName?: string;
  ddPhoneNumber?: string;
  ddCarDescription?: string;
  pickupAddress: string;
  pickupLocation: GeoPoint;
  status: 'queued' | 'assigned' | 'enroute' | 'completed' | 'cancelled';
  priority: number;              // (classYear × 10) + (waitTime × 0.5), emergency = 9999
  estimatedETA?: number;         // Minutes
  requestTime: Timestamp;
  assignedTime?: Timestamp;
  enrouteTime?: Timestamp;
  completionTime?: Timestamp;
  isEmergency: boolean;
  emergencyReason?: string;
}
```

#### 6. `adminAlerts/{alertId}`
Stores alerts for admins.

```typescript
interface AdminAlert {
  id: string;
  chapterId: string;
  type: 'dd_inactive' | 'emergency_request' | 'year_transition';
  message: string;
  ddId?: string;
  rideId?: string;
  isRead: boolean;
  createdAt: Timestamp;
}
```

#### 7. `yearTransitionLogs/{logId}`
Audit log for year transitions (August 1st).

```typescript
interface YearTransitionLog {
  id: string;
  executionDate: Timestamp;
  seniorsRemoved: number;
  usersAdvanced: number;
  status: 'success' | 'failed';
  errorMessage?: string;
}
```

## Security Rules Summary

The security rules enforce the following:

### Access Requirements
- Must be signed in with Firebase Auth
- Must use @ksu.edu email address
- Email must be verified

### Users Collection
- **Read**: Any verified user
- **Create**: User can create their own account during signup
- **Update**: User can update their own profile OR admin can update anyone
- **Delete**: Admin only

### Chapters Collection
- **Read**: Any verified user
- **Write**: Admin only

### Events Collection
- **Read**: Any verified user
- **Write**: Admin only
- **DD Assignments Subcollection**:
  - Read: Any verified user
  - Create/Delete: Admin only
  - Update: Admin OR the DD themselves

### Rides Collection
- **Read**: Any verified user
- **Create**: User can create ride for themselves
- **Update**: Rider, assigned DD, or admin
- **Delete**: Admin only

### Admin Alerts Collection
- **Read/Write**: Admin only, restricted to their chapter

### Year Transition Logs Collection
- **Read**: Admin only
- **Write**: Cloud Functions only (no client-side writes)

## Composite Indexes

The following composite indexes are configured in `firestore.indexes.json`:

1. **rides**: `eventId` (ASC) + `status` (ASC) + `priority` (DESC)
   - Used for fetching active rides sorted by priority

2. **rides**: `eventId` (ASC) + `ddId` (ASC) + `status` (ASC)
   - Used for fetching rides assigned to a specific DD

3. **rides**: `riderId` (ASC) + `requestTime` (DESC)
   - Used for fetching ride history for a rider

4. **ddAssignments**: `eventId` (ASC) + `isActive` (ASC) + `totalRidesCompleted` (ASC)
   - Used for finding available DDs with fewest completed rides

5. **events**: `chapterId` (ASC) + `status` (ASC) + `date` (DESC)
   - Used for fetching active events for a chapter

6. **users**: `chapterId` (ASC) + `role` (ASC)
   - Used for fetching admins for a chapter

7. **users**: `chapterId` (ASC) + `classYear` (DESC)
   - Used for fetching chapter members sorted by class year

8. **adminAlerts**: `chapterId` (ASC) + `isRead` (ASC) + `createdAt` (DESC)
   - Used for fetching unread alerts for admins

## iOS Firebase Integration

The iOS app uses `FirebaseService.swift` as a singleton service that:

1. Configures Firebase on initialization
2. Automatically connects to Firebase emulators in DEBUG builds
3. Provides typed collection references
4. Provides CRUD operations for all collections
5. Provides real-time listeners for active rides, user data, and alerts

### Emulator Configuration

In DEBUG builds, the app automatically connects to:
- Firestore Emulator: `localhost:8080`
- Auth Emulator: `localhost:9099`

### Key Methods

```swift
// Users
FirebaseService.shared.createUser(_ user: User)
FirebaseService.shared.fetchUser(id: String) -> User
FirebaseService.shared.updateUser(_ user: User)
FirebaseService.shared.fetchChapterMembers(chapterId: String) -> [User]

// Events
FirebaseService.shared.createEvent(_ event: Event)
FirebaseService.shared.fetchActiveEvents(chapterId: String) -> [Event]
FirebaseService.shared.updateEvent(_ event: Event)

// DD Assignments
FirebaseService.shared.createDDAssignment(_ assignment: DDAssignment, eventId: String)
FirebaseService.shared.fetchActiveDDAssignments(eventId: String) -> [DDAssignment]
FirebaseService.shared.updateDDAssignment(_ assignment: DDAssignment, eventId: String)

// Rides
FirebaseService.shared.createRide(_ ride: Ride)
FirebaseService.shared.fetchActiveRides(eventId: String) -> [Ride]
FirebaseService.shared.fetchDDRides(ddId: String, eventId: String) -> [Ride]
FirebaseService.shared.updateRide(_ ride: Ride)

// Real-time Listeners
FirebaseService.shared.listenToActiveRides(eventId: String, completion: ([Ride]) -> Void)
FirebaseService.shared.listenToUser(userId: String, completion: (User?) -> Void)
FirebaseService.shared.listenToUnreadAlerts(chapterId: String, completion: ([AdminAlert]) -> Void)
```

## Business Logic

### Queue Priority Algorithm
```
priority = (classYear × 10) + (waitTime × 0.5)
emergency priority = 9999

Examples:
- Senior (4) waiting 5 min: (4×10) + (5×0.5) = 42.5
- Freshman (1) waiting 15 min: (1×10) + (15×0.5) = 17.5
- Emergency: 9999 (always first)
```

### DD Assignment Algorithm
Assign to DD with shortest wait time:
1. If DD has no active rides → 0 minutes wait
2. If DD has rides → sum estimated time for all queued/active rides
3. Assign to DD with minimum wait time

### Location Capture
- **One-time only** when rider requests ride
- **One-time only** when DD marks "en route"
- **No background tracking**

## Deployment

### 1. Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

### 2. Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

### 3. Test with Emulators
```bash
firebase emulators:start --only firestore,auth
```

## Next Steps

### Required Cloud Functions (To Be Implemented)

1. **yearTransition** - Scheduled function (August 1st)
   - Remove seniors (classYear === 4)
   - Increment classYear for all other users
   - Log results to yearTransitionLogs

2. **assignRideToDD** - Triggered on ride creation
   - Find available DD with shortest wait time
   - Assign ride to DD
   - Update ride status to 'assigned'

3. **notifyDDNewRide** - Triggered on ride assignment
   - Send SMS to DD with pickup details

4. **notifyRiderEnRoute** - Triggered on DD marks en route
   - Send SMS to rider with DD info and ETA

5. **monitorDDActivity** - Triggered on DD assignment update
   - Track inactive toggles
   - Alert admin if >5 toggles in 30 minutes
   - Notify DD if inactive >15 minutes

6. **handleEmergencyRequest** - Triggered on emergency ride creation
   - Create admin alert
   - Send push notification to admin

## Cost Optimization

1. Use client-side caching via Firestore persistence
2. Use batch writes when updating multiple documents
3. Limit queries with `.limit()` where appropriate
4. Use real-time listeners only where necessary
5. Minimize SMS sends (only on critical state changes)

## Testing Checklist

- [ ] Deploy security rules to test environment
- [ ] Deploy indexes to test environment
- [ ] Test user signup with @ksu.edu email
- [ ] Test user signup with non-KSU email (should fail)
- [ ] Test admin can create events
- [ ] Test member cannot create events
- [ ] Test member can request ride for themselves
- [ ] Test member cannot request ride for others
- [ ] Test DD can update their assignment
- [ ] Test DD cannot update other DD's assignment
- [ ] Test admin can read alerts for their chapter
- [ ] Test admin cannot read alerts for other chapters
- [ ] Test year transition logs are read-only from client

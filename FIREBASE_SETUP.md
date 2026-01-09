# Firebase Backend Setup Guide

This guide covers the complete Firebase backend setup for the DD Ride app.

## Prerequisites

1. **Firebase CLI** installed globally:
   ```bash
   npm install -g firebase-tools
   ```

2. **Node.js** (v18 or later) for Cloud Functions

3. **Firebase Project** created at https://console.firebase.google.com

## Initial Setup

### 1. Login to Firebase

```bash
firebase login
```

### 2. Select Your Firebase Project

```bash
firebase use --add
# Select your project and give it an alias (e.g., "production")
```

### 3. Initialize Firebase Services

If not already initialized, run:

```bash
firebase init
```

Select:
- ✅ Firestore
- ✅ Functions
- ✅ Emulators (for local development)

## Firestore Configuration

### Data Model Overview

```
firestore/
├── users/{userId}
│   ├── id, name, email (@ksu.edu)
│   ├── phoneNumber, chapterId, role
│   ├── classYear (1-4), isEmailVerified
│   └── fcmToken, createdAt, updatedAt
│
├── chapters/{chapterId}
│   ├── id, name, universityId
│   ├── inviteCode, yearTransitionDate
│   └── organization, isActive, timestamps
│
├── events/{eventId}
│   ├── id, name, chapterId, date
│   ├── allowedChapterIds, status
│   └── createdBy, createdAt
│   │
│   └── ddAssignments/{userId} (subcollection)
│       ├── userId, eventId, photoURL
│       ├── carDescription, isActive
│       ├── inactiveToggles, timestamps
│       └── totalRidesCompleted
│
├── rides/{rideId}
│   ├── id, eventId, riderId, riderName
│   ├── ddId, ddName, ddPhoneNumber
│   ├── pickupAddress, pickupLocation (GeoPoint)
│   ├── status, priority, estimatedETA
│   ├── isEmergency, emergencyReason
│   └── requestTime, assignedTime, enrouteTime, completionTime
│
├── adminAlerts/{alertId}
│   ├── id, chapterId, type, message
│   ├── ddId, rideId, isRead
│   └── createdAt
│
└── yearTransitionLogs/{logId}
    ├── id, executionDate
    ├── seniorsRemoved, usersAdvanced
    └── status, errorMessage
```

### Priority Queue Algorithm

Rides are sorted by priority:

```typescript
// Normal rides
priority = (classYear × 10) + (waitTime × 0.5)

// Examples:
// Senior (4) waiting 5 min: (4×10) + (5×0.5) = 42.5
// Freshman (1) waiting 15 min: (1×10) + (15×0.5) = 17.5

// Emergency rides
priority = 9999
```

### DD Assignment Algorithm

```typescript
// Assign to DD with shortest wait time
1. If DD has no active rides → 0 minutes wait
2. If DD has rides → sum estimated time for all rides
3. Assign to DD with minimum wait time
```

## Security Rules

The security rules enforce:

1. **Email Verification**: All users must have verified @ksu.edu email
2. **Role-Based Access**: Admins have elevated permissions
3. **Chapter Isolation**: Users can only access their chapter's data
4. **Owner Protection**: Users can update their own data

### Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

### Test Security Rules Locally

```bash
# Start emulators
firebase emulators:start --only firestore

# In another terminal, run rules tests
cd functions
npm test
```

## Composite Indexes

The app requires these composite indexes for efficient queries:

1. **Rides Queue** (eventId + status + priority)
2. **DD's Rides** (eventId + ddId + status)
3. **Rider History** (riderId + requestTime)
4. **Active DDs** (eventId + isActive + totalRidesCompleted)
5. **Events List** (chapterId + status + date)
6. **Chapter Members** (chapterId + role/classYear)
7. **Admin Alerts** (chapterId + isRead + createdAt)

### Deploy Indexes

```bash
firebase deploy --only firestore:indexes
```

Note: Index creation can take several minutes. Check status at:
https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes

## Cloud Functions

### Install Dependencies

```bash
cd functions
npm install
```

### Available Functions

1. **yearTransition** - Scheduled function (Aug 1 midnight)
   - Removes all seniors (classYear === 4)
   - Advances everyone else by 1 year
   - Logs transition results

2. **assignRideToDD** - Triggered on ride creation
   - Finds active DD with fewest rides
   - Assigns ride to DD
   - Updates ride status

3. **notifyDDNewRide** - Triggered on ride assignment
   - Sends SMS to DD with pickup address
   - Uses Twilio API

4. **notifyRiderEnRoute** - Triggered when DD starts trip
   - Sends SMS to rider with DD info and ETA
   - Uses Twilio API

5. **monitorDDActivity** - Triggered on DD assignment update
   - Tracks inactive toggles
   - Alerts admin if DD toggles >5 times
   - Reminds DD if inactive >15 minutes

6. **handleEmergencyRequest** - Triggered on emergency ride
   - Creates admin alert
   - Sends push notification to admin

### Configure Twilio Credentials

```bash
firebase functions:config:set \
  twilio.sid="YOUR_TWILIO_ACCOUNT_SID" \
  twilio.token="YOUR_TWILIO_AUTH_TOKEN" \
  twilio.number="+15551234567"
```

To view current config:
```bash
firebase functions:config:get
```

### Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:assignRideToDD
```

### View Function Logs

```bash
firebase functions:log

# Follow logs in real-time
firebase functions:log --only assignRideToDD
```

## Local Development with Emulators

### Start Emulators

```bash
firebase emulators:start
```

This starts:
- **Firestore**: http://localhost:8080
- **Auth**: http://localhost:9099
- **Functions**: http://localhost:5001
- **Emulator UI**: http://localhost:4000

### iOS App Emulator Configuration

The iOS app automatically connects to emulators in DEBUG builds:

```swift
#if DEBUG
// Firestore
settings.host = "localhost:8080"
settings.isSSLEnabled = false

// Auth
Auth.auth().useEmulator(withHost: "localhost", port: 9099)
#endif
```

### Export/Import Emulator Data

```bash
# Export data
firebase emulators:export ./firestore-data

# Import data on startup
firebase emulators:start --import=./firestore-data
```

## Authentication Setup

### Enable Email/Password Authentication

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Email/Password" provider
3. **Important**: Enable "Email link (passwordless sign-in)" for better UX

### Configure Authorized Domains

Add these domains:
- `localhost` (for local development)
- Your production domain (for web version)

### Email Verification

The app enforces:
1. Email must end with `@ksu.edu`
2. Email must be verified before access
3. Security rules block unverified users

## Cloud Scheduler Setup

### Enable Required APIs

```bash
# Enable Cloud Scheduler API
gcloud services enable cloudscheduler.googleapis.com

# Enable Cloud Functions API
gcloud services enable cloudfunctions.googleapis.com
```

### Year Transition Schedule

The `yearTransition` function is scheduled to run:
- **Date**: August 1st
- **Time**: 12:00 AM (midnight)
- **Timezone**: America/Chicago (K-State)
- **Frequency**: Yearly

Check schedule in Firebase Console → Functions → Cloud Scheduler

## Cost Optimization

### Firestore

- **Free Tier**: 50,000 reads, 20,000 writes, 20,000 deletes per day
- **Best Practices**:
  - Use offline persistence (enabled by default)
  - Limit query results with `.limit()`
  - Use snapshot listeners for real-time updates (more efficient than polling)

### Cloud Functions

- **Free Tier**: 2 million invocations per month
- **Best Practices**:
  - Set appropriate memory limits (128MB-256MB for most functions)
  - Set timeouts (default 60s, reduce if possible)
  - Use Cloud Scheduler sparingly

### Twilio SMS

- **Cost**: ~$0.0079 per message
- **Optimization**:
  - Only send on ride assignment and en route
  - No confirmation messages
  - Use push notifications where possible

## Monitoring and Alerts

### Firebase Console

Monitor usage at:
- **Firestore**: https://console.firebase.google.com/project/YOUR_PROJECT/firestore
- **Functions**: https://console.firebase.google.com/project/YOUR_PROJECT/functions
- **Auth**: https://console.firebase.google.com/project/YOUR_PROJECT/authentication

### Set Up Budget Alerts

1. Go to Google Cloud Console
2. Billing → Budgets & alerts
3. Create budget (e.g., $50/month)
4. Set alert threshold (e.g., 80%)

## Deployment Checklist

Before deploying to production:

- [ ] Update security rules
- [ ] Deploy composite indexes
- [ ] Configure Twilio credentials
- [ ] Enable email verification
- [ ] Set up Cloud Scheduler
- [ ] Configure budget alerts
- [ ] Test with emulators
- [ ] Review function logs
- [ ] Verify year transition date in chapter settings

## Useful Commands

```bash
# Check Firebase project info
firebase projects:list

# Check current project
firebase use

# View Firestore data
firebase firestore:indexes

# Delete all Firestore data (DANGER!)
firebase firestore:delete --all-collections

# View function logs
firebase functions:log --limit 100

# Deploy everything
firebase deploy

# Deploy only specific targets
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## Troubleshooting

### "Permission Denied" Errors

1. Check security rules in Firebase Console
2. Verify user email is verified (@ksu.edu)
3. Check user role and chapterId

### Composite Index Errors

1. Check error message for index URL
2. Click URL to create index automatically
3. Wait for index to build (can take minutes)

### Emulator Connection Issues

1. Ensure emulators are running: `firebase emulators:start`
2. Check iOS app is in DEBUG mode
3. Verify localhost ports are not blocked
4. Try clearing Firestore cache

### Cloud Function Timeout

1. Check function logs: `firebase functions:log`
2. Increase timeout in functions/src/index.ts
3. Optimize function code (reduce database reads)

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Data Modeling](https://firebase.google.com/docs/firestore/manage-data/structure-data)
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Cloud Functions Guide](https://firebase.google.com/docs/functions)
- [Twilio SMS Documentation](https://www.twilio.com/docs/sms)

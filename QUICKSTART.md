# DD Ride App - Quick Start Guide

Fast-track guide to get the DD Ride App running locally.

## Prerequisites

- Xcode 15+ installed
- Firebase CLI installed: `npm install -g firebase-tools`
- Node.js 18+ installed

## 5-Minute Setup

### 1. Start Firebase Emulators (Terminal 1)
```bash
cd /Users/didowu/DDRideApp
firebase emulators:start --only firestore,auth
```

Wait for:
```
✔  All emulators ready! It is now safe to connect your app.
┌─────────────────────────────────────────────────────────┐
│ ✔  All emulators ready! View Emulator UI at            │
│ http://127.0.0.1:4000                                   │
└─────────────────────────────────────────────────────────┘
```

### 2. Open iOS App (Terminal 2)
```bash
cd /Users/didowu/DDRideApp/ios
open DDRide.xcworkspace
```

### 3. Run in Simulator
In Xcode:
1. Select iPhone 15 simulator (or any iOS 17+ device)
2. Click Run (⌘R)
3. App will automatically connect to local emulators

### 4. Test Authentication
1. Try signing up with non-KSU email → Should fail
2. Sign up with test@ksu.edu → Should work
3. Check email verification requirement

## Emulator UI

Open http://localhost:4000 to:
- View Firestore data
- Manage test users
- See authentication logs
- Inspect security rule evaluations

## Verify Backend Setup

Run the verification script:
```bash
./verify-firebase-backend.sh
```

Should show all green checkmarks (✓).

## Common Commands

### Development
```bash
# Start emulators
firebase emulators:start --only firestore,auth

# Start emulators with test data
firebase emulators:start --import=./test-data

# Export test data
firebase emulators:export ./test-data
```

### Deployment (When Ready)
```bash
# Deploy to Firebase
firebase deploy --only firestore:rules,firestore:indexes

# View deployed rules
firebase firestore:rules get
```

### iOS Development
```bash
# Build iOS app
cd ios && xcodebuild -workspace DDRide.xcworkspace -scheme DDRide

# Run tests
xcodebuild test -workspace DDRide.xcworkspace -scheme DDRide -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Directory Structure

```
DDRideApp/
├── ios/DDRide/              # iOS app code
│   ├── Core/
│   │   ├── Models/          # Swift data models
│   │   └── Services/        # Firebase & Auth services
│   ├── Features/            # App features (to be built)
│   └── Resources/           # Assets, config files
├── firestore.rules          # Security rules
├── firestore.indexes.json   # Database indexes
└── firebase.json            # Firebase config
```

## Key Files

- **FirebaseService.swift** - All Firestore operations
- **AuthService.swift** - Authentication logic
- **firestore.rules** - Security rules (enforces @ksu.edu)
- **User.swift** - User model with role, classYear, etc.

## Default Test Data

Create these in Emulator UI for testing:

### Test Chapter
```json
{
  "id": "test-chapter-1",
  "name": "Test Fraternity",
  "universityId": "ksu",
  "inviteCode": "TEST123",
  "yearTransitionDate": "08-01",
  "organization": "fraternity",
  "isActive": true
}
```

### Test Admin User
```json
{
  "id": "admin-user-id",
  "name": "Test Admin",
  "email": "admin@ksu.edu",
  "phoneNumber": "+15555551234",
  "chapterId": "test-chapter-1",
  "role": "admin",
  "classYear": 4,
  "isEmailVerified": true
}
```

### Test Member User
```json
{
  "id": "member-user-id",
  "name": "Test Member",
  "email": "member@ksu.edu",
  "phoneNumber": "+15555555678",
  "chapterId": "test-chapter-1",
  "role": "member",
  "classYear": 3,
  "isEmailVerified": true
}
```

## Troubleshooting

### App won't connect to emulators
1. Verify emulators are running (check Terminal 1)
2. Check for "🔧 Firebase Emulators configured" in Xcode console
3. Ensure running in DEBUG mode (not RELEASE)
4. Restart app and emulators

### Authentication fails
1. Check email is @ksu.edu
2. Verify email verification status
3. Check security rules in Emulator UI
4. View Auth tab in Emulator UI for user details

### Permission denied errors
1. Check user role (admin vs member)
2. Verify email is verified
3. Test security rules in Emulator UI
4. Check firestore.rules for the specific operation

### Build errors
1. Clean build folder: Product → Clean Build Folder (⌘⇧K)
2. Reset packages: File → Packages → Reset Package Caches
3. Restart Xcode

## Documentation

- **FIREBASE_BACKEND_SETUP.md** - Complete data model and architecture
- **FIREBASE_DEPLOYMENT.md** - Deployment guide and commands
- **FIREBASE_SETUP_COMPLETE.md** - Setup verification and status
- **CLAUDE.md** - Project overview and business logic

## Next Steps

1. ✓ Backend setup complete
2. → Build authentication UI (sign in/up screens)
3. → Build admin dashboard
4. → Build member ride request flow
5. → Build DD interface
6. → Implement real-time ride queue
7. → Add push notifications
8. → Implement Cloud Functions
9. → Deploy to TestFlight
10. → Production launch

## Quick Test Flow

1. Start emulators
2. Run iOS app
3. Sign up as admin@ksu.edu
4. Create a test event
5. Assign yourself as DD
6. Sign up as member@ksu.edu (different simulator/device)
7. Request a ride
8. See real-time updates in both apps

## Support

Questions? Check:
1. FIREBASE_BACKEND_SETUP.md for data model
2. FIREBASE_DEPLOYMENT.md for deployment help
3. Firebase Console logs
4. Emulator UI for debugging

---

**Status: Backend Ready ✓**

Start building the iOS UI!

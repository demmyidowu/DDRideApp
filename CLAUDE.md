# DD Ride App - K-State Designated Driver Management

## Project Overview
iOS app for managing designated drivers for K-State fraternities and sororities.

## Tech Stack
- **Frontend**: Swift 5.9+, SwiftUI, Combine, iOS 17+
- **Backend**: Firebase (Firestore, Cloud Functions, Authentication)
- **SMS**: Twilio
- **Location**: Core Location, MapKit
- **Push Notifications**: Firebase Cloud Messaging

## Repository Structure
```
DDRideApp/
├── .claude/                  # Claude Code configuration
│   ├── agents/              # Custom subagents
│   ├── skills/              # Custom skills
│   └── commands/            # Custom commands
├── ios/                     # iOS Xcode project
│   ├── DDRide/             # Main app code
│   │   ├── App/
│   │   ├── Core/
│   │   ├── Features/
│   │   ├── Shared/
│   │   └── Resources/
│   └── DDRide.xcodeproj
├── functions/               # Firebase Cloud Functions
│   └── src/
└── CLAUDE.md               # This file
```

## Key Features
1. **Admin Dashboard**: DD assignment, event management, member management
2. **Ride Request System**: Smart queue with priority algorithm
3. **SMS Notifications**: Twilio integration for ride updates
4. **Automatic Year Transitions**: Scheduled task on Aug 1
5. **KSU Email Verification**: Enforce @ksu.edu domain
6. **Emergency Button**: Immediate priority with admin alerts
7. **DD Activity Monitoring**: Track inactive toggles and prolonged inactivity
8. **Ride Logs**: Complete audit trail for liability

## Critical Business Rules

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
Assign to DD with **shortest wait time** (soonest availability):
1. If DD has no active rides → 0 minutes wait
2. If DD has rides → sum estimated time for all queued/active rides
3. Assign to DD with minimum wait time

Queue position shown to rider is **overall position across all DDs**, not per-DD.

### Location Capture
- **One-time only** when rider requests ride (battery efficient)
- **One-time only** when DD marks "en route" (for ETA calculation)
- **No background tracking**

### SMS Triggers
1. Ride assigned → SMS to DD with pickup address
2. DD en route → SMS to rider with DD info + ETA

### Year Transition
- Scheduled: August 1st, midnight (Cloud Scheduler)
- Remove all seniors (classYear === 4)
- Increment everyone else's classYear by 1
- Notify admin to add new freshmen

### DD Monitoring
- Alert admin if DD toggles inactive >5 times in 30 minutes
- Notify DD if inactive >15 minutes during assigned shift

## Development Workflow

### Using Subagents
This project uses specialized subagents for different tasks:
- `swift-ios-architect`: App architecture and structure
- `firebase-backend-engineer`: Backend logic and Cloud Functions
- `swiftui-developer`: UI components and views
- `business-logic-specialist`: Algorithms and business rules
- `location-services-expert`: Core Location and MapKit
- `sms-integration-specialist`: Twilio SMS integration
- `test-automator`: Unit and integration tests
- `debugger`: Bug investigation and fixes

### Development Commands
```bash
# Start iOS development
cd ios
open DDRide.xcworkspace

# Run tests
xcodebuild test -workspace ios/DDRide.xcworkspace -scheme DDRide -destination 'platform=iOS Simulator,name=iPhone 15'

# Firebase emulators
firebase emulators:start --only firestore,functions,auth

# Deploy to Firebase
firebase deploy --only functions
firebase deploy --only firestore:rules
```

## Getting Started

1. Set up Firebase project
2. Configure Twilio account
3. Create Xcode project structure
4. Implement authentication flow
5. Build admin dashboard
6. Implement ride request system
7. Test with Firebase emulators
8. Deploy to TestFlight

## Important Notes
- Always test with Firebase emulators before production
- Use @ksu.edu emails only for beta testing
- SMS costs ~$0.0079 per message
- Location permission: "When In Use" only (not "Always")
- Keep all Firebase functions under 60 second timeout

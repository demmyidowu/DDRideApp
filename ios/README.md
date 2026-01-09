# DD Ride iOS App

## Project Setup

This Xcode project has been created with the following structure:

### Folder Structure
```
ios/
├── DDRide/
│   ├── DDRideApp.swift                  # App entry point
│   ├── App/
│   │   ├── ContentView.swift            # Root view with auth routing
│   │   └── MainTabView.swift            # Main tab navigation
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── User.swift
│   │   │   ├── Chapter.swift
│   │   │   ├── Event.swift
│   │   │   ├── Ride.swift
│   │   │   └── DDAssignment.swift
│   │   ├── Services/
│   │   │   ├── AuthService.swift        # Firebase Authentication
│   │   │   ├── FirestoreService.swift   # Firestore operations
│   │   │   ├── LocationService.swift    # Core Location (one-time capture)
│   │   │   └── NotificationService.swift # Push notifications
│   │   └── Utilities/
│   │       ├── Constants.swift          # App constants
│   │       ├── Extensions.swift         # Swift extensions
│   │       └── Helpers.swift            # Helper functions
│   ├── Features/
│   │   ├── Authentication/
│   │   │   ├── LoginView.swift
│   │   │   ├── SignUpView.swift
│   │   │   ├── EmailVerificationView.swift
│   │   │   └── ForgotPasswordView.swift
│   │   ├── Admin/
│   │   │   └── AdminDashboardView.swift
│   │   ├── DD/
│   │   │   └── DDDashboardView.swift
│   │   ├── Rider/
│   │   │   └── RiderDashboardView.swift
│   │   └── Profile/
│   │       └── ProfileView.swift
│   ├── Shared/
│   │   ├── Components/
│   │   │   ├── CustomButton.swift       # Reusable button styles
│   │   │   ├── LoadingView.swift        # Loading state view
│   │   │   └── ErrorView.swift          # Error state view
│   │   └── Styles/
│   │       └── AppTheme.swift           # App-wide theming
│   └── Resources/
│       ├── Assets.xcassets              # Images and colors
│       ├── Info.plist                   # App configuration
│       └── GoogleService-Info.plist     # Firebase config (placeholder)
└── DDRide.xcodeproj
```

## Next Steps

### 1. Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing
3. Add an iOS app with bundle ID: `com.ddride.app`
4. Download `GoogleService-Info.plist`
5. Replace the placeholder file at `ios/DDRide/Resources/GoogleService-Info.plist`

### 2. Install Firebase SDK

#### Using Swift Package Manager (Recommended)
1. Open `DDRide.xcodeproj` in Xcode
2. Go to File > Add Package Dependencies
3. Enter: `https://github.com/firebase/firebase-ios-sdk`
4. Select version: 10.0.0 or later
5. Add these packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseMessaging
   - FirebaseAnalytics (optional)

### 3. Build and Run
```bash
cd ios
open DDRide.xcodeproj

# Or use command line
xcodebuild -project DDRide.xcodeproj -scheme DDRide -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Project Configuration

### Minimum Requirements
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Bundle Identifier
`com.ddride.app`

### Key Features Implemented
- MVVM Architecture
- SwiftUI + Combine
- Firebase Authentication with KSU email validation
- Location Services (one-time capture only)
- Push Notifications
- Priority-based ride queue algorithm
- DD assignment algorithm
- Role-based navigation (Admin/DD/Rider)

### Location Permissions
The app requests "When In Use" location permission only:
- Captured once when rider requests a ride
- Captured once when DD marks "en route"
- No background tracking

### Info.plist Keys
- `NSLocationWhenInUseUsageDescription`: Location permission explanation
- `UIBackgroundModes`: Remote notifications

## Development Guidelines

### Code Style
- Use SwiftUI for all UI
- Use async/await for asynchronous operations
- Use @MainActor for view models
- Follow MVVM pattern strictly
- Use dependency injection

### State Management
- `@State`: View-local state
- `@StateObject`: ViewModel ownership
- `@ObservedObject`: Passed ViewModels
- `@EnvironmentObject`: App-wide services (AuthService)
- `@Published`: ViewModel properties

### Testing
- Unit tests for business logic (Helpers, Calculators)
- Integration tests for Firebase operations
- UI tests for critical flows

## Firebase Emulators (Development)
```bash
# Start emulators
firebase emulators:start --only auth,firestore

# Update Firestore settings in code to use emulator
# See FirestoreService.swift for configuration
```

## Troubleshooting

### Common Issues

1. **Firebase not configured**
   - Ensure `GoogleService-Info.plist` is added to project
   - Verify Firebase SDK is installed via SPM

2. **Location permission denied**
   - Check Info.plist has location usage descriptions
   - Verify app requests permission in LocationService

3. **Build errors**
   - Clean build folder: Product > Clean Build Folder
   - Reset package cache: File > Packages > Reset Package Caches

## Additional Resources
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)

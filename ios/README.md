# DDRide iOS Application

## Project Overview
Native iOS application for managing designated drivers for K-State fraternities and sororities.

## Technical Specifications
- **Minimum iOS Version**: 17.0
- **Swift Version**: 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with Combine
- **Bundle ID**: com.ddride.app
- **Organization**: DD Ride

## Project Structure

```
DDRide/
├── DDRideApp.swift              # App entry point
├── App/                         # Main app views
│   ├── ContentView.swift        # Root view with auth routing
│   └── MainTabView.swift        # Tab navigation for authenticated users
├── Core/
│   ├── Models/                  # Data models
│   │   ├── User.swift
│   │   ├── Chapter.swift
│   │   ├── Event.swift
│   │   ├── Ride.swift
│   │   └── DDAssignment.swift
│   ├── Services/                # Business logic services
│   │   ├── AuthService.swift
│   │   ├── FirestoreService.swift
│   │   ├── LocationService.swift
│   │   └── NotificationService.swift
│   └── Utilities/               # Helper classes and extensions
│       ├── Constants.swift
│       ├── Extensions.swift
│       └── Helpers.swift
├── Features/                    # Feature modules
│   ├── Authentication/
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   ├── EmailVerificationView.swift
│   │   └── ForgotPasswordView.swift
│   ├── Admin/
│   │   └── AdminDashboardView.swift
│   ├── DD/
│   │   └── DDDashboardView.swift
│   ├── Rider/
│   │   └── RiderDashboardView.swift
│   └── Profile/
│       └── ProfileView.swift
├── Shared/                      # Reusable components
│   ├── Components/
│   │   ├── CustomButton.swift
│   │   ├── LoadingView.swift
│   │   └── ErrorView.swift
│   └── Styles/
│       └── AppTheme.swift
└── Resources/
    ├── Assets.xcassets          # Images and colors
    ├── Info.plist               # App configuration
    └── GoogleService-Info.plist # Firebase configuration
```

## Getting Started

### Prerequisites
1. Xcode 15.0 or later
2. macOS Ventura 13.0 or later
3. Active Apple Developer account (for device testing)
4. Firebase project configured

### Opening the Project
```bash
cd ios
open DDRide.xcodeproj
```

### Firebase Setup
1. Download `GoogleService-Info.plist` from your Firebase project
2. Place it in `ios/DDRide/Resources/`
3. Ensure it's added to the DDRide target

### Building the App
1. Select the DDRide scheme
2. Choose a simulator or device
3. Press Cmd+R to build and run

### Running Tests
```bash
xcodebuild test \
  -project DDRide.xcodeproj \
  -scheme DDRide \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture Pattern

### MVVM + Combine
- **Models**: Codable structs conforming to Identifiable
- **Views**: SwiftUI views with minimal logic
- **ViewModels**: @MainActor ObservableObject classes
- **Services**: Protocol-based singletons for reusability

### State Management
- `@State`: View-local UI state
- `@StateObject`: ViewModel ownership
- `@ObservedObject`: Passed ViewModels
- `@EnvironmentObject`: App-wide shared state (AuthService)
- `@Published`: Observable ViewModel properties

### Navigation
Using NavigationStack (iOS 16+) with type-safe destinations:
```swift
NavigationStack(path: $navigationPath) {
    RootView()
        .navigationDestination(for: User.self) { user in
            UserDetailView(user: user)
        }
}
```

## Key Dependencies

### Firebase SDK
- FirebaseAuth
- FirebaseFirestore
- FirebaseMessaging (Push Notifications)

### Apple Frameworks
- SwiftUI
- Combine
- CoreLocation
- MapKit
- UserNotifications

## Code Conventions

### Naming
- **Files**: PascalCase matching the main type
- **Types**: PascalCase (User, AuthService)
- **Functions/Variables**: camelCase (fetchUser, isLoading)
- **Constants**: PascalCase for types, camelCase for instances

### File Organization
- One type per file
- Group related types in folders
- Keep ViewModels near their Views

### SwiftUI Best Practices
- Extract subviews when body exceeds 10 lines
- Use ViewModifiers for reusable styling
- Prefer `@MainActor` on ViewModels
- Use `task` modifier over `onAppear` for async work

## Common Tasks

### Adding a New View
1. Create Swift file in appropriate Feature folder
2. Define SwiftUI struct conforming to View
3. Add to navigation in MainTabView or parent view
4. Create corresponding ViewModel if needed

### Adding a New Model
1. Create Swift file in Core/Models
2. Conform to Codable and Identifiable
3. Add Firestore field mappings if needed
4. Update FirestoreService with CRUD operations

### Adding a New Service
1. Create protocol defining interface
2. Create implementation class in Core/Services
3. Make it a singleton with `.shared` if stateless
4. Inject via initializer for testability

## Troubleshooting

### Build Errors
- Clean build folder: Cmd+Shift+K
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Restart Xcode

### Firebase Issues
- Verify GoogleService-Info.plist is in project
- Check bundle ID matches Firebase console
- Ensure Firebase pods are up to date

### Simulator Issues
- Reset simulator: Device > Erase All Content and Settings
- Clear app data: Long press app icon > Delete App

## Resources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

## Support

For questions or issues:
1. Check the CLAUDE.md file in the project root
2. Review Firebase console for backend issues
3. Check Xcode console for runtime errors

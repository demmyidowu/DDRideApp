# Authentication System Documentation

## Overview

The DD Ride app uses Firebase Authentication with email/password sign-in, enforcing K-State email addresses (@ksu.edu) and requiring email verification before full access.

## Architecture

### Components

```
Authentication/
├── AuthService.swift                    # Core authentication service
├── ViewModels/
│   ├── AuthViewModel.swift             # Handles auth UI logic
│   └── EmailVerificationViewModel.swift # Email verification flow
└── Views/
    ├── LoginView.swift                 # Sign in screen
    ├── SignUpView.swift                # Registration screen
    ├── EmailVerificationView.swift     # Email verification prompt
    └── ForgotPasswordView.swift        # Password reset screen
```

## Authentication Flow

### 1. Sign Up Flow

```swift
User enters details → Validate @ksu.edu email → Create Firebase user →
Send verification email → Create Firestore document → Show EmailVerificationView
```

**Validations:**
- Email must end with `@ksu.edu`
- Password must be 8+ characters
- Password must contain uppercase, lowercase, and number
- Phone number must be 10 digits (formatted as E.164: +1XXXXXXXXXX)

### 2. Sign In Flow

```swift
User enters credentials → Firebase sign in → Check email verified →
Fetch user document → Update auth state → Navigate to app
```

If email not verified, user is shown EmailVerificationView.

### 3. Email Verification Flow

```swift
User receives email → Clicks verification link → Opens app →
Clicks "I've Verified My Email" → Reload Firebase user →
Check isEmailVerified → Update Firestore document → Grant access
```

### 4. Password Reset Flow

```swift
User enters email → Validate @ksu.edu → Send reset email →
User clicks link → Resets password → Returns to login
```

## Auth States

```swift
enum AuthState {
    case signedOut                  // No user signed in
    case emailNotVerified(User)     // Signed in but email not verified
    case signedIn(User)             // Signed in with verified email
}
```

## Usage

### Using AuthService

```swift
// Observe auth state in your app
@StateObject private var authService = AuthService.shared

var body: some View {
    Group {
        switch authService.authState {
        case .signedOut:
            LoginView()
        case .emailNotVerified:
            EmailVerificationView()
        case .signedIn(let user):
            MainAppView(user: user)
        }
    }
}
```

### Sign Up

```swift
let viewModel = AuthViewModel()

// In your view
await viewModel.signUp()

// Automatically sends verification email
// and shows EmailVerificationView
```

### Sign In

```swift
let viewModel = AuthViewModel()

await viewModel.signIn()

// Checks email verification
// and navigates based on auth state
```

### Check Email Verification

```swift
let viewModel = EmailVerificationViewModel()

let isVerified = await viewModel.checkVerification()
```

### Sign Out

```swift
let viewModel = AuthViewModel()

viewModel.signOut()
```

## Security Features

### Email Validation

All email addresses are validated to ensure they end with `@ksu.edu`:

```swift
private func validateKSUEmail(_ email: String) -> Bool {
    return email.lowercased().hasSuffix("@ksu.edu")
}
```

### Password Requirements

```swift
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
```

### Phone Number Formatting

Phone numbers are automatically formatted to E.164 format (+1XXXXXXXXXX):

```swift
// Input: (555) 123-4567
// Stored: +15551234567
```

### Email Verification Enforcement

Users cannot access the app until their email is verified. The Firebase Security Rules also enforce this:

```javascript
match /users/{userId} {
  allow read: if request.auth != null &&
                request.auth.token.email_verified == true;
}
```

## Error Handling

### Custom Auth Errors

```swift
enum AuthError: LocalizedError {
    case invalidEmail           // Not @ksu.edu
    case invalidName           // Empty name
    case invalidPhoneNumber    // Invalid format
    case emailNotVerified      // Email not verified
    case notAuthenticated      // No user signed in
    case passwordTooShort      // < 8 characters
    case passwordNeedsUppercase
    case passwordNeedsLowercase
    case passwordNeedsNumber
}
```

### Firebase Auth Errors

Firebase errors are converted to user-friendly messages:

```swift
extension AuthErrorCode {
    var friendlyMessage: String {
        switch self {
        case .emailAlreadyInUse:
            return "This email is already registered."
        case .wrongPassword:
            return "Incorrect password."
        // ... more cases
        }
    }
}
```

## User Model

```swift
struct User: Codable, Identifiable, Equatable {
    let id: String              // Firebase Auth UID
    var name: String
    var email: String           // @ksu.edu
    var phoneNumber: String     // E.164 format
    var chapterId: String       // Set by admin
    var role: UserRole          // admin or member
    var classYear: Int          // 1-4 (1=freshman, 4=senior)
    var isEmailVerified: Bool
    var fcmToken: String?       // Push notifications
    var createdAt: Date
    var updatedAt: Date
}
```

## Integration with Firebase

### Firestore Document Creation

After successful signup, a Firestore document is created:

```swift
func signUp(...) async throws {
    // Create Firebase Auth user
    let authResult = try await Auth.auth().createUser(...)

    // Create Firestore document
    let user = User(
        id: authResult.user.uid,
        name: name,
        email: email,
        // ... other fields
        isEmailVerified: false
    )

    try await createUserDocument(user)
}
```

### Email Verification Status Sync

When email is verified, the Firestore document is updated:

```swift
func checkEmailVerification() async throws -> Bool {
    try await firebaseUser.reload()

    if firebaseUser.isEmailVerified {
        var updatedUser = user
        updatedUser.isEmailVerified = true
        updatedUser.updatedAt = Date()
        try await updateUserDocument(updatedUser)
    }
}
```

## UI Components

### SignUpView

- Full name field
- K-State email field with validation
- Phone number field with formatting
- Password field with strength indicator
- Confirm password field
- Real-time validation feedback
- Password requirements checklist

### LoginView

- Email field
- Password field
- Sign in button
- Forgot password link
- Create account link

### EmailVerificationView

- Instructions to check email
- "I've Verified My Email" button
- Resend email button (with 60-second cooldown)
- Sign out option

### ForgotPasswordView

- Email input field
- Send reset link button
- Success confirmation

## Best Practices

### 1. Always Use Lowercase Emails

```swift
email.lowercased()
```

### 2. Validate Before Submission

```swift
guard validateKSUEmail(email) else {
    throw AuthError.invalidEmail
}
```

### 3. Handle Loading States

```swift
@Published var isLoading = false

func signIn() async {
    isLoading = true
    defer { isLoading = false }
    // ... auth logic
}
```

### 4. Show User-Friendly Errors

```swift
.alert("Error", isPresented: $viewModel.showError) {
    Button("OK") {}
} message: {
    Text(viewModel.errorMessage ?? "An error occurred")
}
```

### 5. Observe Auth State Changes

```swift
Auth.auth().addStateDidChangeListener { auth, user in
    Task {
        await handleAuthStateChange(user)
    }
}
```

## Testing

### Manual Test Checklist

- [ ] Sign up with non-KSU email (should fail)
- [ ] Sign up with weak password (should fail)
- [ ] Sign up with valid credentials (should succeed)
- [ ] Receive verification email
- [ ] Try to sign in before verification (should show EmailVerificationView)
- [ ] Verify email and sign in (should succeed)
- [ ] Request password reset
- [ ] Sign out

### Edge Cases

- [ ] Network error during sign up
- [ ] Network error during sign in
- [ ] Email already registered
- [ ] User tries to sign in immediately after signup
- [ ] User closes app during verification
- [ ] User resends verification email multiple times

## Future Enhancements

- [ ] Add rate limiting for signup attempts
- [ ] Add biometric authentication (Face ID / Touch ID)
- [ ] Add social sign-in (Google, Apple)
- [ ] Add session timeout
- [ ] Add device tracking
- [ ] Add two-factor authentication

## Troubleshooting

### User Can't Receive Verification Email

1. Check spam folder
2. Verify Firebase email templates are configured
3. Check Firebase Console → Authentication → Templates
4. Use resend email button

### User Verified Email But Still Sees Verification Screen

1. Ensure user clicks "I've Verified My Email" button
2. Check Firebase Auth user's emailVerified field
3. Check network connectivity
4. Try signing out and back in

### Firebase Auth Errors

Check Firebase Console → Authentication → Users for:
- User account status
- Email verification status
- Last sign-in time

## Related Files

- `/ios/DDRide/Core/Models/User.swift` - User data model
- `/ios/DDRide/Core/Services/FirestoreService.swift` - Firestore operations
- `/functions/src/auth/` - Cloud Functions for auth triggers
- `/firestore.rules` - Security rules

## Support

For issues or questions:
1. Check Firebase Console for error logs
2. Review FirebaseAuth documentation
3. Check app logs for detailed error messages

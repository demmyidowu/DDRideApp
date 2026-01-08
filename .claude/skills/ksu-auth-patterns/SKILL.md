---
name: ksu-auth-patterns
description: K-State email authentication patterns for Firebase. Use when implementing user registration, email verification, or authentication flows requiring @ksu.edu domains.
---

# KSU Authentication Patterns

## When to Use This Skill
Use when implementing authentication that requires K-State email addresses (@ksu.edu).

## Email Validation Pattern
```swift
import FirebaseAuth

class AuthService {
    func validateKSUEmail(_ email: String) -> Bool {
        return email.lowercased().hasSuffix("@ksu.edu")
    }
    
    func signUp(email: String, password: String) async throws -> User {
        // Validate KSU email
        guard validateKSUEmail(email) else {
            throw AuthError.invalidEmail("Must use K-State email (@ksu.edu)")
        }
        
        // Create Firebase user
        let authResult = try await Auth.auth().createUser(
            withEmail: email,
            password: password
        )
        
        // Send verification email
        try await authResult.user.sendEmailVerification()
        
        return authResult.user
    }
    
    func checkEmailVerified() async throws -> Bool {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        try await user.reload()
        return user.isEmailVerified
    }
}
```

## Firebase Rules Integration
```javascript
// firestore.rules
match /users/{userId} {
  allow create: if request.auth != null 
    && request.auth.token.email.matches('.*@ksu\\.edu$')
    && request.auth.token.email_verified == true;
}
```

## SwiftUI Login Flow
```swift
struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("K-State Email", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $password)
            
            Button("Sign Up") {
                Task {
                    await signUp()
                }
            }
            .disabled(!email.hasSuffix("@ksu.edu"))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    func signUp() async {
        do {
            try await AuthService.shared.signUp(email: email, password: password)
            // Show email verification screen
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Error Messages
- "Must use K-State email address"
- "Please verify your K-State email before continuing"
- "Email verification sent to your K-State inbox"
- "Invalid K-State email format"

## Security Notes
- Always verify email before granting access
- Store email in lowercase for consistency
- Check `email_verified` token claim in Firebase rules
- Rate limit signup attempts to prevent abuse
- Never store passwords client-side

## Testing
```swift
func testKSUEmailValidation() {
    XCTAssertTrue(validateKSUEmail("student@ksu.edu"))
    XCTAssertTrue(validateKSUEmail("STUDENT@KSU.EDU"))
    XCTAssertFalse(validateKSUEmail("student@gmail.com"))
    XCTAssertFalse(validateKSUEmail("student@k-state.edu"))
}
```

# Firebase Deployment Guide - DD Ride App

Quick reference for deploying and testing the Firebase backend.

## Prerequisites

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase project (if not done already):
```bash
firebase init
```
Select:
- Firestore
- Functions (for Cloud Functions - optional for now)
- Authentication (optional, web-based)
- Hosting (optional, for privacy policy page)

## Local Development with Emulators

### Start Emulators
```bash
firebase emulators:start --only firestore,auth
```

This starts:
- Firestore Emulator: `http://localhost:8080`
- Auth Emulator: `http://localhost:9099`
- Emulator UI: `http://localhost:4000`

### Export Emulator Data
```bash
firebase emulators:export ./emulator-data
```

### Import Emulator Data
```bash
firebase emulators:start --import=./emulator-data
```

## Deployment Commands

### Deploy Everything
```bash
firebase deploy
```

### Deploy Security Rules Only
```bash
firebase deploy --only firestore:rules
```

### Deploy Indexes Only
```bash
firebase deploy --only firestore:indexes
```

### Deploy Cloud Functions Only (when implemented)
```bash
firebase deploy --only functions
```

## Testing Security Rules

### Test with Emulators
```bash
# Start emulators
firebase emulators:start --only firestore,auth

# Run iOS app in DEBUG mode (automatically connects to emulators)
# Open ios/DDRide.xcworkspace in Xcode
# Run on simulator
```

### Test Rules Directly
```bash
# Create a test file: firestore.rules.test.js
# Run tests
firebase emulators:exec --only firestore "npm test"
```

## Verify Deployment

### Check Rules
```bash
firebase firestore:rules get
```

### Check Indexes
```bash
firebase firestore:indexes list
```

## Monitor Production

### View Firestore Usage
```bash
firebase firestore:usage
```

### View Logs
```bash
firebase functions:log
```

## Common Issues and Solutions

### Issue: Rules not updating
**Solution:**
```bash
# Force deploy
firebase deploy --only firestore:rules --force
```

### Issue: Index creation timeout
**Solution:**
- Indexes can take several minutes to build
- Check Firebase Console > Firestore > Indexes
- Wait for "Enabled" status

### Issue: iOS app not connecting to emulators
**Solution:**
1. Verify emulators are running
2. Check console output for emulator configuration
3. Ensure running in DEBUG mode (not RELEASE)
4. Check FirebaseService.swift has correct ports

### Issue: Permission denied errors
**Solution:**
1. Check user is authenticated
2. Check user has @ksu.edu email
3. Check email is verified
4. Check user role in Firestore

## Environment Setup

### Development (Emulators)
- Firestore: `localhost:8080`
- Auth: `localhost:9099`
- No real data, no costs
- Auto-configured in DEBUG builds

### Staging (Firebase Project)
- Use a separate Firebase project for staging
- Deploy same rules and indexes
- Test with real Firebase services
- Minimal costs

### Production (Firebase Project)
- Production Firebase project
- Deploy tested rules and indexes
- Monitor usage and costs
- Set up billing alerts

## Security Checklist Before Production

- [ ] All security rules tested with emulators
- [ ] KSU email validation working
- [ ] Email verification required
- [ ] Admin-only operations protected
- [ ] Chapter isolation working (users can only access their chapter)
- [ ] Year transition logs are read-only from client
- [ ] All indexes deployed and enabled
- [ ] Firebase project has billing enabled
- [ ] Billing alerts configured
- [ ] Backup strategy defined

## Cost Monitoring

### Set Budget Alert
1. Go to Firebase Console > Usage and Billing
2. Set budget alert at $25/month
3. Configure email notifications

### Firestore Costs (Approximate)
- Document reads: $0.06 per 100,000 reads
- Document writes: $0.18 per 100,000 writes
- Document deletes: $0.02 per 100,000 deletes
- Storage: $0.18 per GB per month

### Optimization Tips
1. Use client-side caching (already configured)
2. Limit query results with `.limit()`
3. Use real-time listeners sparingly
4. Batch writes when updating multiple documents
5. Delete old completed rides after 30 days

## Quick Commands Reference

```bash
# Start development
firebase emulators:start --only firestore,auth

# Deploy to production
firebase deploy --only firestore:rules,firestore:indexes

# View production logs
firebase firestore:usage

# Export emulator data (for testing)
firebase emulators:export ./test-data

# Run with test data
firebase emulators:start --import=./test-data

# Check deployment status
firebase deploy:list
```

## Support

- Firebase Documentation: https://firebase.google.com/docs
- Firestore Security Rules: https://firebase.google.com/docs/firestore/security/get-started
- Firebase Support: https://firebase.google.com/support

## Next Steps

1. Start emulators and test authentication flow
2. Create test user accounts with @ksu.edu emails
3. Test all CRUD operations
4. Verify security rules work as expected
5. Deploy to staging environment
6. Test with TestFlight beta
7. Deploy to production

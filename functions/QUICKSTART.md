# Quick Start Guide - Firebase Cloud Functions

Get your Cloud Functions up and running in 5 minutes.

## Prerequisites

- Node.js 24+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Twilio account (for SMS features)

## Step 1: Install Dependencies

```bash
cd functions
npm install
```

## Step 2: Configure Twilio

```bash
# Login to Firebase
firebase login

# Select your project
firebase use <your-project-id>

# Set Twilio credentials
firebase functions:config:set \
  twilio.sid="YOUR_TWILIO_ACCOUNT_SID" \
  twilio.token="YOUR_TWILIO_AUTH_TOKEN" \
  twilio.number="+1234567890"
```

Get your Twilio credentials from: https://console.twilio.com

## Step 3: Build TypeScript

```bash
npm run build
```

## Step 4: Test Locally (Optional)

```bash
# Download config for local testing
firebase functions:config:get > .runtimeconfig.json

# Start emulators (from project root)
cd ..
firebase emulators:start --only functions,firestore,auth
```

## Step 5: Deploy

```bash
# From functions directory
firebase deploy --only functions
```

Wait 2-5 minutes for deployment to complete.

## Step 6: Deploy Firestore Indexes

```bash
# From project root
firebase deploy --only firestore:indexes
```

Wait 5-10 minutes for indexes to build.

## Step 7: Verify Deployment

```bash
# List deployed functions
firebase functions:list

# View logs
firebase functions:log

# Test by creating a ride document in Firestore
# Should trigger autoAssignRide function
```

## Expected Functions

After deployment, you should see:
- `autoAssignRide` - Ride assignment
- `notifyDDNewRide` - SMS to DD
- `notifyRiderEnRoute` - SMS to rider
- `incrementDDRideCount` - Ride counter
- `yearTransition` - Scheduled annual task
- `monitorDDActivity` - DD monitoring
- `handleEmergencyRide` - Emergency handling
- `monitorEmergencyRideStatus` - Emergency monitoring

## Troubleshooting

### Build Errors
```bash
# Clean build
rm -rf lib
npm run build
```

### Deployment Fails
```bash
# Check Firebase project
firebase use

# Verify you're logged in
firebase login

# Check for TypeScript errors
npm run build
```

### Functions Not Triggering
```bash
# Check logs for errors
firebase functions:log --only-errors

# Verify indexes are ready
# Go to Firebase Console > Firestore > Indexes
```

### SMS Not Sending
```bash
# Verify Twilio config
firebase functions:config:get

# Check function logs
firebase functions:log --only notifyDDNewRide

# Test Twilio credentials at console.twilio.com
```

## Next Steps

- Read [README.md](./README.md) for function details
- Read [DEPLOYMENT.md](./DEPLOYMENT.md) for advanced deployment
- Set up monitoring in Firebase Console
- Configure budget alerts

## Support

If you encounter issues:
1. Check function logs: `firebase functions:log`
2. Verify Firestore indexes in Firebase Console
3. Review [DEPLOYMENT.md](./DEPLOYMENT.md) troubleshooting section
4. Check Firebase Status: https://status.firebase.google.com

---

**Setup Time**: ~5-10 minutes
**Index Build Time**: ~5-10 minutes
**Total Time**: ~15 minutes

# Firebase Cloud Functions - DD Ride App

Production-ready Cloud Functions for automated ride assignment, SMS notifications, and chapter management.

## Overview

This directory contains all serverless backend logic for the DD Ride App, including:

- **Ride Assignment**: Automatic DD assignment using shortest wait time algorithm
- **SMS Notifications**: Twilio integration for ride status updates
- **Year Transition**: Automated class year advancement (August 1st)
- **DD Monitoring**: Activity tracking and admin alerts
- **Emergency Handling**: Priority routing and instant notifications

## Architecture

```
functions/
├── src/
│   ├── index.ts                  # Main exports
│   ├── rideAssignment.ts         # Auto-assign rides to DDs
│   ├── smsNotifications.ts       # Twilio SMS integration
│   ├── yearTransition.ts         # Annual class year updates
│   ├── ddMonitoring.ts          # DD activity alerts
│   ├── emergencyHandler.ts      # Emergency ride handling
│   └── utils/
│       ├── twilioClient.ts      # SMS helper with retry logic
│       └── validation.ts        # Input validation utilities
├── package.json
├── tsconfig.json
├── DEPLOYMENT.md                # Detailed deployment guide
└── README.md                    # This file
```

## Functions Reference

### 1. Ride Management

#### `autoAssignRide`
**Trigger**: `onCreate rides/{rideId}`
**Purpose**: Automatically assigns new rides to DD with shortest wait time

**Algorithm**:
1. Fetch all active DDs for the event
2. Calculate wait time for each DD (active rides × 15 mins)
3. Assign to DD with minimum wait time
4. Update ride with DD info and status "assigned"

**Example**:
```typescript
// When a ride document is created:
{
  riderId: "user123",
  eventId: "event456",
  status: "queued",
  pickupAddress: "123 Main St"
}

// Function automatically updates to:
{
  ...previousFields,
  ddId: "dd789",
  ddName: "John Smith",
  ddPhoneNumber: "+15551234567",
  ddCarDescription: "Blue Honda Civic",
  status: "assigned",
  assignedTime: Timestamp,
  estimatedWaitTime: 5
}
```

---

### 2. SMS Notifications

#### `notifyDDNewRide`
**Trigger**: `onUpdate rides/{rideId}` (queued → assigned)
**Purpose**: Send SMS to DD when ride is assigned

**SMS Format**:
```
New ride: {riderName} at {pickupAddress}
```

**Emergency Format**:
```
🚨 EMERGENCY RIDE: {riderName} at {pickupAddress}
```

#### `notifyRiderEnRoute`
**Trigger**: `onUpdate rides/{rideId}` (assigned → enroute)
**Purpose**: Send SMS to rider when DD starts driving

**SMS Format**:
```
{ddName} in {carDescription} is {ETA} mins away
```

#### `incrementDDRideCount`
**Trigger**: `onUpdate rides/{rideId}` (any → completed)
**Purpose**: Update DD's total completed rides counter

---

### 3. Scheduled Tasks

#### `yearTransition`
**Trigger**: Scheduled (August 1st, 00:00 America/Chicago)
**Purpose**: Annual class year transition

**Actions**:
1. Remove all seniors (classYear === 4)
2. Advance all other members (classYear += 1)
3. Create audit log in `yearTransitionLogs` collection
4. Notify chapter admins to add new freshmen

**Example Log**:
```typescript
{
  executionDate: Timestamp,
  chaptersProcessed: 3,
  seniorsRemoved: 45,
  usersAdvanced: 150,
  status: "success",
  chapterResults: [
    {
      chapterId: "chapter1",
      chapterName: "Alpha Chapter",
      seniorsRemoved: 15,
      usersAdvanced: 50,
      status: "success"
    }
  ]
}
```

---

### 4. Activity Monitoring

#### `monitorDDActivity`
**Trigger**: `onUpdate events/{eventId}/ddAssignments/{ddId}`
**Purpose**: Monitor DD activity and create alerts

**Checks**:
1. **Excessive Toggles**: Alert if DD toggles inactive >5 times
2. **Prolonged Inactivity**: Alert if inactive >15 minutes during event
3. **Auto-Reset**: Reset toggle counter after 30 minutes

**Alert Types**:
- `dd_inactive`: Excessive toggles or prolonged inactivity

---

### 5. Emergency Handling

#### `handleEmergencyRide`
**Trigger**: `onCreate rides/{rideId}` where `isEmergency === true`
**Purpose**: Immediate priority and admin notification

**Actions**:
1. Set ride priority to 9999 (always first in queue)
2. Create admin alert
3. TODO: Send push notification to chapter admins

**Alert Format**:
```
🚨 EMERGENCY RIDE REQUEST
Event: Friday Night Event
Rider: Jane Doe
Location: 123 Main St
Reason: Medical emergency
```

#### `monitorEmergencyRideStatus`
**Trigger**: `onCreate rides/{rideId}` where `isEmergency === true`
**Purpose**: Alert if emergency ride not assigned within 2 minutes

---

## Setup

### Prerequisites
- Node.js 24+
- Firebase CLI (`npm install -g firebase-tools`)
- Twilio account

### Installation
```bash
cd functions
npm install
```

### Build
```bash
npm run build
```

### Local Development
```bash
# Start Firebase emulators
npm run serve

# Or from project root
firebase emulators:start --only functions,firestore,auth
```

---

## Configuration

### Twilio Setup
```bash
# Set Twilio credentials (required for SMS)
firebase functions:config:set \
  twilio.sid="ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
  twilio.token="your_auth_token_here" \
  twilio.number="+15551234567"

# Verify configuration
firebase functions:config:get

# Download for local testing
firebase functions:config:get > .runtimeconfig.json
```

**Important**: Never commit `.runtimeconfig.json` to git!

---

## Deployment

### Full Deployment
```bash
cd functions
npm run build
firebase deploy --only functions
```

### Deploy Single Function
```bash
firebase deploy --only functions:autoAssignRide
```

### Deploy Multiple Functions
```bash
firebase deploy --only functions:autoAssignRide,functions:notifyDDNewRide
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for comprehensive deployment guide.

---

## Testing

### Unit Tests
```bash
cd functions
npm test
```

### Integration Testing with Emulators
```bash
# Terminal 1: Start emulators
firebase emulators:start

# Terminal 2: Run tests or manual operations
firebase functions:shell
```

### Manual Test Cases

#### Test Ride Assignment
```javascript
// Create test ride in Firestore
{
  riderId: "test_user_1",
  eventId: "test_event_1",
  status: "queued",
  riderName: "Test Rider",
  riderPhoneNumber: "+15551111111",
  pickupAddress: "123 Test St",
  isEmergency: false
}

// Expected: autoAssignRide executes and assigns DD
```

#### Test SMS Notification
```javascript
// Update ride status
status: "queued" → "assigned"

// Expected: notifyDDNewRide sends SMS to DD
```

#### Test Year Transition
```bash
# In functions shell
yearTransition()

# Check yearTransitionLogs collection
```

---

## Monitoring

### View Logs
```bash
# All logs
firebase functions:log

# Specific function
firebase functions:log --only autoAssignRide

# Real-time
firebase functions:log --follow

# Errors only
firebase functions:log --only-errors
```

### Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project
3. Navigate to Functions
4. View metrics: invocations, errors, execution time

### Key Metrics
- **Error Rate**: Should be < 1%
- **Execution Time**: < 10s for most functions
- **Memory Usage**: Within configured limits (256MiB default)

---

## Cost Estimates

### Firebase Functions
- **Free Tier**: 2M invocations/month, 400K GB-seconds
- **Typical Usage**: 10-50k invocations/month (well within free tier)

### Twilio SMS
- **Cost**: ~$0.0079 per SMS
- **Estimate**:
  - 10 rides/event: $0.16 (2 SMS per ride)
  - 100 rides/month: $1.60
  - 1000 rides/month: $16.00

### Total Monthly Cost
- Small chapter (100 rides/month): ~$2-5
- Medium chapter (500 rides/month): ~$8-12
- Large chapter (1000 rides/month): ~$16-25

---

## Error Handling

All functions include comprehensive error handling:

1. **Input Validation**: Check data exists and is valid
2. **Graceful Degradation**: Non-critical errors don't throw
3. **Detailed Logging**: All operations logged with context
4. **Retry Logic**: SMS sends retry 3 times with exponential backoff
5. **Alerts**: Critical failures create admin alerts

### Example Error Log
```json
{
  "severity": "ERROR",
  "message": "SMS attempt 1 failed",
  "to": "+15551234567",
  "error": "Twilio Error 21211: Invalid 'To' Phone Number",
  "code": 21211,
  "rideId": "ride123"
}
```

---

## Security

### Best Practices
1. Never commit secrets (use Firebase config)
2. Validate all inputs (phone numbers, document IDs)
3. Use service account with minimal permissions
4. Monitor logs for suspicious activity
5. Rate limit expensive operations

### Phone Number Validation
```typescript
// E.164 format required: +[country code][number]
const isValid = /^\+[1-9]\d{1,14}$/.test(phoneNumber);
```

---

## Performance Optimization

### Tips
1. **Minimize Firestore reads**: Cache frequently accessed data
2. **Use batch operations**: Group writes when possible
3. **Index optimization**: Ensure all queries have indexes
4. **Early returns**: Check conditions before expensive operations
5. **Appropriate memory**: Use 256MiB unless timeouts occur

### Example Optimization
```typescript
// Bad: Multiple individual reads
for (const doc of docs) {
  await firestore.collection('users').doc(doc.userId).get();
}

// Good: Batch read
const userIds = docs.map(d => d.userId);
const users = await firestore.getAll(
  ...userIds.map(id => firestore.collection('users').doc(id))
);
```

---

## Troubleshooting

### Common Issues

#### Function not executing
```bash
# Check if deployed
firebase functions:list

# Check logs
firebase functions:log --only functionName

# Verify trigger path matches collection structure
```

#### SMS not sending
```bash
# Check Twilio config
firebase functions:config:get

# Check function logs
firebase functions:log --only notifyDDNewRide

# Verify phone number is E.164 format
```

#### Firestore index error
```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Wait 5-10 minutes for index creation
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed troubleshooting guide.

---

## Development Workflow

1. **Make changes** in `src/` directory
2. **Build**: `npm run build`
3. **Test locally**: `firebase emulators:start`
4. **Verify**: Check logs and test cases
5. **Deploy**: `firebase deploy --only functions`
6. **Monitor**: Check logs and metrics

---

## Support

- **Documentation**: [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- **Twilio Docs**: [Twilio API Reference](https://www.twilio.com/docs)
- **Firebase Console**: https://console.firebase.google.com
- **Project Issues**: See GitHub repository

---

## License

Proprietary - K-State DD Ride App

---

**Last Updated**: January 2026
**Node.js Version**: 24
**Firebase Functions Version**: 7.0.0
**TypeScript Version**: 5.7.3

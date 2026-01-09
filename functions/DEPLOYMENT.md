# Firebase Cloud Functions Deployment Guide

Complete guide for deploying and managing Cloud Functions for the DD Ride App.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Rollback](#rollback)
- [Cost Management](#cost-management)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
- **Node.js**: v24 or later
- **Firebase CLI**: Latest version
- **Git**: For version control
- **Twilio Account**: For SMS functionality

### Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Verify Installation
```bash
firebase --version
node --version
```

---

## Initial Setup

### 1. Login to Firebase
```bash
firebase login
```

### 2. Select Firebase Project
```bash
# View available projects
firebase projects:list

# Use specific project
firebase use <project-id>

# Or use interactive selection
firebase use
```

### 3. Install Dependencies
```bash
cd functions
npm install
```

### 4. Build TypeScript
```bash
npm run build
```

---

## Configuration

### Twilio Configuration

**IMPORTANT**: Never commit Twilio credentials to source control.

#### Set Twilio Config (Production)
```bash
firebase functions:config:set \
  twilio.sid="ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
  twilio.token="your_auth_token_here" \
  twilio.number="+15551234567"
```

Replace with your actual Twilio credentials:
- `twilio.sid`: Account SID from Twilio Console
- `twilio.token`: Auth Token from Twilio Console
- `twilio.number`: Your Twilio phone number in E.164 format (+1234567890)

#### Verify Configuration
```bash
firebase functions:config:get
```

Expected output:
```json
{
  "twilio": {
    "sid": "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "token": "your_auth_token_here",
    "number": "+15551234567"
  }
}
```

#### Local Development Configuration
For local testing with Firebase Emulators:

```bash
# Download production config for local use
firebase functions:config:get > .runtimeconfig.json
```

**Note**: Add `.runtimeconfig.json` to `.gitignore` to prevent committing secrets.

---

## Deployment

### Full Deployment (All Functions)
```bash
cd functions
npm run build
firebase deploy --only functions
```

### Deploy Specific Function
```bash
firebase deploy --only functions:autoAssignRide
firebase deploy --only functions:notifyDDNewRide
firebase deploy --only functions:yearTransition
```

### Deploy Multiple Functions
```bash
firebase deploy --only functions:autoAssignRide,functions:notifyDDNewRide
```

### Deploy with Preview
```bash
firebase deploy --only functions --preview
```

### Deployment Checklist
- [ ] All tests passing (`npm test`)
- [ ] TypeScript builds without errors (`npm run build`)
- [ ] Twilio config set in Firebase
- [ ] Firestore indexes created (see below)
- [ ] Security rules deployed
- [ ] Code reviewed and approved
- [ ] Backup/rollback plan prepared

---

## Firestore Indexes

### Required Indexes

Cloud Functions require these composite indexes for efficient queries:

#### Index 1: Rides by Event, Status, and Priority
```json
{
  "collectionGroup": "rides",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "eventId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "priority", "order": "DESCENDING" }
  ]
}
```

#### Index 2: Rides by Event, DD, and Status
```json
{
  "collectionGroup": "rides",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "eventId", "order": "ASCENDING" },
    { "fieldPath": "ddId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" }
  ]
}
```

#### Index 3: DD Assignments by Event and Activity
```json
{
  "collectionGroup": "ddAssignments",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" }
  ]
}
```

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

**Note**: Index creation can take several minutes. Functions may fail until indexes are ready.

---

## Testing

### Local Testing with Emulators

#### Start Emulators
```bash
cd functions
npm run build
cd ..
firebase emulators:start --only functions,firestore,auth
```

#### Test Individual Function
```bash
# In separate terminal
firebase functions:shell

# Inside shell
autoAssignRide({ rideId: "test123" })
```

### Unit Testing
```bash
cd functions
npm test
```

### Integration Testing

Create test documents in Firestore and verify function execution:

1. Start emulators
2. Create test ride document
3. Check function logs
4. Verify expected updates

### Manual Testing Checklist

#### Ride Assignment
- [ ] Create ride with status "queued"
- [ ] Verify DD assigned automatically
- [ ] Check ride status updated to "assigned"
- [ ] Verify DD with shortest wait time selected

#### SMS Notifications
- [ ] Verify DD receives SMS on ride assignment
- [ ] Verify rider receives SMS when DD en route
- [ ] Check SMS content is correct
- [ ] Verify no SMS sent for non-trigger status changes

#### Year Transition
- [ ] Test with sample data
- [ ] Verify seniors removed
- [ ] Verify others advanced
- [ ] Check transition log created

#### DD Monitoring
- [ ] Toggle DD inactive multiple times
- [ ] Verify alert created after 5 toggles
- [ ] Keep DD inactive for 15+ minutes
- [ ] Verify prolonged inactivity alert

#### Emergency Handling
- [ ] Create ride with isEmergency: true
- [ ] Verify priority set to 9999
- [ ] Check admin alert created
- [ ] Verify alert message format

---

## Monitoring

### View Function Logs
```bash
# All function logs
firebase functions:log

# Last 50 entries
firebase functions:log --limit 50

# Only errors
firebase functions:log --only-errors

# Specific function
firebase functions:log --only autoAssignRide

# Follow logs in real-time
firebase functions:log --follow
```

### Firebase Console

1. Navigate to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Functions** section
4. View:
   - Function execution count
   - Error rate
   - Execution time
   - Memory usage

### Key Metrics to Monitor

- **Invocations**: How often each function runs
- **Error Rate**: Should be < 1%
- **Execution Time**: Should be under 10s for most functions
- **Memory Usage**: Should not exceed configured limits
- **Cold Starts**: Initial function invocations (slower)

### Alerts

Set up alerts in Firebase Console for:
- High error rates (> 5%)
- Function timeout
- Memory limit exceeded
- Twilio API failures

---

## Rollback

### View Deployment History
```bash
firebase functions:list
```

### Rollback to Previous Version

Unfortunately, Firebase doesn't support automatic rollback. To revert:

1. **Git Revert**
   ```bash
   git revert HEAD
   git push
   firebase deploy --only functions
   ```

2. **Deploy Previous Git Commit**
   ```bash
   git checkout <previous-commit-hash>
   cd functions
   npm install
   npm run build
   cd ..
   firebase deploy --only functions
   git checkout main
   ```

3. **Emergency: Delete Broken Function**
   ```bash
   firebase functions:delete autoAssignRide
   # Then redeploy working version
   ```

### Rollback Checklist
- [ ] Identify broken function(s)
- [ ] Check git history for last working commit
- [ ] Test locally with emulators
- [ ] Deploy previous version
- [ ] Verify functionality restored
- [ ] Monitor logs for errors
- [ ] Document incident

---

## Cost Management

### Function Costs

Firebase Functions pricing (as of 2024):
- **Invocations**: $0.40 per million (first 2M free)
- **Compute Time**: ~$0.0000025 per GB-second
- **Networking**: $0.12 per GB (first 5GB free)

### Twilio SMS Costs
- ~$0.0079 per SMS sent
- Budget approximately:
  - 10 rides/event = ~$0.16 (2 SMS per ride)
  - 100 rides/month = ~$1.60
  - 1000 rides/month = ~$16.00

### Cost Optimization

1. **Reduce Invocations**
   - Use `onDocumentUpdated` instead of `onDocumentWritten`
   - Check conditions early and return
   - Batch operations when possible

2. **Optimize Memory**
   - Use minimum required memory (256MiB default)
   - Only increase if timeouts occur

3. **Reduce Execution Time**
   - Fetch only required fields
   - Use batch operations
   - Cache frequently accessed data

4. **Monitor Usage**
   ```bash
   # View function metrics
   firebase functions:log --limit 100
   ```

5. **Set Budget Alerts**
   - Go to Firebase Console > Usage & Billing
   - Set daily budget alert
   - Recommended: $10-20/month for testing

### Monthly Cost Estimate

For a single chapter with 50 active members:
- **Functions**: $0 (free tier)
- **Twilio SMS**: $10-15
- **Firestore reads/writes**: $5-10
- **Total**: ~$15-25/month

---

## Troubleshooting

### Common Issues

#### 1. Function Not Triggering

**Symptoms**: Function deployed but not executing

**Solutions**:
```bash
# Check if function exists
firebase functions:list

# Check function logs
firebase functions:log --only functionName

# Verify trigger path matches collection structure
# Example: "rides/{rideId}" not "ride/{rideId}"
```

#### 2. Twilio Configuration Error

**Symptoms**: "Twilio credentials not configured" error

**Solutions**:
```bash
# Verify config
firebase functions:config:get

# Reset config
firebase functions:config:set twilio.sid="..." twilio.token="..." twilio.number="..."

# Redeploy
firebase deploy --only functions
```

#### 3. Index Not Found Error

**Symptoms**: "The query requires an index" error

**Solutions**:
```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Wait 5-10 minutes for indexes to build

# Check index status in Firebase Console
```

#### 4. Function Timeout

**Symptoms**: Function exceeds 60 second limit

**Solutions**:
- Optimize queries (use indexes)
- Reduce batch sizes
- Increase timeout in function config:
  ```typescript
  export const myFunction = onDocumentCreated({
    timeoutSeconds: 120, // Increase from default 60s
    ...
  })
  ```

#### 5. Memory Limit Exceeded

**Symptoms**: Function crashes with out-of-memory error

**Solutions**:
```typescript
export const myFunction = onDocumentCreated({
  memory: "512MiB", // Increase from default 256MiB
  ...
})
```

#### 6. SMS Not Sending

**Symptoms**: No SMS received by users

**Check**:
```bash
# Function logs
firebase functions:log --only notifyDDNewRide

# Twilio logs at https://console.twilio.com

# Verify phone numbers are E.164 format (+15551234567)
```

---

## Scheduled Function Testing

### Test Year Transition Locally

Since `yearTransition` runs once per year, test manually:

```bash
# Start emulators
firebase emulators:start

# In another terminal, use functions shell
firebase functions:shell

# Manually invoke
yearTransition()
```

### Simulate Scheduled Execution

Create a test trigger:
```typescript
// In functions/src/index.ts (temporary)
import {onRequest} from "firebase-functions/v2/https";

export const testYearTransition = onRequest(async (req, res) => {
  // Import and execute year transition logic
  // Remove after testing
});
```

---

## Security Best Practices

1. **Never commit secrets**
   - Add `.runtimeconfig.json` to `.gitignore`
   - Use Firebase config for credentials

2. **Validate inputs**
   - Check document data before processing
   - Validate phone numbers with E.164 regex

3. **Limit function access**
   - Use security rules to control who can trigger functions
   - Validate user authentication in callable functions

4. **Monitor for abuse**
   - Set up alerts for unusual activity
   - Rate limit expensive operations

5. **Use least privilege**
   - Functions should only access required collections
   - Limit service account permissions

---

## Maintenance Schedule

### Daily
- Check error logs
- Monitor SMS delivery rate

### Weekly
- Review function metrics
- Check cost usage
- Update dependencies if needed

### Monthly
- Review and optimize slow functions
- Update documentation
- Security audit

### Annually
- Test year transition function (July)
- Review Twilio costs and optimize
- Update Firebase Functions runtime version

---

## Support Resources

- **Firebase Functions Docs**: https://firebase.google.com/docs/functions
- **Twilio Docs**: https://www.twilio.com/docs
- **Firebase Console**: https://console.firebase.google.com
- **Firebase Status**: https://status.firebase.google.com

---

## Quick Reference

### Essential Commands
```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:functionName

# View logs
firebase functions:log

# View config
firebase functions:config:get

# Start emulators
firebase emulators:start

# Build TypeScript
cd functions && npm run build
```

### Emergency Contacts
- Firebase Support: https://firebase.google.com/support
- Twilio Support: https://support.twilio.com
- K-State IT: (Add contact info)

---

**Last Updated**: January 2026
**Maintained by**: DD Ride App Development Team

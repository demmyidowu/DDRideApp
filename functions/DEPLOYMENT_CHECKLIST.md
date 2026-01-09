# Firebase Cloud Functions - Deployment Checklist

Use this checklist to ensure a smooth deployment of all Cloud Functions.

## Pre-Deployment Checklist

### 1. Environment Setup
- [ ] Node.js v24 installed (check: `node --version`)
- [ ] Firebase CLI installed (check: `firebase --version`)
- [ ] Logged into Firebase (check: `firebase login`)
- [ ] Correct Firebase project selected (check: `firebase use`)

### 2. Twilio Configuration
- [ ] Twilio account created at https://console.twilio.com
- [ ] Twilio Account SID obtained (starts with AC...)
- [ ] Twilio Auth Token obtained
- [ ] Twilio phone number purchased (E.164 format: +1234567890)
- [ ] Twilio credentials tested via Twilio Console

### 3. Code Preparation
- [ ] All dependencies installed (`cd functions && npm install`)
- [ ] TypeScript builds without errors (`npm run build`)
- [ ] No TypeScript errors in console
- [ ] Git status clean or changes committed
- [ ] Code reviewed (if working in team)

### 4. Configuration Files
- [ ] `.gitignore` includes `.env` and `.runtimeconfig.json`
- [ ] `.env.template` exists for reference
- [ ] No secrets committed to git (check with `git log --all -p | grep -i "twilio"`)

## Deployment Steps

### Step 1: Set Twilio Secrets
```bash
# Option A: Firebase Secrets (Recommended for v2)
firebase functions:secrets:set TWILIO_ACCOUNT_SID
# Enter your Account SID when prompted

firebase functions:secrets:set TWILIO_AUTH_TOKEN
# Enter your Auth Token when prompted

firebase functions:secrets:set TWILIO_PHONE_NUMBER
# Enter your phone number when prompted (E.164 format)

# Verify secrets are set
firebase functions:secrets:list
```

**Checklist:**
- [ ] TWILIO_ACCOUNT_SID secret set
- [ ] TWILIO_AUTH_TOKEN secret set
- [ ] TWILIO_PHONE_NUMBER secret set
- [ ] Secrets verified with `firebase functions:secrets:list`

### Step 2: Build Functions
```bash
cd functions
npm run build
```

**Checklist:**
- [ ] Build completes without errors
- [ ] `lib/` directory created with .js files
- [ ] No TypeScript errors shown

### Step 3: Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# OR deploy specific function for testing
firebase deploy --only functions:autoAssignRide
```

**Checklist:**
- [ ] Deployment starts without errors
- [ ] All 8 functions deployed successfully:
  - [ ] autoAssignRide
  - [ ] notifyDDNewRide
  - [ ] notifyRiderEnRoute
  - [ ] incrementDDRideCount
  - [ ] yearTransition
  - [ ] monitorDDActivity
  - [ ] handleEmergencyRide
  - [ ] monitorEmergencyRideStatus
- [ ] No deployment errors in console
- [ ] Deployment URL shows in console

### Step 4: Deploy Firestore Indexes
```bash
# From project root
firebase deploy --only firestore:indexes
```

**Checklist:**
- [ ] Indexes deployment initiated
- [ ] No errors during index deployment
- [ ] Wait 5-10 minutes for indexes to build

### Step 5: Verify Deployment
```bash
# List deployed functions
firebase functions:list

# Check function logs
firebase functions:log --limit 10
```

**Checklist:**
- [ ] All 8 functions appear in list
- [ ] Functions show correct region (us-central1)
- [ ] No errors in recent logs
- [ ] Functions show "healthy" status in Firebase Console

## Post-Deployment Testing

### Test 1: Function Logs
```bash
firebase functions:log --follow
```
- [ ] Logs are streaming correctly
- [ ] No error messages appearing

### Test 2: Ride Assignment
Create a test ride in Firestore:
```json
{
  "riderId": "test_user_1",
  "riderName": "Test Rider",
  "riderPhoneNumber": "+15551234567",
  "eventId": "test_event_1",
  "pickupAddress": "123 Test St, Manhattan, KS",
  "pickupLocation": {
    "_latitude": 39.183,
    "_longitude": -96.572
  },
  "status": "queued",
  "isEmergency": false,
  "priority": 0,
  "requestTime": "2026-01-09T12:00:00Z"
}
```

**Expected Result:**
- [ ] `autoAssignRide` function triggers
- [ ] Ride status changes to "assigned"
- [ ] DD assigned to ride
- [ ] No errors in function logs

### Test 3: SMS Notification (Optional - uses real SMS credits)
Update test ride status:
```json
{
  "status": "assigned"
}
```

**Expected Result:**
- [ ] `notifyDDNewRide` triggers
- [ ] SMS sent to DD phone number
- [ ] SMS delivery confirmed in Twilio logs
- [ ] Function logs show "SMS sent successfully"

**Note**: This uses real SMS credits (~$0.0079 per message)

### Test 4: Emergency Ride
Create emergency test ride:
```json
{
  "riderId": "test_user_2",
  "riderName": "Emergency Test",
  "riderPhoneNumber": "+15559876543",
  "eventId": "test_event_1",
  "pickupAddress": "456 Emergency Ave",
  "status": "queued",
  "isEmergency": true,
  "emergencyReason": "Test emergency",
  "priority": 0,
  "requestTime": "2026-01-09T12:00:00Z"
}
```

**Expected Result:**
- [ ] `handleEmergencyRide` triggers
- [ ] Priority set to 9999
- [ ] Admin alert created in `adminAlerts` collection
- [ ] No errors in logs

### Test 5: Check Firestore Indexes
1. Go to Firebase Console
2. Navigate to Firestore > Indexes
3. Check index status

**Checklist:**
- [ ] All indexes show "Enabled" status (green)
- [ ] No indexes show "Building" or "Error" status
- [ ] If still building, wait and check again in 5-10 minutes

## Monitoring Setup

### Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to Functions

**Setup:**
- [ ] Check function invocation counts
- [ ] Verify error rate is 0%
- [ ] Check execution times (should be < 10s)
- [ ] Set up email alerts for errors

### Budget Alerts
1. Go to Firebase Console > Usage & Billing
2. Set up budget alert

**Recommended:**
- [ ] Daily budget alert: $5
- [ ] Monthly budget alert: $50
- [ ] Alert recipients configured

### Twilio Dashboard
1. Go to https://console.twilio.com
2. Check Messaging > Logs

**Verify:**
- [ ] Test SMS appears in logs
- [ ] Delivery status is "delivered"
- [ ] No error messages

## Troubleshooting

### If Functions Not Deploying
```bash
# Check Firebase login
firebase login --reauth

# Verify project
firebase use

# Check for build errors
cd functions
npm run build

# Clear cache and retry
rm -rf node_modules lib
npm install
npm run build
firebase deploy --only functions
```

### If SMS Not Sending
```bash
# Check secrets are set
firebase functions:secrets:list

# Check Twilio credentials in Twilio Console
# Verify phone number is verified in Twilio

# Check function logs
firebase functions:log --only notifyDDNewRide
```

### If Functions Timing Out
- Check Firestore indexes are all "Enabled"
- Increase function timeout (see DEPLOYMENT.md)
- Optimize queries (see performance section in README.md)

### If Indexes Not Building
- Wait 10-15 minutes (index creation can be slow)
- Check Firebase Status: https://status.firebase.google.com
- Try redeploying: `firebase deploy --only firestore:indexes`

## Rollback Plan

If deployment fails or causes issues:

### Option 1: Redeploy Previous Version
```bash
# Checkout previous git commit
git log --oneline
git checkout <previous-commit-hash>

# Redeploy
cd functions
npm install
npm run build
firebase deploy --only functions

# Return to main branch
git checkout main
```

### Option 2: Delete Broken Function
```bash
# Delete specific function
firebase functions:delete functionName

# Redeploy fixed version
firebase deploy --only functions:functionName
```

## Success Criteria

Deployment is successful when:
- [ ] All 8 functions deployed without errors
- [ ] All Firestore indexes show "Enabled" status
- [ ] Test ride assignment works correctly
- [ ] Function logs show no errors
- [ ] SMS test sends successfully (if tested)
- [ ] Emergency ride creates admin alert
- [ ] Firebase Console shows healthy function status
- [ ] Budget alerts configured
- [ ] Team notified of successful deployment

## Post-Deployment

### Immediate (Within 24 hours)
- [ ] Monitor function logs for errors
- [ ] Check function invocation counts
- [ ] Verify SMS delivery rate
- [ ] Review Twilio costs
- [ ] Document any issues encountered

### Weekly
- [ ] Review function performance metrics
- [ ] Check error rates
- [ ] Review SMS costs
- [ ] Optimize slow functions if needed

### Monthly
- [ ] Review total costs (Firebase + Twilio)
- [ ] Update dependencies if needed
- [ ] Review and update documentation
- [ ] Plan for year transition testing (if approaching August)

## Emergency Contacts

**Firebase Support**: https://firebase.google.com/support
**Twilio Support**: https://support.twilio.com
**Firebase Status**: https://status.firebase.google.com
**Project Team**: [Add your team contacts]

---

## Deployment Sign-Off

**Deployed By**: _________________
**Date**: _________________
**Firebase Project**: _________________
**Functions Deployed**: ___ / 8
**Tests Passed**: ___ / 5
**Issues Encountered**: _________________

**Approved By**: _________________
**Date**: _________________

---

**Last Updated**: January 2026
**Version**: 1.0.0

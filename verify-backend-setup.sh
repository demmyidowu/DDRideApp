#!/bin/bash

# Firebase Backend Setup Verification Script
# This script checks that all Firebase backend components are properly configured

echo "🔍 Verifying Firebase Backend Setup..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Function to check file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $2 - Missing: $1"
        ((FAIL++))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $2 - Missing: $1"
        ((FAIL++))
        return 1
    fi
}

# Function to check file contains pattern
check_pattern() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $3"
        ((PASS++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $3 - Pattern not found in $1"
        ((WARN++))
        return 1
    fi
}

echo "📁 Checking Core Files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Firebase config files
check_file "firestore.rules" "Firestore Security Rules"
check_file "firestore.indexes.json" "Firestore Composite Indexes"
check_file "firebase.json" "Firebase Configuration"
check_file ".firebaserc" "Firebase Project Config"

echo ""
echo "📱 Checking iOS Models..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# iOS Models
check_file "ios/DDRide/Core/Models/User.swift" "User Model"
check_file "ios/DDRide/Core/Models/Chapter.swift" "Chapter Model"
check_file "ios/DDRide/Core/Models/Event.swift" "Event Model"
check_file "ios/DDRide/Core/Models/DDAssignment.swift" "DD Assignment Model"
check_file "ios/DDRide/Core/Models/Ride.swift" "Ride Model"
check_file "ios/DDRide/Core/Models/AdminAlert.swift" "Admin Alert Model"
check_file "ios/DDRide/Core/Models/YearTransitionLog.swift" "Year Transition Log Model"

echo ""
echo "⚙️  Checking iOS Services..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# iOS Services
check_file "ios/DDRide/Core/Services/FirebaseService.swift" "Firebase Service"
check_file "ios/DDRide/Core/Services/AuthService.swift" "Auth Service"
check_file "ios/DDRide/Core/Services/LocationService.swift" "Location Service"
check_file "ios/DDRide/Core/Services/NotificationService.swift" "Notification Service"

echo ""
echo "🔐 Checking Security Rules..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Security rules checks
check_pattern "firestore.rules" "isKSUEmail" "KSU Email Validation"
check_pattern "firestore.rules" "isEmailVerified" "Email Verification Check"
check_pattern "firestore.rules" "isAdmin" "Admin Role Check"
check_pattern "firestore.rules" "isSameChapter" "Chapter Isolation"
check_pattern "firestore.rules" "match /users/{userId}" "Users Collection Rules"
check_pattern "firestore.rules" "match /chapters/{chapterId}" "Chapters Collection Rules"
check_pattern "firestore.rules" "match /events/{eventId}" "Events Collection Rules"
check_pattern "firestore.rules" "match /rides/{rideId}" "Rides Collection Rules"
check_pattern "firestore.rules" "match /ddAssignments/{assignmentId}" "DD Assignments Rules"

echo ""
echo "📊 Checking Composite Indexes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Index checks
check_pattern "firestore.indexes.json" "eventId" "Event ID Index"
check_pattern "firestore.indexes.json" "priority" "Priority Index"
check_pattern "firestore.indexes.json" "status" "Status Index"
check_pattern "firestore.indexes.json" "ddAssignments" "DD Assignments Index"
check_pattern "firestore.indexes.json" "isActive" "Active Status Index"
check_pattern "firestore.indexes.json" "totalRidesCompleted" "Rides Completed Index"

echo ""
echo "🔧 Checking iOS Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# iOS app configuration
check_pattern "ios/DDRide/DDRideApp.swift" "FirebaseApp.configure" "Firebase Initialization"
check_pattern "ios/DDRide/DDRideApp.swift" "FirebaseService.shared" "Firebase Service Init"
check_pattern "ios/DDRide/Core/Services/FirebaseService.swift" "configureEmulators" "Emulator Configuration"
check_pattern "ios/DDRide/Core/Services/FirebaseService.swift" "localhost:8080" "Firestore Emulator"
check_pattern "ios/DDRide/Core/Services/FirebaseService.swift" "localhost:9099" "Auth Emulator"

echo ""
echo "📚 Checking Documentation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Documentation
check_file "FIREBASE_SETUP.md" "Firebase Setup Guide"
check_file "ios/FIREBASE_USAGE.md" "iOS Usage Guide"
check_file "BACKEND_SUMMARY.md" "Backend Summary"
check_file "CLAUDE.md" "Project Instructions"

echo ""
echo "🧪 Checking Cloud Functions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cloud Functions
check_dir "functions" "Functions Directory"
check_file "functions/package.json" "Functions Package Config"
check_file "functions/tsconfig.json" "TypeScript Config"

if [ -f "functions/src/index.ts" ]; then
    echo -e "${GREEN}✓${NC} Functions Source File"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} Functions not yet implemented (expected)"
    ((WARN++))
fi

echo ""
echo "📦 Checking Data Model Completeness..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# User model fields
check_pattern "ios/DDRide/Core/Models/User.swift" "classYear" "User ClassYear Field"
check_pattern "ios/DDRide/Core/Models/User.swift" "isEmailVerified" "User Email Verification"
check_pattern "ios/DDRide/Core/Models/User.swift" "fcmToken" "User FCM Token"
check_pattern "ios/DDRide/Core/Models/User.swift" "@ksu.edu" "KSU Email Comment"

# Chapter model fields
check_pattern "ios/DDRide/Core/Models/Chapter.swift" "yearTransitionDate" "Chapter Year Transition"
check_pattern "ios/DDRide/Core/Models/Chapter.swift" "inviteCode" "Chapter Invite Code"

# Ride model fields
check_pattern "ios/DDRide/Core/Models/Ride.swift" "priority" "Ride Priority"
check_pattern "ios/DDRide/Core/Models/Ride.swift" "isEmergency" "Emergency Flag"
check_pattern "ios/DDRide/Core/Models/Ride.swift" "GeoPoint" "Location GeoPoint"
check_pattern "ios/DDRide/Core/Models/Ride.swift" "estimatedETA" "Estimated ETA"

# DD Assignment fields
check_pattern "ios/DDRide/Core/Models/DDAssignment.swift" "inactiveToggles" "Inactive Toggles"
check_pattern "ios/DDRide/Core/Models/DDAssignment.swift" "totalRidesCompleted" "Total Rides"
check_pattern "ios/DDRide/Core/Models/DDAssignment.swift" "carDescription" "Car Description"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Verification Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓${NC} Passed:   $PASS"
echo -e "${YELLOW}⚠${NC} Warnings: $WARN"
echo -e "${RED}✗${NC} Failed:   $FAIL"
echo ""

# Overall status
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 Backend setup looks good!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Start Firebase emulators: firebase emulators:start"
    echo "  2. Run iOS app in debug mode"
    echo "  3. Implement Cloud Functions (see FIREBASE_SETUP.md)"
    echo "  4. Deploy to production: firebase deploy"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Backend setup has issues that need attention${NC}"
    echo ""
    echo "Please fix the failed checks above before proceeding."
    echo ""
    exit 1
fi

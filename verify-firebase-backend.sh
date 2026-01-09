#!/bin/bash

# Firebase Backend Verification Script for DD Ride App
# This script verifies that all Firebase backend components are properly configured

echo "=========================================="
echo "Firebase Backend Verification for DD Ride"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verification status
ALL_CHECKS_PASSED=true

# Function to check file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2 exists"
        return 0
    else
        echo -e "${RED}✗${NC} $2 missing: $1"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Function to check file contains string
check_file_contains() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $3"
        return 0
    else
        echo -e "${RED}✗${NC} $3 not found in $1"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

echo "1. Checking Firestore Security Rules..."
echo "----------------------------------------"
check_file "firestore.rules" "Security rules file"
check_file_contains "firestore.rules" "isKSUEmail" "KSU email validation function"
check_file_contains "firestore.rules" "isEmailVerified" "Email verification function"
check_file_contains "firestore.rules" "isAdmin" "Admin role check function"
check_file_contains "firestore.rules" "match /users" "Users collection rules"
check_file_contains "firestore.rules" "match /chapters" "Chapters collection rules"
check_file_contains "firestore.rules" "match /events" "Events collection rules"
check_file_contains "firestore.rules" "match /rides" "Rides collection rules"
check_file_contains "firestore.rules" "match /adminAlerts" "Admin alerts collection rules"
check_file_contains "firestore.rules" "match /yearTransitionLogs" "Year transition logs collection rules"
echo ""

echo "2. Checking Firestore Indexes..."
echo "----------------------------------------"
check_file "firestore.indexes.json" "Firestore indexes file"
check_file_contains "firestore.indexes.json" "\"collectionGroup\": \"rides\"" "Rides collection index"
check_file_contains "firestore.indexes.json" "\"collectionGroup\": \"ddAssignments\"" "DD assignments index"
check_file_contains "firestore.indexes.json" "\"collectionGroup\": \"events\"" "Events collection index"
check_file_contains "firestore.indexes.json" "\"collectionGroup\": \"users\"" "Users collection index"
check_file_contains "firestore.indexes.json" "\"collectionGroup\": \"adminAlerts\"" "Admin alerts index"
echo ""

echo "3. Checking Swift Models..."
echo "----------------------------------------"
check_file "ios/DDRide/Core/Models/User.swift" "User model"
check_file "ios/DDRide/Core/Models/Chapter.swift" "Chapter model"
check_file "ios/DDRide/Core/Models/Event.swift" "Event model"
check_file "ios/DDRide/Core/Models/Ride.swift" "Ride model"
check_file "ios/DDRide/Core/Models/DDAssignment.swift" "DDAssignment model"
check_file "ios/DDRide/Core/Models/AdminAlert.swift" "AdminAlert model"
check_file "ios/DDRide/Core/Models/YearTransitionLog.swift" "YearTransitionLog model"
echo ""

echo "4. Checking Firebase Services..."
echo "----------------------------------------"
check_file "ios/DDRide/Core/Services/FirebaseService.swift" "FirebaseService"
check_file_contains "ios/DDRide/Core/Services/FirebaseService.swift" "configureEmulators" "Emulator configuration"
check_file_contains "ios/DDRide/Core/Services/FirebaseService.swift" "usersCollection" "Users collection reference"
check_file_contains "ios/DDRide/Core/Services/FirebaseService.swift" "eventsCollection" "Events collection reference"
check_file_contains "ios/DDRide/Core/Services/FirebaseService.swift" "ridesCollection" "Rides collection reference"
check_file_contains "ios/DDRide/Core/Services/FirebaseService.swift" "ddAssignmentsCollection" "DD assignments collection reference"
check_file_contains "ios/DDRide/Core/Services/FirebaseService.swift" "listenToActiveRides" "Real-time listener for rides"
echo ""

echo "5. Checking AuthService..."
echo "----------------------------------------"
check_file "ios/DDRide/Core/Services/AuthService.swift" "AuthService"
check_file_contains "ios/DDRide/Core/Services/AuthService.swift" "@ksu.edu" "KSU email validation"
check_file_contains "ios/DDRide/Core/Services/AuthService.swift" "signIn" "Sign in method"
check_file_contains "ios/DDRide/Core/Services/AuthService.swift" "signUp" "Sign up method"
check_file_contains "ios/DDRide/Core/Services/AuthService.swift" "signOut" "Sign out method"
check_file_contains "ios/DDRide/Core/Services/AuthService.swift" "refreshEmailVerification" "Email verification refresh method"
echo ""

echo "6. Checking App Initialization..."
echo "----------------------------------------"
check_file "ios/DDRide/DDRideApp.swift" "DDRideApp"
check_file_contains "ios/DDRide/DDRideApp.swift" "FirebaseApp.configure" "Firebase initialization"
check_file_contains "ios/DDRide/DDRideApp.swift" "FirebaseService.shared" "FirebaseService initialization"
check_file_contains "ios/DDRide/DDRideApp.swift" "AuthService.shared" "AuthService initialization"
echo ""

echo "7. Checking Documentation..."
echo "----------------------------------------"
check_file "FIREBASE_BACKEND_SETUP.md" "Firebase backend setup documentation"
check_file "CLAUDE.md" "Project instructions"
echo ""

# Summary
echo "=========================================="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}All checks passed! ✓${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run Firebase emulators: firebase emulators:start --only firestore,auth"
    echo "2. Deploy security rules: firebase deploy --only firestore:rules"
    echo "3. Deploy indexes: firebase deploy --only firestore:indexes"
    echo "4. Build the iOS app and test authentication flow"
    exit 0
else
    echo -e "${RED}Some checks failed. Please review the output above.${NC}"
    exit 1
fi

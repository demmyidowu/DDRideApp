/**
 * Firebase Cloud Functions for DD Ride App
 *
 * This file exports all Cloud Functions for the DD Ride application.
 * Functions are organized by responsibility:
 *
 * 1. Ride Management (rideAssignment.ts)
 *    - autoAssignRide: Automatically assign rides to DDs with shortest wait time
 *
 * 2. SMS Notifications (smsNotifications.ts)
 *    - notifyDDNewRide: Send SMS to DD when ride is assigned
 *    - notifyRiderEnRoute: Send SMS to rider when DD is en route
 *    - incrementDDRideCount: Update DD ride count on completion
 *
 * 3. Scheduled Tasks (yearTransition.ts)
 *    - yearTransition: Annual class year transition (August 1st)
 *
 * 4. Activity Monitoring (ddMonitoring.ts)
 *    - monitorDDActivity: Monitor DD inactive toggles and prolonged inactivity
 *
 * 5. Emergency Handling (emergencyHandler.ts)
 *    - handleEmergencyRide: Process emergency ride requests
 *    - monitorEmergencyRideStatus: Alert if emergency ride unassigned too long
 *
 * @see https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions/v2";

// Set global options for all functions
setGlobalOptions({
  maxInstances: 10, // Cost control
  region: "us-central1", // Central US region for K-State
});

// ============================================================================
// RIDE MANAGEMENT
// ============================================================================

/**
 * Automatically assigns new rides to the DD with the shortest wait time
 * Trigger: onCreate rides/{rideId}
 */
export {autoAssignRide} from "./rideAssignment";

// ============================================================================
// SMS NOTIFICATIONS
// ============================================================================

/**
 * Sends SMS to DD when a new ride is assigned
 * Trigger: onUpdate rides/{rideId} (queued -> assigned)
 */
export {notifyDDNewRide} from "./smsNotifications";

/**
 * Sends SMS to rider when DD marks en route
 * Trigger: onUpdate rides/{rideId} (assigned -> enroute)
 */
export {notifyRiderEnRoute} from "./smsNotifications";

/**
 * Increments DD's totalRidesCompleted counter when ride is completed
 * Trigger: onUpdate rides/{rideId} (any -> completed)
 */
export {incrementDDRideCount} from "./smsNotifications";

// ============================================================================
// SCHEDULED TASKS
// ============================================================================

/**
 * Annual year transition function
 * Schedule: August 1st at midnight (America/Chicago)
 * Actions:
 * - Removes all seniors (classYear === 4)
 * - Advances all other members (classYear += 1)
 * - Creates audit log
 * - Notifies admins
 */
export {yearTransition} from "./yearTransition";

// ============================================================================
// ACTIVITY MONITORING
// ============================================================================

/**
 * Monitors DD activity patterns and creates alerts
 * Trigger: onUpdate events/{eventId}/ddAssignments/{ddId}
 * Checks:
 * - Excessive inactive toggles (>5)
 * - Prolonged inactivity (>15 minutes)
 * - Auto-resets toggle counter after 30 minutes
 */
export {monitorDDActivity} from "./ddMonitoring";

// ============================================================================
// EMERGENCY HANDLING
// ============================================================================

/**
 * Handles emergency ride requests
 * Trigger: onCreate rides/{rideId} where isEmergency === true
 * Actions:
 * - Sets priority to 9999
 * - Creates admin alert
 * - Notifies chapter admins (TODO: push notifications)
 */
export {handleEmergencyRide} from "./emergencyHandler";

/**
 * Monitors emergency ride assignment status
 * Trigger: onCreate rides/{rideId} where isEmergency === true
 * Waits 2 minutes, then alerts if still unassigned
 */
export {monitorEmergencyRideStatus} from "./emergencyHandler";

// ============================================================================
// UTILITY EXPORTS
// ============================================================================

// Export utility functions for testing purposes
export * as validation from "./utils/validation";

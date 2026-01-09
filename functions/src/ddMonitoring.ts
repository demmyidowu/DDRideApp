/**
 * DD Activity Monitoring Functions
 *
 * Monitors DD activity patterns and creates alerts for:
 * - Excessive inactive toggles (>5 in 30 minutes)
 * - Prolonged inactivity (>15 minutes during active shift)
 */

import * as logger from "firebase-functions/logger";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";

// Initialize Firebase Admin
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

/**
 * Thresholds for monitoring
 */
const INACTIVE_TOGGLE_THRESHOLD = 5; // Alert if more than 5 toggles
const PROLONGED_INACTIVE_MINUTES = 15; // Alert if inactive for 15+ minutes
const TOGGLE_RESET_WINDOW_MINUTES = 30; // Reset counter after 30 minutes

/**
 * Create an admin alert
 *
 * @param data - Alert data
 */
async function createAdminAlert(data: {
  chapterId: string;
  type: string;
  message: string;
  ddId?: string;
  rideId?: string;
}): Promise<void> {
  try {
    await db.collection("adminAlerts").add({
      ...data,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("Admin alert created", {
      type: data.type,
      chapterId: data.chapterId,
    });
  } catch (error: any) {
    logger.error("Failed to create admin alert", {
      error: error.message,
      data,
    });
    // Don't throw - alert creation failure shouldn't block the function
  }
}

/**
 * Get chapter ID from event ID
 *
 * @param eventId - Event document ID
 * @returns Promise<string | null> - Chapter ID or null if not found
 */
async function getChapterIdFromEvent(eventId: string): Promise<string | null> {
  try {
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      logger.error("Event not found", {eventId});
      return null;
    }
    return eventDoc.data()?.chapterId || null;
  } catch (error: any) {
    logger.error("Error fetching event", {eventId, error: error.message});
    return null;
  }
}

/**
 * Get DD user name
 *
 * @param ddId - User document ID
 * @returns Promise<string> - DD name or "Unknown"
 */
async function getDDName(ddId: string): Promise<string> {
  try {
    const userDoc = await db.collection("users").doc(ddId).get();
    if (!userDoc.exists) {
      logger.error("DD user not found", {ddId});
      return "Unknown";
    }
    return userDoc.data()?.name || "Unknown";
  } catch (error: any) {
    logger.error("Error fetching DD user", {ddId, error: error.message});
    return "Unknown";
  }
}

/**
 * Check if event is currently active
 *
 * @param eventId - Event document ID
 * @returns Promise<boolean> - true if event is active
 */
async function isEventActive(eventId: string): Promise<boolean> {
  try {
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      return false;
    }
    return eventDoc.data()?.status === "active";
  } catch (error: any) {
    logger.error("Error checking event status", {
      eventId,
      error: error.message,
    });
    return false;
  }
}

/**
 * Monitor DD activity patterns and create alerts
 *
 * Triggered when a DD assignment document is updated
 * Monitors for:
 * 1. Excessive inactive toggles
 * 2. Prolonged inactivity during shifts
 */
export const monitorDDActivity = onDocumentUpdated(
  {
    document: "events/{eventId}/ddAssignments/{ddId}",
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const ddId = event.params.ddId;
    const eventId = event.params.eventId;

    if (!before || !after) {
      logger.error("Missing assignment data", {ddId, eventId});
      return;
    }

    logger.info("DD activity monitor triggered", {
      ddId,
      eventId,
      wasActive: before.isActive,
      nowActive: after.isActive,
    });

    try {
      const chapterId = await getChapterIdFromEvent(eventId);
      if (!chapterId) {
        logger.error("Could not determine chapter ID", {eventId});
        return;
      }

      // Check 1: Monitor inactive toggles
      await checkInactiveToggleAbuse(
        ddId,
        eventId,
        chapterId,
        before,
        after
      );

      // Check 2: Monitor prolonged inactivity
      await checkProlongedInactivity(
        ddId,
        eventId,
        chapterId,
        after
      );

      // Check 3: Auto-reset toggle counter if enough time has passed
      await autoResetToggleCounter(
        ddId,
        eventId,
        after
      );
    } catch (error: any) {
      logger.error("Error in DD activity monitoring", {
        ddId,
        eventId,
        error: error.message,
        stack: error.stack,
      });
      // Don't throw - monitoring failure shouldn't block other operations
    }
  }
);

/**
 * Check for excessive inactive toggles and create alert
 */
async function checkInactiveToggleAbuse(
  ddId: string,
  eventId: string,
  chapterId: string,
  before: any,
  after: any
): Promise<void> {
  // Check if DD just toggled to inactive
  if (!before.isActive || after.isActive) {
    return; // Only check on toggle to inactive
  }

  const toggleCount = after.inactiveToggles || 0;

  logger.info("DD toggled inactive", {
    ddId,
    eventId,
    toggleCount,
  });

  // Alert if toggle count exceeds threshold
  if (toggleCount > INACTIVE_TOGGLE_THRESHOLD) {
    const ddName = await getDDName(ddId);

    await createAdminAlert({
      chapterId,
      type: "dd_inactive",
      message:
        `${ddName} has toggled inactive ${toggleCount} times. ` +
        `This may indicate an issue.`,
      ddId,
    });

    logger.warn("Excessive inactive toggles detected", {
      ddId,
      ddName,
      toggleCount,
      threshold: INACTIVE_TOGGLE_THRESHOLD,
    });
  }
}

/**
 * Check for prolonged inactivity during shift
 */
async function checkProlongedInactivity(
  ddId: string,
  eventId: string,
  chapterId: string,
  assignment: any
): Promise<void> {
  // Only check if DD is currently inactive
  if (assignment.isActive) {
    return;
  }

  // Check if event is still active
  const eventActive = await isEventActive(eventId);
  if (!eventActive) {
    return; // Don't alert if event has ended
  }

  // Check last inactive timestamp
  const lastInactiveTimestamp = assignment.lastInactiveTimestamp;
  if (!lastInactiveTimestamp) {
    return; // No timestamp to check
  }

  // Calculate inactive duration
  const now = Date.now();
  const lastInactiveMs = lastInactiveTimestamp.toMillis ?
    lastInactiveTimestamp.toMillis() :
    (lastInactiveTimestamp as Timestamp).toMillis();
  const inactiveMinutes = (now - lastInactiveMs) / 60000;

  logger.info("Checking prolonged inactivity", {
    ddId,
    eventId,
    inactiveMinutes: Math.round(inactiveMinutes),
  });

  // Alert if inactive for too long
  if (inactiveMinutes > PROLONGED_INACTIVE_MINUTES) {
    // Check if we've already alerted recently (avoid spam)
    const lastAlertCheck = assignment.lastInactivityAlertTime;
    if (lastAlertCheck) {
      const lastAlertMs = lastAlertCheck.toMillis ?
        lastAlertCheck.toMillis() :
        (lastAlertCheck as Timestamp).toMillis();
      const minutesSinceLastAlert = (now - lastAlertMs) / 60000;

      // Only alert once per 30 minutes
      if (minutesSinceLastAlert < 30) {
        return;
      }
    }

    const ddName = await getDDName(ddId);

    await createAdminAlert({
      chapterId,
      type: "dd_inactive",
      message:
        `${ddName} has been inactive for ${Math.round(inactiveMinutes)} ` +
        `minutes during active shift.`,
      ddId,
    });

    // Update last alert time
    await db
      .collection("events")
      .doc(eventId)
      .collection("ddAssignments")
      .doc(ddId)
      .update({
        lastInactivityAlertTime: FieldValue.serverTimestamp(),
      });

    logger.warn("Prolonged inactivity detected", {
      ddId,
      ddName,
      inactiveMinutes: Math.round(inactiveMinutes),
    });

    // TODO: Send push notification to DD
    // Placeholder for future FCM implementation
  }
}

/**
 * Auto-reset toggle counter if enough time has passed
 */
async function autoResetToggleCounter(
  ddId: string,
  eventId: string,
  assignment: any
): Promise<void> {
  const toggleCount = assignment.inactiveToggles || 0;
  const lastToggleTimestamp = assignment.lastInactiveTimestamp;

  // Only reset if there are toggles to reset
  if (toggleCount === 0 || !lastToggleTimestamp) {
    return;
  }

  // Check if reset window has passed
  const now = Date.now();
  const lastToggleMs = lastToggleTimestamp.toMillis ?
    lastToggleTimestamp.toMillis() :
    (lastToggleTimestamp as Timestamp).toMillis();
  const minutesSinceLastToggle = (now - lastToggleMs) / 60000;

  if (minutesSinceLastToggle > TOGGLE_RESET_WINDOW_MINUTES) {
    await db
      .collection("events")
      .doc(eventId)
      .collection("ddAssignments")
      .doc(ddId)
      .update({
        inactiveToggles: 0,
      });

    logger.info("Reset DD toggle counter", {
      ddId,
      eventId,
      previousCount: toggleCount,
      minutesSinceLastToggle: Math.round(minutesSinceLastToggle),
    });
  }
}

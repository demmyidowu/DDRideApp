/**
 * Emergency Ride Request Handler
 *
 * Handles emergency ride requests by creating admin alerts and
 * notifying chapter administrators immediately.
 */

import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// Initialize Firebase Admin
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

/**
 * Get chapter ID from event
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
 * Get event name for better alert context
 *
 * @param eventId - Event document ID
 * @returns Promise<string> - Event name or "Unknown Event"
 */
async function getEventName(eventId: string): Promise<string> {
  try {
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      return "Unknown Event";
    }
    return eventDoc.data()?.name || "Unknown Event";
  } catch (error: any) {
    logger.error("Error fetching event name", {eventId, error: error.message});
    return "Unknown Event";
  }
}

/**
 * Format address for display (truncate if too long)
 *
 * @param address - Full address
 * @returns Truncated address
 */
function formatAddress(address: string): string {
  if (!address) return "Unknown location";
  if (address.length <= 50) return address;
  return address.substring(0, 47) + "...";
}

/**
 * Create emergency admin alert
 *
 * @param data - Alert data
 * @returns Promise<void>
 */
async function createEmergencyAlert(data: {
  chapterId: string;
  rideId: string;
  riderName: string;
  pickupAddress: string;
  emergencyReason: string;
  eventName: string;
}): Promise<void> {
  try {
    const message =
      `🚨 EMERGENCY RIDE REQUEST\n` +
      `Event: ${data.eventName}\n` +
      `Rider: ${data.riderName}\n` +
      `Location: ${formatAddress(data.pickupAddress)}\n` +
      `Reason: ${data.emergencyReason}`;

    await db.collection("adminAlerts").add({
      chapterId: data.chapterId,
      type: "emergency_request",
      message,
      rideId: data.rideId,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("Emergency alert created", {
      rideId: data.rideId,
      chapterId: data.chapterId,
    });
  } catch (error: any) {
    logger.error("Failed to create emergency alert", {
      error: error.message,
      rideId: data.rideId,
    });
    throw error; // This should throw since emergency alerts are critical
  }
}

/**
 * Notify chapter admins via push notification (placeholder)
 *
 * @param chapterId - Chapter ID
 * @param rideId - Ride document ID
 * @param riderName - Name of rider requesting emergency pickup
 */
async function notifyChapterAdmins(
  chapterId: string,
  rideId: string,
  riderName: string
): Promise<void> {
  try {
    // Fetch all admins for this chapter
    const adminsSnapshot = await db
      .collection("users")
      .where("chapterId", "==", chapterId)
      .where("role", "==", "admin")
      .get();

    if (adminsSnapshot.empty) {
      logger.warn("No admins found for chapter", {chapterId});
      return;
    }

    logger.info("Found chapter admins for notification", {
      chapterId,
      adminCount: adminsSnapshot.size,
    });

    // TODO: Implement FCM push notifications
    // For now, we just log the intent
    // Future implementation:
    // - Get FCM tokens from admin user documents
    // - Send high-priority push notification
    // - Include ride details and deep link to ride view

    /*
    for (const adminDoc of adminsSnapshot.docs) {
      const admin = adminDoc.data();
      if (admin.fcmToken) {
        await admin.messaging().send({
          token: admin.fcmToken,
          notification: {
            title: '🚨 EMERGENCY RIDE REQUEST',
            body: `${riderName} needs immediate pickup`
          },
          data: {
            rideId,
            type: 'emergency',
            priority: 'high'
          },
          apns: {
            payload: {
              aps: {
                sound: 'emergency.caf',
                badge: 1,
                'content-available': 1
              }
            }
          }
        });
      }
    }
    */

    logger.info("Admin notification placeholder executed", {
      chapterId,
      rideId,
      adminCount: adminsSnapshot.size,
    });
  } catch (error: any) {
    logger.error("Failed to notify admins", {
      chapterId,
      rideId,
      error: error.message,
    });
    // Don't throw - push notification failure shouldn't fail the function
  }
}

/**
 * Set emergency ride to highest priority
 *
 * @param rideRef - Firestore document reference for the ride
 */
async function setPriorityEmergency(rideRef: any): Promise<void> {
  try {
    await rideRef.update({
      priority: 9999, // Emergency rides always have highest priority
    });

    logger.info("Emergency ride priority set", {
      rideId: rideRef.id,
      priority: 9999,
    });
  } catch (error: any) {
    logger.error("Failed to set emergency priority", {
      rideId: rideRef.id,
      error: error.message,
    });
    // Don't throw - priority update failure shouldn't fail the function
  }
}

/**
 * Handle emergency ride requests
 *
 * Triggered when a new ride document is created with isEmergency === true
 * Creates admin alerts and notifies chapter administrators immediately
 */
export const handleEmergencyRide = onDocumentCreated(
  {
    document: "rides/{rideId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error("No data in snapshot");
      return;
    }

    const rideId = event.params.rideId;
    const ride = snapshot.data();

    // Only process emergency rides
    if (!ride.isEmergency) {
      return;
    }

    logger.warn("EMERGENCY RIDE REQUEST DETECTED", {
      rideId,
      riderId: ride.riderId,
      riderName: ride.riderName,
      eventId: ride.eventId,
      emergencyReason: ride.emergencyReason,
    });

    try {
      // Get chapter ID
      const chapterId = await getChapterIdFromEvent(ride.eventId);
      if (!chapterId) {
        logger.error("Could not determine chapter ID for emergency ride", {
          rideId,
          eventId: ride.eventId,
        });
        throw new Error("Could not determine chapter ID");
      }

      // Get event name for context
      const eventName = await getEventName(ride.eventId);

      // Set emergency priority
      await setPriorityEmergency(snapshot.ref);

      // Create emergency alert
      await createEmergencyAlert({
        chapterId,
        rideId,
        riderName: ride.riderName || "Unknown",
        pickupAddress: ride.pickupAddress || "Unknown location",
        emergencyReason: ride.emergencyReason || "No reason provided",
        eventName,
      });

      // Notify chapter admins
      await notifyChapterAdmins(
        chapterId,
        rideId,
        ride.riderName || "Unknown"
      );

      logger.info("Emergency ride processed successfully", {
        rideId,
        chapterId,
        eventName,
      });
    } catch (error: any) {
      logger.error("Emergency ride processing failed", {
        rideId,
        error: error.message,
        stack: error.stack,
      });

      // For emergency rides, we should throw to ensure visibility
      throw error;
    }
  }
);

/**
 * Monitor emergency ride status and alert if not assigned quickly
 *
 * Triggered when an emergency ride is updated
 * Alerts admins if emergency ride remains unassigned for too long
 */
export const monitorEmergencyRideStatus = onDocumentCreated(
  {
    document: "rides/{rideId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const ride = snapshot.data();
    if (!ride.isEmergency) return;

    // Wait 2 minutes then check if still unassigned
    await new Promise((resolve) => setTimeout(resolve, 120000)); // 2 minutes

    try {
      // Re-fetch ride to check current status
      const updatedRide = await snapshot.ref.get();
      const currentRide = updatedRide.data();

      if (!currentRide) return;

      // Check if still queued
      if (currentRide.status === "queued") {
        const chapterId = await getChapterIdFromEvent(currentRide.eventId);
        if (!chapterId) return;

        await db.collection("adminAlerts").add({
          chapterId,
          type: "emergency_request",
          message:
            `⚠️ EMERGENCY RIDE STILL UNASSIGNED\n` +
            `Rider: ${currentRide.riderName}\n` +
            `Location: ${formatAddress(currentRide.pickupAddress)}\n` +
            `Request time: 2+ minutes ago`,
          rideId: snapshot.id,
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });

        logger.warn("Emergency ride still unassigned after 2 minutes", {
          rideId: snapshot.id,
        });
      }
    } catch (error: any) {
      logger.error("Error monitoring emergency ride status", {
        rideId: snapshot.id,
        error: error.message,
      });
      // Don't throw - this is a secondary check
    }
  }
);

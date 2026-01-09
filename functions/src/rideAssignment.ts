/**
 * Ride Assignment Function
 *
 * Automatically assigns rides to designated drivers based on shortest wait time
 * algorithm. Triggered when a new ride is created in Firestore.
 */

import * as logger from "firebase-functions/logger";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// Initialize Firebase Admin (only if not already initialized)
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

/**
 * Interface for DD Assignment data
 */
interface DDAssignment {
  userId: string;
  isActive: boolean;
  totalRidesCompleted: number;
  carDescription?: string;
  photoURL?: string;
}

/**
 * Interface for active ride data (for wait time calculation)
 */
interface ActiveRide {
  ddId: string;
  status: "queued" | "assigned" | "enroute";
  estimatedETA?: number;
}

/**
 * Interface for DD with calculated wait time
 */
interface DDWithWaitTime {
  userId: string;
  waitTime: number; // in minutes
  assignment: DDAssignment;
}

/**
 * Calculate wait time for a specific DD based on their active rides
 *
 * @param ddId - The DD's user ID
 * @param eventId - The event ID
 * @returns Promise<number> - Wait time in minutes
 */
async function calculateDDWaitTime(
  ddId: string,
  eventId: string
): Promise<number> {
  try {
    // Fetch all active rides assigned to this DD
    const activeRidesSnapshot = await db
      .collection("rides")
      .where("eventId", "==", eventId)
      .where("ddId", "==", ddId)
      .where("status", "in", ["assigned", "enroute"])
      .get();

    if (activeRidesSnapshot.empty) {
      return 0; // No active rides, available immediately
    }

    // Calculate total estimated time
    // Each ride without ETA = 15 minutes default
    let totalWaitTime = 0;

    activeRidesSnapshot.forEach((doc) => {
      const ride = doc.data() as ActiveRide;
      totalWaitTime += ride.estimatedETA || 15;
    });

    logger.info("Calculated DD wait time", {
      ddId,
      activeRides: activeRidesSnapshot.size,
      totalWaitTime,
    });

    return totalWaitTime;
  } catch (error: any) {
    logger.error("Error calculating DD wait time", {
      ddId,
      error: error.message,
    });
    // Return high wait time on error to avoid assigning to this DD
    return 999;
  }
}

/**
 * Find the best DD to assign a ride to (shortest wait time)
 *
 * @param eventId - The event ID
 * @returns Promise<DDWithWaitTime | null> - Best DD or null if none available
 */
async function findBestAvailableDD(
  eventId: string
): Promise<DDWithWaitTime | null> {
  try {
    // Fetch event to get the collection path
    const eventDoc = await db.collection("events").doc(eventId).get();

    if (!eventDoc.exists) {
      logger.error("Event not found", {eventId});
      return null;
    }

    // Fetch all active DD assignments for this event
    const ddAssignmentsSnapshot = await db
      .collection("events")
      .doc(eventId)
      .collection("ddAssignments")
      .where("isActive", "==", true)
      .get();

    if (ddAssignmentsSnapshot.empty) {
      logger.warn("No active DDs available for event", {eventId});
      return null;
    }

    logger.info("Found active DDs", {
      count: ddAssignmentsSnapshot.size,
      eventId,
    });

    // Calculate wait time for each DD
    const ddWaitTimes: DDWithWaitTime[] = await Promise.all(
      ddAssignmentsSnapshot.docs.map(async (doc) => {
        const assignment = doc.data() as DDAssignment;
        const waitTime = await calculateDDWaitTime(doc.id, eventId);

        return {
          userId: doc.id,
          waitTime,
          assignment,
        };
      })
    );

    // Find DD with minimum wait time
    const bestDD = ddWaitTimes.reduce((best, current) => {
      return current.waitTime < best.waitTime ? current : best;
    });

    logger.info("Selected best DD", {
      ddId: bestDD.userId,
      waitTime: bestDD.waitTime,
      totalActiveDDs: ddWaitTimes.length,
    });

    return bestDD;
  } catch (error: any) {
    logger.error("Error finding best DD", {
      eventId,
      error: error.message,
    });
    return null;
  }
}

/**
 * Auto-assign ride to DD with shortest wait time
 *
 * Triggered when a new ride document is created in Firestore.
 * Only processes rides with status "queued" and no existing DD assignment.
 */
export const autoAssignRide = onDocumentCreated(
  {
    document: "rides/{rideId}",
    region: "us-central1",
    timeoutSeconds: 60,
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

    logger.info("Auto-assign ride triggered", {
      rideId,
      status: ride.status,
      eventId: ride.eventId,
    });

    // Only process queued rides without DD assignment
    if (ride.status !== "queued") {
      logger.info("Ride not in queued status, skipping", {
        rideId,
        status: ride.status,
      });
      return;
    }

    if (ride.ddId) {
      logger.info("Ride already has DD assigned, skipping", {
        rideId,
        ddId: ride.ddId,
      });
      return;
    }

    try {
      // Find best available DD
      const bestDD = await findBestAvailableDD(ride.eventId);

      if (!bestDD) {
        logger.warn("No available DDs, leaving ride in queue", {
          rideId,
          eventId: ride.eventId,
        });
        return;
      }

      // Fetch DD user info
      const ddUserDoc = await db.collection("users").doc(bestDD.userId).get();

      if (!ddUserDoc.exists) {
        logger.error("DD user document not found", {
          ddId: bestDD.userId,
          rideId,
        });
        return;
      }

      const ddUser = ddUserDoc.data();

      // Assign ride to DD
      await snapshot.ref.update({
        ddId: bestDD.userId,
        ddName: ddUser?.name || "Unknown",
        ddPhoneNumber: ddUser?.phoneNumber || "",
        ddCarDescription: bestDD.assignment.carDescription || "Unknown car",
        status: "assigned",
        assignedTime: FieldValue.serverTimestamp(),
        estimatedWaitTime: bestDD.waitTime,
      });

      logger.info("Ride assigned successfully", {
        rideId,
        ddId: bestDD.userId,
        ddName: ddUser?.name,
        estimatedWaitTime: bestDD.waitTime,
      });

      // Note: DD totalRidesCompleted is incremented when ride is completed,
      // not when assigned (to avoid counting cancelled rides)
    } catch (error: any) {
      logger.error("Error in auto-assign ride", {
        rideId,
        error: error.message,
        stack: error.stack,
      });
      throw error;
    }
  }
);

/**
 * SMS Notification Functions
 *
 * Handles sending SMS notifications to DDs and riders via Twilio
 * for ride status updates.
 */

import * as logger from "firebase-functions/logger";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {sendSMSSafe} from "./utils/twilioClient";

// Initialize Firebase Admin
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

/**
 * Notify DD when a new ride is assigned to them
 *
 * Triggered when ride status changes from "queued" to "assigned"
 * SMS format: "New ride: {riderName} at {pickupAddress}"
 */
export const notifyDDNewRide = onDocumentUpdated(
  {
    document: "rides/{rideId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const rideId = event.params.rideId;

    if (!before || !after) {
      logger.error("Missing ride data", {rideId});
      return;
    }

    // Only trigger when status changes from queued to assigned
    if (before.status !== "queued" || after.status !== "assigned") {
      return;
    }

    logger.info("Notifying DD of new ride assignment", {
      rideId,
      ddId: after.ddId,
      riderId: after.riderId,
    });

    try {
      // Get DD phone number (should be in ride data already)
      const ddPhoneNumber = after.ddPhoneNumber;

      if (!ddPhoneNumber) {
        logger.error("DD phone number missing from ride data", {
          rideId,
          ddId: after.ddId,
        });
        return;
      }

      // Get rider info
      const riderName = after.riderName || "Rider";
      const pickupAddress = after.pickupAddress || "Unknown location";
      const isEmergency = after.isEmergency || false;

      // Format SMS message
      const emergencyPrefix = isEmergency ? "🚨 EMERGENCY RIDE: " : "";
      const messageBody =
        `${emergencyPrefix}New ride: ${riderName} at ${pickupAddress}`;

      // Send SMS (non-critical, don't throw errors)
      const sent = await sendSMSSafe({
        to: ddPhoneNumber,
        body: messageBody,
      });

      if (sent) {
        logger.info("DD notification SMS sent successfully", {
          rideId,
          ddId: after.ddId,
          ddPhoneNumber,
        });
      } else {
        logger.error("Failed to send DD notification SMS", {
          rideId,
          ddId: after.ddId,
          ddPhoneNumber,
        });
      }
    } catch (error: any) {
      logger.error("Error in notifyDDNewRide", {
        rideId,
        error: error.message,
        stack: error.stack,
      });
      // Don't throw - notification failure shouldn't block other operations
    }
  }
);

/**
 * Notify rider when DD is en route
 *
 * Triggered when ride status changes from "assigned" to "enroute"
 * SMS format: "{ddName} in {carDescription} is {ETA} mins away"
 */
export const notifyRiderEnRoute = onDocumentUpdated(
  {
    document: "rides/{rideId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const rideId = event.params.rideId;

    if (!before || !after) {
      logger.error("Missing ride data", {rideId});
      return;
    }

    // Only trigger when status changes from assigned to enroute
    if (before.status !== "assigned" || after.status !== "enroute") {
      return;
    }

    logger.info("Notifying rider that DD is en route", {
      rideId,
      riderId: after.riderId,
      ddId: after.ddId,
    });

    try {
      // Get rider phone number
      const riderPhoneNumber = after.riderPhoneNumber;

      if (!riderPhoneNumber) {
        logger.error("Rider phone number missing from ride data", {
          rideId,
          riderId: after.riderId,
        });
        return;
      }

      // Get DD info from ride data
      const ddName = after.ddName || "Your DD";
      const carDescription = after.ddCarDescription || "their car";
      const estimatedETA = after.estimatedETA;

      // Format ETA text
      let etaText = "on the way";
      if (estimatedETA && estimatedETA > 0) {
        etaText = `${estimatedETA} min${estimatedETA !== 1 ? "s" : ""} away`;
      }

      // Format SMS message (keep under 160 chars)
      const messageBody =
        `${ddName} in ${carDescription} is ${etaText}`;

      // Send SMS (non-critical)
      const sent = await sendSMSSafe({
        to: riderPhoneNumber,
        body: messageBody,
      });

      if (sent) {
        logger.info("Rider notification SMS sent successfully", {
          rideId,
          riderId: after.riderId,
          riderPhoneNumber,
        });
      } else {
        logger.error("Failed to send rider notification SMS", {
          rideId,
          riderId: after.riderId,
          riderPhoneNumber,
        });
      }
    } catch (error: any) {
      logger.error("Error in notifyRiderEnRoute", {
        rideId,
        error: error.message,
        stack: error.stack,
      });
      // Don't throw - notification failure shouldn't block other operations
    }
  }
);

/**
 * Increment DD ride count when ride is completed
 *
 * Triggered when ride status changes to "completed"
 * Updates the DD's totalRidesCompleted counter
 */
export const incrementDDRideCount = onDocumentUpdated(
  {
    document: "rides/{rideId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const rideId = event.params.rideId;

    if (!before || !after) {
      logger.error("Missing ride data", {rideId});
      return;
    }

    // Only trigger when status changes to completed
    if (after.status !== "completed" || before.status === "completed") {
      return;
    }

    const ddId = after.ddId;
    const eventId = after.eventId;

    if (!ddId || !eventId) {
      logger.error("Missing ddId or eventId", {rideId, ddId, eventId});
      return;
    }

    logger.info("Incrementing DD ride count", {
      rideId,
      ddId,
      eventId,
    });

    try {
      // Update DD assignment ride count
      const ddAssignmentRef = db
        .collection("events")
        .doc(eventId)
        .collection("ddAssignments")
        .doc(ddId);

      await ddAssignmentRef.update({
        totalRidesCompleted: (await ddAssignmentRef.get()).data()
          ?.totalRidesCompleted + 1 || 1,
      });

      logger.info("DD ride count incremented successfully", {
        rideId,
        ddId,
      });
    } catch (error: any) {
      logger.error("Error incrementing DD ride count", {
        rideId,
        ddId,
        error: error.message,
      });
      // Don't throw - this is a background update
    }
  }
);

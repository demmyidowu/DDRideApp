/**
 * Year Transition Function
 *
 * Scheduled function that runs annually on August 1st at midnight (Central Time)
 * to handle class year transitions:
 * - Removes all seniors (classYear === 4)
 * - Advances all other members by one year (classYear += 1)
 * - Logs results for audit trail
 */

import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp, getApps} from "firebase-admin/app";
import {getFirestore, FieldValue, WriteBatch} from "firebase-admin/firestore";

// Initialize Firebase Admin
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

/**
 * Interface for year transition log
 */
interface YearTransitionLog {
  executionDate: any; // Firestore timestamp
  chaptersProcessed: number;
  seniorsRemoved: number;
  usersAdvanced: number;
  status: "success" | "failed" | "partial";
  errorMessage?: string;
  chapterResults?: Array<{
    chapterId: string;
    chapterName: string;
    seniorsRemoved: number;
    usersAdvanced: number;
    status: "success" | "failed";
    error?: string;
  }>;
}

/**
 * Execute batch writes with proper batching (max 500 operations per batch)
 *
 * @param operations - Array of functions that add operations to a batch
 * @returns Promise<number> - Number of batches committed
 */
async function executeBatchedWrites(
  operations: Array<(batch: WriteBatch) => void>
): Promise<number> {
  const MAX_BATCH_SIZE = 500;
  let batchCount = 0;
  let currentBatch = db.batch();
  let operationCount = 0;

  for (const operation of operations) {
    operation(currentBatch);
    operationCount++;

    if (operationCount >= MAX_BATCH_SIZE) {
      await currentBatch.commit();
      batchCount++;
      logger.info("Committed batch", {batchNumber: batchCount});

      currentBatch = db.batch();
      operationCount = 0;
    }
  }

  // Commit remaining operations
  if (operationCount > 0) {
    await currentBatch.commit();
    batchCount++;
    logger.info("Committed final batch", {batchNumber: batchCount});
  }

  return batchCount;
}

/**
 * Process year transition for a single chapter
 *
 * @param chapterId - Chapter document ID
 * @param chapterName - Chapter name for logging
 * @returns Promise with transition results
 */
async function processChapterTransition(
  chapterId: string,
  chapterName: string
): Promise<{
  seniorsRemoved: number;
  usersAdvanced: number;
  status: "success" | "failed";
  error?: string;
}> {
  try {
    logger.info("Processing chapter transition", {chapterId, chapterName});

    // Fetch all users in this chapter
    const usersSnapshot = await db
      .collection("users")
      .where("chapterId", "==", chapterId)
      .get();

    if (usersSnapshot.empty) {
      logger.info("No users in chapter", {chapterId});
      return {
        seniorsRemoved: 0,
        usersAdvanced: 0,
        status: "success",
      };
    }

    const operations: Array<(batch: WriteBatch) => void> = [];
    let seniorsRemoved = 0;
    let usersAdvanced = 0;

    // Process each user
    usersSnapshot.forEach((userDoc) => {
      const user = userDoc.data();
      const classYear = user.classYear;

      if (classYear === 4) {
        // Delete seniors
        operations.push((batch) => batch.delete(userDoc.ref));
        seniorsRemoved++;
      } else if (classYear >= 1 && classYear <= 3) {
        // Advance everyone else
        operations.push((batch) =>
          batch.update(userDoc.ref, {
            classYear: classYear + 1,
            updatedAt: FieldValue.serverTimestamp(),
          })
        );
        usersAdvanced++;
      }
    });

    // Execute all operations
    await executeBatchedWrites(operations);

    logger.info("Chapter transition complete", {
      chapterId,
      chapterName,
      seniorsRemoved,
      usersAdvanced,
    });

    return {
      seniorsRemoved,
      usersAdvanced,
      status: "success",
    };
  } catch (error: any) {
    logger.error("Chapter transition failed", {
      chapterId,
      chapterName,
      error: error.message,
    });

    return {
      seniorsRemoved: 0,
      usersAdvanced: 0,
      status: "failed",
      error: error.message,
    };
  }
}

/**
 * Notify chapter admins about year transition completion
 *
 * @param chapterId - Chapter document ID
 * @param seniorsRemoved - Number of seniors removed
 * @param usersAdvanced - Number of users advanced
 */
async function notifyChapterAdmins(
  chapterId: string,
  seniorsRemoved: number,
  usersAdvanced: number
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

    // Create admin alert
    await db.collection("adminAlerts").add({
      chapterId,
      type: "year_transition",
      message:
        `Year transition complete: ${seniorsRemoved} seniors removed, ` +
        `${usersAdvanced} members advanced. Please add new freshmen.`,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("Admin notification created", {
      chapterId,
      adminCount: adminsSnapshot.size,
    });

    // TODO: Send push notifications via FCM
    // Placeholder for future implementation
  } catch (error: any) {
    logger.error("Failed to notify admins", {
      chapterId,
      error: error.message,
    });
    // Don't throw - notification failure shouldn't fail the transition
  }
}

/**
 * Year Transition Scheduled Function
 *
 * Runs annually on August 1st at midnight Central Time
 * Schedule: "0 0 1 8 *" = minute 0, hour 0, day 1, month 8, any day of week
 */
export const yearTransition = onSchedule(
  {
    schedule: "0 0 1 8 *",
    timeZone: "America/Chicago",
    region: "us-central1",
    timeoutSeconds: 540, // 9 minutes (max for scheduled functions)
    memory: "512MiB",
  },
  async () => {
    logger.info("Year transition scheduled function started");

    const startTime = Date.now();
    let totalSeniorsRemoved = 0;
    let totalUsersAdvanced = 0;
    let chaptersProcessed = 0;
    const chapterResults: YearTransitionLog["chapterResults"] = [];

    try {
      // Fetch all chapters
      const chaptersSnapshot = await db.collection("chapters").get();

      if (chaptersSnapshot.empty) {
        logger.warn("No chapters found");
        await createTransitionLog({
          executionDate: FieldValue.serverTimestamp(),
          chaptersProcessed: 0,
          seniorsRemoved: 0,
          usersAdvanced: 0,
          status: "success",
        });
        return;
      }

      logger.info("Processing chapters", {count: chaptersSnapshot.size});

      // Process each chapter
      for (const chapterDoc of chaptersSnapshot.docs) {
        const chapter = chapterDoc.data();
        const chapterId = chapterDoc.id;
        const chapterName = chapter.name || "Unknown";

        const result = await processChapterTransition(chapterId, chapterName);

        chaptersProcessed++;
        totalSeniorsRemoved += result.seniorsRemoved;
        totalUsersAdvanced += result.usersAdvanced;

        chapterResults.push({
          chapterId,
          chapterName,
          seniorsRemoved: result.seniorsRemoved,
          usersAdvanced: result.usersAdvanced,
          status: result.status,
          error: result.error,
        });

        // Notify chapter admins
        await notifyChapterAdmins(
          chapterId,
          result.seniorsRemoved,
          result.usersAdvanced
        );
      }

      const executionTime = Date.now() - startTime;

      // Determine overall status
      const hasFailures = chapterResults.some((r) => r.status === "failed");
      const status = hasFailures ? "partial" : "success";

      // Create transition log
      await createTransitionLog({
        executionDate: FieldValue.serverTimestamp(),
        chaptersProcessed,
        seniorsRemoved: totalSeniorsRemoved,
        usersAdvanced: totalUsersAdvanced,
        status,
        chapterResults,
      });

      logger.info("Year transition completed successfully", {
        chaptersProcessed,
        totalSeniorsRemoved,
        totalUsersAdvanced,
        executionTimeMs: executionTime,
        status,
      });
    } catch (error: any) {
      logger.error("Year transition failed", {
        error: error.message,
        stack: error.stack,
      });

      // Log failure
      await createTransitionLog({
        executionDate: FieldValue.serverTimestamp(),
        chaptersProcessed,
        seniorsRemoved: totalSeniorsRemoved,
        usersAdvanced: totalUsersAdvanced,
        status: "failed",
        errorMessage: error.message,
        chapterResults,
      });

      throw error;
    }
  }
);

/**
 * Create year transition log for audit trail
 *
 * @param logData - Log data to store
 */
async function createTransitionLog(
  logData: YearTransitionLog
): Promise<void> {
  try {
    await db.collection("yearTransitionLogs").add(logData);
    logger.info("Year transition log created", {
      status: logData.status,
      seniorsRemoved: logData.seniorsRemoved,
      usersAdvanced: logData.usersAdvanced,
    });
  } catch (error: any) {
    logger.error("Failed to create transition log", {
      error: error.message,
    });
    // Don't throw - logging failure shouldn't fail the function
  }
}

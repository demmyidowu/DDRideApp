/**
 * Twilio SMS client with retry logic and error handling
 */

import * as logger from "firebase-functions/logger";
import twilio from "twilio";
import {isValidE164} from "./validation";

/**
 * SMS sending options
 */
export interface SendSMSOptions {
  to: string;
  body: string;
  maxRetries?: number;
}

// Twilio configuration from environment variables
// Set these via Firebase environment config or secrets
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
const TWILIO_PHONE_NUMBER = process.env.TWILIO_PHONE_NUMBER;

/**
 * Initialize Twilio client with config from environment
 */
function getTwilioClient() {
  const twilioSid = TWILIO_ACCOUNT_SID;
  const twilioToken = TWILIO_AUTH_TOKEN;

  if (!twilioSid || !twilioToken) {
    throw new Error(
      "Twilio credentials not configured. Set TWILIO_ACCOUNT_SID and " +
      "TWILIO_AUTH_TOKEN environment variables or use Firebase Secrets."
    );
  }

  return twilio(twilioSid, twilioToken);
}

/**
 * Get Twilio phone number from environment
 */
function getTwilioNumber(): string {
  const twilioNumber = TWILIO_PHONE_NUMBER;

  if (!twilioNumber) {
    throw new Error(
      "Twilio phone number not configured. Set TWILIO_PHONE_NUMBER " +
      "environment variable."
    );
  }

  return twilioNumber;
}

/**
 * Sleep for specified milliseconds (for retry backoff)
 *
 * @param ms - Milliseconds to sleep
 * @returns Promise that resolves after delay
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Send SMS via Twilio with retry logic and error handling
 *
 * @param options - SMS sending options
 * @returns Promise<boolean> - true if sent successfully, false otherwise
 * @throws Error if phone number is invalid or max retries exceeded
 *
 * @example
 * ```typescript
 * await sendSMS({
 *   to: '+15551234567',
 *   body: 'Your ride is on the way!'
 * });
 * ```
 */
export async function sendSMS(options: SendSMSOptions): Promise<boolean> {
  const {to, body, maxRetries = 3} = options;

  // Validate phone number format
  if (!isValidE164(to)) {
    logger.error("Invalid phone number format", {to});
    throw new Error(`Invalid E.164 phone number format: ${to}`);
  }

  // Validate message body
  if (!body || body.trim().length === 0) {
    logger.error("Empty SMS body");
    throw new Error("SMS body cannot be empty");
  }

  // Log SMS attempt (for cost tracking)
  logger.info("Attempting to send SMS", {
    to,
    bodyLength: body.length,
    estimatedCost: "$0.0079",
  });

  const client = getTwilioClient();
  const twilioNumber = getTwilioNumber();

  // Retry logic with exponential backoff
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const message = await client.messages.create({
        body,
        from: twilioNumber,
        to,
      });

      logger.info("SMS sent successfully", {
        messageSid: message.sid,
        to,
        status: message.status,
        attempt: attempt + 1,
      });

      return true;
    } catch (error: any) {
      logger.error(`SMS attempt ${attempt + 1} failed`, {
        to,
        error: error.message,
        code: error.code,
        status: error.status,
      });

      // If this was the last attempt, throw the error
      if (attempt === maxRetries - 1) {
        logger.error("SMS max retries exceeded", {
          to,
          attempts: maxRetries,
        });
        throw new Error(
          `Failed to send SMS after ${maxRetries} attempts: ${error.message}`
        );
      }

      // Exponential backoff: 1s, 2s, 4s
      const backoffMs = Math.pow(2, attempt) * 1000;
      logger.info("Retrying SMS after backoff", {
        backoffMs,
        nextAttempt: attempt + 2,
      });
      await sleep(backoffMs);
    }
  }

  return false;
}

/**
 * Send SMS without throwing errors (safe wrapper)
 * Logs errors but doesn't throw, useful for non-critical notifications
 *
 * @param options - SMS sending options
 * @returns Promise<boolean> - true if sent, false if failed
 */
export async function sendSMSSafe(options: SendSMSOptions): Promise<boolean> {
  try {
    return await sendSMS(options);
  } catch (error: any) {
    logger.error("SMS send failed (non-critical)", {
      to: options.to,
      error: error.message,
    });
    return false;
  }
}

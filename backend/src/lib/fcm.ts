import admin from "firebase-admin";
import prisma from "./prisma";

// Initialize Firebase Admin
// Note: You need to set up a Firebase project and provide credentials
// For now, this is a placeholder that logs when FCM would send
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;

let fcmInitialized = false;

try {
  if (!admin.apps.length) {
    admin.initializeApp(
      serviceAccount
        ? {
            credential: admin.credential.cert(JSON.parse(serviceAccount)),
            projectId: process.env.FIREBASE_PROJECT_ID,
          }
        : {
            credential: admin.credential.applicationDefault(),
            projectId: process.env.FIREBASE_PROJECT_ID,
          },
    );
  }

  fcmInitialized = true;
} catch (err) {
  console.error("Failed to initialize Firebase Admin:", err);
}

// Rate limiting: track FCM sends per user per hour
const fcmRateLimit = 10; // max 10 notifications per user per hour
const fcmRateWindow = 60 * 60 * 1000; // 1 hour in ms
const fcmSendLog = new Map<string, { count: number; resetTime: number }>();

/**
 * Check if user is rate limited for FCM
 */
function isRateLimited(userId: string): boolean {
  const now = Date.now();
  const userLog = fcmSendLog.get(userId);

  if (!userLog || now > userLog.resetTime) {
    // Reset or create new log
    fcmSendLog.set(userId, { count: 1, resetTime: now + fcmRateWindow });
    return false;
  }

  if (userLog.count >= fcmRateLimit) {
    console.log(`FCM rate limit exceeded for user ${userId}`);
    return true;
  }

  userLog.count++;
  return false;
}

/**
 * Send a push notification to a user's registered FCM devices
 */
export async function sendPushNotification(userId: string, title: string, body: string, link?: string) {
  if (!fcmInitialized) {
    console.log(`[FCM Mock] Would send to user ${userId}: ${title} - ${body}`);
    return;
  }

  // Rate limiting check
  if (isRateLimited(userId)) {
    console.log(`FCM notification skipped for user ${userId} due to rate limit`);
    return;
  }

  try {
    // Get all device tokens for the user
    const deviceTokens = await prisma.fcmDeviceToken.findMany({
      where: { userId },
      select: { token: true },
      take: 100,
    });

    if (deviceTokens.length === 0) {
      console.log(`No FCM tokens found for user ${userId}`);
      return;
    }

    const tokens = deviceTokens.map((t: { token: string }) => t.token);

    // Send notification to all devices using sendEachForMulticast
    const message: admin.messaging.MulticastMessage = {
      notification: {
        title,
        body,
      },
      data: link ? { link } : undefined,
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`FCM sent to ${response.successCount}/${response.responses.length} devices for user ${userId}`);

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp: admin.messaging.SendResponse, idx: number) => {
        if (!resp.success) {
          invalidTokens.push(tokens[idx]);
        }
      });

      if (invalidTokens.length > 0) {
        await prisma.fcmDeviceToken.deleteMany({
          where: {
            token: { in: invalidTokens },
          },
        });
        console.log(`Cleaned up ${invalidTokens.length} invalid FCM tokens`);
      }
    }
  } catch (err) {
    console.error("Failed to send FCM notification:", err);
  }
}

/**
 * Get FCM statistics for monitoring
 */
export function getFcmStats() {
  return {
    rateLimit: fcmRateLimit,
    rateWindow: fcmRateWindow,
    activeUsers: fcmSendLog.size,
    initialized: fcmInitialized,
  };
}

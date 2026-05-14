import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, AuthRequest } from "../middleware/auth";

const router = Router();

// POST /api/fcm/register - Register a device token
router.post("/register", authenticate as any, async (req: AuthRequest, res) => {
  try {
    const { token, platform } = req.body;
    if (!token || typeof token !== "string") {
      res.status(400).json({ error: "FCM token is required" });
      return;
    }
    if (!platform || !["ios", "android"].includes(platform)) {
      res.status(400).json({ error: "Platform must be 'ios' or 'android'" });
      return;
    }

    // Upsert the token
    const deviceToken = await prisma.fcmDeviceToken.upsert({
      where: { token },
      create: {
        userId: req.user!.id,
        token,
        platform,
      },
      update: {
        updatedAt: new Date(),
      },
    });

    res.json({ deviceToken });
  } catch (err) {
    console.error("FCM register error:", err);
    res.status(500).json({ error: "Failed to register device token" });
  }
});

// POST /api/fcm/unregister - Unregister a device token
router.post("/unregister", authenticate as any, async (req: AuthRequest, res) => {
  try {
    const { token } = req.body;
    if (!token || typeof token !== "string") {
      res.status(400).json({ error: "FCM token is required" });
      return;
    }

    await prisma.fcmDeviceToken.deleteMany({
      where: {
        userId: req.user!.id,
        token,
      },
    });

    res.json({ success: true });
  } catch (err) {
    console.error("FCM unregister error:", err);
    res.status(500).json({ error: "Failed to unregister device token" });
  }
});

// GET /api/fcm/tokens - Get all tokens for the current user (for debugging)
router.get("/tokens", authenticate as any, async (req: AuthRequest, res) => {
  try {
    const tokens = await prisma.fcmDeviceToken.findMany({
      where: { userId: req.user!.id },
      select: {
        id: true,
        platform: true,
        createdAt: true,
        updatedAt: true,
      },
      take: 50,
    });

    res.json({ tokens });
  } catch (err) {
    console.error("FCM tokens error:", err);
    res.status(500).json({ error: "Failed to fetch device tokens" });
  }
});

export default router;

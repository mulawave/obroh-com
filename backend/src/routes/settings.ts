import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, requireAdmin, AuthRequest } from "../middleware/auth";

const router = Router();
const adminAuth: any[] = [authenticate as any, requireApproved as any, requireAdmin as any];

// GET /api/settings - Get all platform settings
router.get("/", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const settings = await prisma.siteContent.findMany({
      where: { page: "settings" },
      orderBy: { key: "asc" },
      take: 100,
    });

    const settingsObj = settings.reduce((acc, setting) => {
      acc[setting.key] = setting.value;
      return acc;
    }, {} as Record<string, string>);

    res.json({ settings: settingsObj });
  } catch (err) {
    console.error("Settings fetch error:", err);
    res.status(500).json({ error: "Failed to load settings" });
  }
});

// PUT /api/settings - Update platform settings
router.put("/", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const { siteName, siteEmail, allowRegistration, requireApproval, emailNotifications } = req.body;

    const updates = [
      { key: "siteName", value: siteName },
      { key: "siteEmail", value: siteEmail },
      { key: "allowRegistration", value: allowRegistration.toString() },
      { key: "requireApproval", value: requireApproval.toString() },
      { key: "emailNotifications", value: emailNotifications.toString() },
    ];

    for (const update of updates) {
      await prisma.siteContent.upsert({
        where: {
          page_section_key: {
            page: "settings",
            section: "general",
            key: update.key,
          },
        },
        update: { value: update.value, updatedBy: req.user!.id },
        create: {
          page: "settings",
          section: "general",
          key: update.key,
          value: update.value,
          label: update.key,
          type: "text",
          updatedBy: req.user!.id,
        },
      });
    }

    res.json({ message: "Settings updated successfully" });
  } catch (err) {
    console.error("Update settings error:", err);
    res.status(500).json({ error: "Failed to update settings" });
  }
});

export default router;

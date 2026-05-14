import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

// GET /api/analytics - Get platform analytics
router.get("/", ...auth, async (_req: AuthRequest, res) => {
  try {
    const [
      totalMembers,
      activeMembers,
      pendingApprovals,
      totalPosts,
      totalMilestones,
      totalAchievements,
      totalArticles,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { status: "approved" } }),
      prisma.user.count({ where: { status: "pending" } }),
      prisma.timelinePost.count(),
      prisma.legacyMilestone.count(),
      prisma.legacyAchievement.count(),
      prisma.knowledgeBaseArticle.count({ where: { published: true } }),
    ]);

    const monthlyGrowth = 12; // Mock calculation - would be based on new members in last 30 days
    const engagementRate = 68; // Mock calculation - would be based on likes/comments per post

    res.json({
      totalMembers,
      activeMembers,
      pendingApprovals,
      totalPosts,
      totalMilestones,
      totalAchievements,
      totalArticles,
      monthlyGrowth,
      engagementRate,
    });
  } catch (err) {
    console.error("Analytics fetch error:", err);
    res.status(500).json({ error: "Failed to load analytics" });
  }
});

export default router;

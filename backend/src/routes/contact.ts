import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireAdmin, AuthRequest } from "../middleware/auth";
import type { Prisma } from "@prisma/client";

const router = Router();

// POST /api/contact — public
router.post("/", async (req, res) => {
  try {
    const { name, email, reason, message } = req.body;
    if (!name || !email || !reason || !message) {
      res.status(400).json({ error: "All fields are required" });
      return;
    }

    const submission = await prisma.contactSubmission.create({ data: { name, email, reason, message } });

    // Create notification for admins
    const admins = await prisma.user.findMany({ where: { role: { in: ["admin", "superadmin"] } }, select: { id: true } });
    if (admins.length > 0) {
      await prisma.notification.createMany({
        data: admins.map((admin) => ({
          userId: admin.id,
          title: "New Contact Submission",
          body: `${name} (${email}) sent a message: ${reason}`,
          type: "contact",
          link: "/admin/contact",
        })),
      });
    }

    res.status(201).json({
      message: "Your message has been sent successfully. We'll get back to you soon.",
      id: submission.id,
    });
  } catch (err) {
    console.error("Contact submit error:", err);
    res.status(500).json({ error: "Failed to send message. Please try again." });
  }
});

// GET /api/contact — admin
router.get("/", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const { status, page = "1", limit = "20" } = req.query;
    const where: Prisma.ContactSubmissionWhereInput = {};
    if (status) where.status = status as any;

    const p = parseInt(page as string);
    const l = parseInt(limit as string);
    const total = await prisma.contactSubmission.count({ where });
    const submissions = await prisma.contactSubmission.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (p - 1) * l,
      take: l,
    });

    res.json({ submissions, total, page: p, pages: Math.ceil(total / l) });
  } catch (err) {
    console.error("List contacts error:", err);
    res.status(500).json({ error: "Failed to fetch submissions" });
  }
});

// PATCH /api/contact/:id/status
router.patch("/:id/status", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { status, adminNotes } = req.body;
    const submission = await prisma.contactSubmission.update({
      where: { id },
      data: { status, ...(adminNotes !== undefined && { adminNotes }) },
    });
    res.json({ submission });
  } catch (err) {
    console.error("Update contact status error:", err);
    res.status(500).json({ error: "Failed to update submission" });
  }
});

// DELETE /api/contact/:id
router.delete("/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    await prisma.contactSubmission.delete({ where: { id } });
    res.json({ message: "Submission deleted" });
  } catch (err) {
    console.error("Delete contact error:", err);
    res.status(500).json({ error: "Failed to delete submission" });
  }
});

export default router;

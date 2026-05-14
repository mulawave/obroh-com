import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, requireAdmin, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

function canModifyRequest(status?: string | null) {
  return status === "pending" || status === "rejected";
}

// GET /lineage — own lineage
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const userId = req.user!.id;
    const [asParent, asChild] = await Promise.all([
      prisma.lineageRelationship.findMany({
        where: { parentId: userId },
        include: { child: { select: { id: true, firstName: true, lastName: true, profileImage: true, branch: true } } },
        take: 100,
      }),
      prisma.lineageRelationship.findMany({
        where: { childId: userId },
        include: { parent: { select: { id: true, firstName: true, lastName: true, profileImage: true, branch: true } } },
        take: 100,
      }),
    ]);
    res.json({ children: asParent, parents: asChild });
  } catch (err) {
    console.error("Lineage error:", err);
    res.status(500).json({ error: "Failed to load lineage" });
  }
});

// GET /lineage/:userId — view another member's lineage
router.get("/:userId", ...auth, async (req: AuthRequest, res) => {
  try {
    const userId = String(req.params.userId);
    const [asParent, asChild] = await Promise.all([
      prisma.lineageRelationship.findMany({
        where: { parentId: userId },
        include: { child: { select: { id: true, firstName: true, lastName: true, profileImage: true, branch: true } } },
        take: 100,
      }),
      prisma.lineageRelationship.findMany({
        where: { childId: userId },
        include: { parent: { select: { id: true, firstName: true, lastName: true, profileImage: true, branch: true } } },
        take: 100,
      }),
    ]);
    res.json({ children: asParent, parents: asChild });
  } catch (err) {
    res.status(500).json({ error: "Failed to load lineage" });
  }
});

// POST /lineage/child-request — request to register a child
router.post("/child-request", ...auth, async (req: AuthRequest, res) => {
  try {
    const { firstName, lastName, dateOfBirth, gender, branch } = req.body;
    if (!firstName?.trim() || !lastName?.trim()) {
      res.status(400).json({ error: "First and last name are required" }); return;
    }
    const request = await prisma.childRegistrationRequest.create({
      data: { requestedById: req.user!.id, firstName: firstName.trim(), lastName: lastName.trim(), dateOfBirth, gender, branch },
    });
    res.status(201).json(request);
  } catch (err) {
    console.error("Child request error:", err);
    res.status(500).json({ error: "Failed to submit child registration request" });
  }
});

// PATCH /lineage/child-request/:id — user edit own request before approval
router.patch("/child-request/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const existing = await prisma.childRegistrationRequest.findUnique({ where: { id } });
    if (!existing) { res.status(404).json({ error: "Request not found" }); return; }
    if (existing.requestedById !== req.user!.id) { res.status(403).json({ error: "Not authorized" }); return; }
    if (!canModifyRequest(existing.status)) {
      res.status(400).json({ error: "Only pending or rejected requests can be edited" });
      return;
    }

    const { firstName, lastName, dateOfBirth, gender, branch } = req.body;
    const nextFirstName = firstName?.toString().trim() ?? existing.firstName;
    const nextLastName = lastName?.toString().trim() ?? existing.lastName;

    if (!nextFirstName || !nextLastName) {
      res.status(400).json({ error: "First and last name are required" });
      return;
    }

    const updated = await prisma.childRegistrationRequest.update({
      where: { id },
      data: {
        firstName: nextFirstName,
        lastName: nextLastName,
        dateOfBirth: dateOfBirth ?? null,
        gender: gender ?? null,
        branch: branch ?? null,
        status: "pending",
        adminNotes: null,
      },
    });

    res.json(updated);
  } catch (err) {
    console.error("Child request edit error:", err);
    res.status(500).json({ error: "Failed to update child registration request" });
  }
});

// DELETE /lineage/child-request/:id — user cancel own request before approval
router.delete("/child-request/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const existing = await prisma.childRegistrationRequest.findUnique({ where: { id } });
    if (!existing) { res.status(404).json({ error: "Request not found" }); return; }
    if (existing.requestedById !== req.user!.id) { res.status(403).json({ error: "Not authorized" }); return; }
    if (!canModifyRequest(existing.status)) {
      res.status(400).json({ error: "Only pending or rejected requests can be cancelled" });
      return;
    }

    await prisma.childRegistrationRequest.delete({ where: { id } });
    res.json({ message: "Request cancelled" });
  } catch (err) {
    console.error("Child request delete error:", err);
    res.status(500).json({ error: "Failed to cancel child registration request" });
  }
});

// GET /lineage/child-requests — own pending requests
router.get("/child-requests/mine", ...auth, async (req: AuthRequest, res) => {
  try {
    const requests = await prisma.childRegistrationRequest.findMany({
      where: { requestedById: req.user!.id },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    res.json({ requests });
  } catch (err) {
    res.status(500).json({ error: "Failed to load requests" });
  }
});

// GET /lineage/child-requests/admin — all pending (admin)
router.get("/child-requests/admin", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const requests = await prisma.childRegistrationRequest.findMany({
      where: { status: "pending" },
      include: { requestedBy: { select: { id: true, firstName: true, lastName: true, email: true } } },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    res.json({ requests });
  } catch (err) {
    res.status(500).json({ error: "Failed to load requests" });
  }
});

// PATCH /lineage/child-requests/:id — admin approve/reject
router.patch("/child-requests/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { status, adminNotes } = req.body;
    if (!["approved", "rejected"].includes(status)) {
      res.status(400).json({ error: "Invalid status" }); return;
    }
    const updated = await prisma.childRegistrationRequest.update({
      where: { id },
      data: { status, adminNotes },
    });
    res.json(updated);
  } catch (err) {
    console.error("Child request update error:", err);
    res.status(500).json({ error: "Failed to update request" });
  }
});

export default router;

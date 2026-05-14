import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, requireAdmin, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

const DECLARATION_TYPES = ["name-change", "court-affidavit", "marital-status", "custodial", "other"];

function canUserModify(status?: string | null) {
  return status === "submitted" || status === "needs-attention";
}

// GET /legal — own declarations
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const declarations = await prisma.legalDeclaration.findMany({
      where: { userId: req.user!.id },
      include: { documents: true },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    res.json({ declarations });
  } catch (err) {
    console.error("Get declarations error:", err);
    res.status(500).json({ error: "Failed to load declarations" });
  }
});

// POST /legal — submit declaration
router.post("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const { title, type, description } = req.body;
    if (!title?.trim() || !description?.trim()) {
      res.status(400).json({ error: "Title and description are required" }); return;
    }
    const declType = DECLARATION_TYPES.includes(type) ? type : "other";
    const declaration = await prisma.legalDeclaration.create({
      data: { userId: req.user!.id, title: title.trim(), type: declType, description: description.trim() },
      include: { documents: true },
    });
    res.status(201).json(declaration);
  } catch (err) {
    console.error("Create declaration error:", err);
    res.status(500).json({ error: "Failed to create declaration" });
  }
});

// GET /legal/admin/all — admin view all
router.get("/admin/all", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const status = req.query.status as string | undefined;
    const where: any = {};
    if (status) where.status = status;
    const declarations = await prisma.legalDeclaration.findMany({
      where,
      include: { documents: true, user: { select: { id: true, firstName: true, lastName: true, email: true } } },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    res.json({ declarations });
  } catch (err) {
    res.status(500).json({ error: "Failed to load declarations" });
  }
});

// GET /legal/:id — view declaration
router.get("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const declaration = await prisma.legalDeclaration.findUnique({
      where: { id },
      include: { documents: true, user: { select: { id: true, firstName: true, lastName: true } } },
    });
    if (!declaration) { res.status(404).json({ error: "Not found" }); return; }
    if (declaration.userId !== req.user!.id && !["admin", "superadmin"].includes(req.user!.role)) {
      res.status(403).json({ error: "Not authorized" }); return;
    }
    res.json(declaration);
  } catch (err) {
    res.status(500).json({ error: "Failed to load declaration" });
  }
});

// PUT /legal/:id — user edit own declaration while still modifiable
router.put("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const declaration = await prisma.legalDeclaration.findUnique({ where: { id } });
    if (!declaration) { res.status(404).json({ error: "Not found" }); return; }
    if (declaration.userId !== req.user!.id) { res.status(403).json({ error: "Not authorized" }); return; }
    if (!canUserModify(declaration.status)) {
      res.status(400).json({ error: "Only submitted or needs-attention declarations can be edited" });
      return;
    }

    const { title, type, description } = req.body;
    const nextTitle = title?.toString().trim() ?? declaration.title;
    const nextDescription = description?.toString().trim() ?? declaration.description;
    const nextType = DECLARATION_TYPES.includes(type) ? type : declaration.type;

    if (!nextTitle || !nextDescription) {
      res.status(400).json({ error: "Title and description are required" });
      return;
    }

    const updated = await prisma.legalDeclaration.update({
      where: { id },
      data: {
        title: nextTitle,
        description: nextDescription,
        type: nextType,
        status: declaration.status === "needs-attention" ? "submitted" : declaration.status,
      },
      include: { documents: true },
    });
    res.json(updated);
  } catch (err) {
    console.error("Update declaration error:", err);
    res.status(500).json({ error: "Failed to update declaration" });
  }
});

// DELETE /legal/:id — user cancel own declaration while modifiable
router.delete("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const declaration = await prisma.legalDeclaration.findUnique({ where: { id } });
    if (!declaration) { res.status(404).json({ error: "Not found" }); return; }
    if (declaration.userId !== req.user!.id) { res.status(403).json({ error: "Not authorized" }); return; }
    if (!canUserModify(declaration.status)) {
      res.status(400).json({ error: "Only submitted or needs-attention declarations can be deleted" });
      return;
    }

    await prisma.legalDeclaration.delete({ where: { id } });
    res.json({ message: "Declaration cancelled" });
  } catch (err) {
    console.error("Delete declaration error:", err);
    res.status(500).json({ error: "Failed to cancel declaration" });
  }
});

// PATCH /legal/:id/status — admin update status
router.patch("/:id/status", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { status, adminNotes } = req.body;
    if (!["submitted", "reviewed", "resolved", "needs-attention"].includes(status)) {
      res.status(400).json({ error: "Invalid status" }); return;
    }
    const declaration = await prisma.legalDeclaration.findUnique({ where: { id }, select: { userId: true, title: true } });
    if (!declaration) { res.status(404).json({ error: "Not found" }); return; }
    const updated = await prisma.legalDeclaration.update({
      where: { id },
      data: { status, adminNotes },
    });
    // Create notification for user
    await prisma.notification.create({
      data: {
        userId: declaration.userId,
        title: "Legal Declaration Status Update",
        body: `Your declaration "${declaration.title}" status has been updated to ${status}`,
        type: "legal",
        link: "/dashboard/legal",
      },
    });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ error: "Failed to update declaration" });
  }
});

export default router;

import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

// GET /api/legacy - Get all legacy items
router.get("/", async (_req, res) => {
  try {
    const legacy = await prisma.legacy.findMany({
      orderBy: [{ type: "asc" }, { sortOrder: "asc" }],
    });
    res.json(legacy);
  } catch (err) {
    console.error("Legacy fetch error:", err);
    res.status(500).json({ error: "Failed to load legacy items" });
  }
});

// GET /api/legacy/:id - Get single legacy item
router.get("/:id", async (req, res) => {
  try {
    const id = String(req.params.id);
    const legacy = await prisma.legacy.findUnique({ where: { id } });
    if (!legacy) {
      res.status(404).json({ error: "Legacy item not found" });
      return;
    }
    res.json(legacy);
  } catch (err) {
    console.error("Legacy fetch error:", err);
    res.status(500).json({ error: "Failed to load legacy item" });
  }
});

// POST /api/legacy - Create legacy item
router.post("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const { type, year, title, description, icon, category, sortOrder } = req.body;

    if (!type || !title || !description) {
      res.status(400).json({ error: "Type, title, and description are required" });
      return;
    }

    const legacy = await prisma.legacy.create({
      data: {
        type,
        year,
        title,
        description,
        icon,
        category,
        sortOrder: sortOrder || 0,
      },
    });

    res.status(201).json(legacy);
  } catch (err) {
    console.error("Create legacy error:", err);
    res.status(500).json({ error: "Failed to create legacy item" });
  }
});

// PUT /api/legacy/:id - Update legacy item
router.put("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { type, year, title, description, icon, category, sortOrder } = req.body;

    const legacy = await prisma.legacy.update({
      where: { id },
      data: {
        type,
        year,
        title,
        description,
        icon,
        category,
        sortOrder,
      },
    });

    res.json(legacy);
  } catch (err) {
    console.error("Update legacy error:", err);
    res.status(500).json({ error: "Failed to update legacy item" });
  }
});

// DELETE /api/legacy/:id - Delete legacy item
router.delete("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    await prisma.legacy.delete({ where: { id } });
    res.json({ message: "Legacy item deleted" });
  } catch (err) {
    console.error("Delete legacy error:", err);
    res.status(500).json({ error: "Failed to delete legacy item" });
  }
});

export default router;

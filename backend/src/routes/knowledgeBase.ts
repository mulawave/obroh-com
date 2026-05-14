import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

// GET /api/knowledge-base - Get all knowledge base items
router.get("/", async (_req, res) => {
  try {
    const knowledge = await prisma.knowledgeBase.findMany({
      orderBy: [{ type: "asc" }, { sortOrder: "asc" }],
    });
    res.json(knowledge);
  } catch (err) {
    console.error("Knowledge base fetch error:", err);
    res.status(500).json({ error: "Failed to load knowledge base items" });
  }
});

// GET /api/knowledge-base/:id - Get single knowledge base item
router.get("/:id", async (req, res) => {
  try {
    const id = String(req.params.id);
    const knowledge = await prisma.knowledgeBase.findUnique({ where: { id } });
    if (!knowledge) {
      res.status(404).json({ error: "Knowledge base item not found" });
      return;
    }
    res.json(knowledge);
  } catch (err) {
    console.error("Knowledge base fetch error:", err);
    res.status(500).json({ error: "Failed to load knowledge base item" });
  }
});

// POST /api/knowledge-base - Create knowledge base item
router.post("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const { type, title, description, content, excerpt, category, icon, readTime, sortOrder } = req.body;

    if (!type || !title) {
      res.status(400).json({ error: "Type and title are required" });
      return;
    }

    const knowledge = await prisma.knowledgeBase.create({
      data: {
        type,
        title,
        description,
        content,
        excerpt,
        category,
        icon,
        readTime,
        sortOrder: sortOrder || 0,
      },
    });

    res.status(201).json(knowledge);
  } catch (err) {
    console.error("Create knowledge base error:", err);
    res.status(500).json({ error: "Failed to create knowledge base item" });
  }
});

// PUT /api/knowledge-base/:id - Update knowledge base item
router.put("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { type, title, description, content, excerpt, category, icon, readTime, sortOrder } = req.body;

    const knowledge = await prisma.knowledgeBase.update({
      where: { id },
      data: {
        type,
        title,
        description,
        content,
        excerpt,
        category,
        icon,
        readTime,
        sortOrder,
      },
    });

    res.json(knowledge);
  } catch (err) {
    console.error("Update knowledge base error:", err);
    res.status(500).json({ error: "Failed to update knowledge base item" });
  }
});

// DELETE /api/knowledge-base/:id - Delete knowledge base item
router.delete("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    await prisma.knowledgeBase.delete({ where: { id } });
    res.json({ message: "Knowledge base item deleted" });
  } catch (err) {
    console.error("Delete knowledge base error:", err);
    res.status(500).json({ error: "Failed to delete knowledge base item" });
  }
});

export default router;

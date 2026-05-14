import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireAdmin, AuthRequest } from "../middleware/auth";
import type { Prisma } from "@prisma/client";

const router = Router();

// GET /api/content — public
router.get("/", async (req, res) => {
  try {
    const { page } = req.query;
    const where: Prisma.SiteContentWhereInput = {};
    if (page) where.page = page as string;

    const content = await prisma.siteContent.findMany({ where });

    const structured: Record<string, Record<string, Record<string, string>>> = {};
    for (const item of content) {
      if (!structured[item.page]) structured[item.page] = {};
      if (!structured[item.page][item.section]) structured[item.page][item.section] = {};
      structured[item.page][item.section][item.key] = item.value;
    }

    res.json({ content: structured, raw: content });
  } catch (err) {
    console.error("Fetch content error:", err);
    res.status(500).json({ error: "Failed to fetch content" });
  }
});

// GET /api/content/pages — admin
router.get("/pages", authenticate as any, requireAdmin as any, async (_req: AuthRequest, res) => {
  try {
    const rows = await prisma.siteContent.findMany({ select: { page: true }, distinct: ["page"] });
    const pages = rows.map((r) => r.page);
    const pageSections: Record<string, string[]> = {};
    for (const page of pages) {
      const secs = await prisma.siteContent.findMany({ where: { page }, select: { section: true }, distinct: ["section"] });
      pageSections[page] = secs.map((s) => s.section);
    }
    res.json({ pages, pageSections });
  } catch (err) {
    console.error("Fetch pages error:", err);
    res.status(500).json({ error: "Failed to fetch pages" });
  }
});

// GET /api/content/page/:page — admin
router.get("/page/:page", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const page = String(req.params.page);
    const content = await prisma.siteContent.findMany({
      where: { page },
      orderBy: [{ section: "asc" }, { key: "asc" }],
    });
    // Map _id to match frontend expectations
    res.json({ content: content.map((c) => ({ ...c, _id: c.id })) });
  } catch (err) {
    console.error("Fetch page content error:", err);
    res.status(500).json({ error: "Failed to fetch page content" });
  }
});

// PUT /api/content/bulk/update — must be before /:id
router.put("/bulk/update", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const { items } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      res.status(400).json({ error: "Items array is required" });
      return;
    }

    await prisma.$transaction(
      items.map((item: { id: string; value: string }) =>
        prisma.siteContent.update({ where: { id: item.id }, data: { value: item.value, updatedBy: req.user!.id } })
      )
    );
    res.json({ message: `${items.length} items updated successfully` });
  } catch (err) {
    console.error("Bulk update error:", err);
    res.status(500).json({ error: "Failed to bulk update content" });
  }
});

// PUT /api/content/:id — admin
router.put("/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { value } = req.body;
    if (value === undefined) { res.status(400).json({ error: "Value is required" }); return; }

    const content = await prisma.siteContent.update({
      where: { id },
      data: { value, updatedBy: req.user!.id },
    });
    res.json({ content });
  } catch (err) {
    console.error("Update content error:", err);
    res.status(500).json({ error: "Failed to update content" });
  }
});

// POST /api/content — admin
router.post("/", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const { section, key, value, type, page, label } = req.body;
    if (!section || !key || !value || !page || !label) {
      res.status(400).json({ error: "All fields are required" }); return;
    }

    const content = await prisma.siteContent.create({
      data: { section, key, value, type: type || "text", page, label, updatedBy: req.user!.id },
    });
    res.status(201).json({ content });
  } catch (err) {
    console.error("Create content error:", err);
    res.status(500).json({ error: "Failed to create content" });
  }
});

// DELETE /api/content/:id — admin
router.delete("/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    await prisma.siteContent.delete({ where: { id } });
    res.json({ message: "Content deleted" });
  } catch (err) {
    console.error("Delete content error:", err);
    res.status(500).json({ error: "Failed to delete content" });
  }
});

export default router;

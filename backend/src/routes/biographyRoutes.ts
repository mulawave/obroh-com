import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

// GET /biography — own biography
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    let bio = await prisma.biography.findUnique({
      where: { userId: req.user!.id },
      include: { sections: { orderBy: { sortOrder: "asc" } } },
    });
    if (!bio) {
      bio = await prisma.biography.create({
        data: { userId: req.user!.id },
        include: { sections: true },
      });
    }
    res.json(bio);
  } catch (err) {
    console.error("Get biography error:", err);
    res.status(500).json({ error: "Failed to load biography" });
  }
});

// PUT /biography — update settings
router.put("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const { isPublic, slug } = req.body;
    const bio = await prisma.biography.upsert({
      where: { userId: req.user!.id },
      create: { userId: req.user!.id, isPublic: !!isPublic, slug },
      update: { isPublic: isPublic !== undefined ? !!isPublic : undefined, slug },
    });
    res.json(bio);
  } catch (err) {
    console.error("Update biography error:", err);
    res.status(500).json({ error: "Failed to update biography" });
  }
});

// POST /biography/sections — add section
router.post("/sections", ...auth, async (req: AuthRequest, res) => {
  try {
    const bio = await prisma.biography.findUnique({ where: { userId: req.user!.id } });
    if (!bio) { res.status(400).json({ error: "Create biography first" }); return; }
    const { title, content, imageUrl, sortOrder } = req.body;
    const section = await prisma.biographySection.create({
      data: { biographyId: bio.id, title, content, imageUrl, sortOrder: sortOrder ?? 0 },
    });
    res.status(201).json(section);
  } catch (err) {
    console.error("Add section error:", err);
    res.status(500).json({ error: "Failed to add section" });
  }
});

// PUT /biography/sections/:id — update section
router.put("/sections/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const { title, content, imageUrl, sortOrder } = req.body;
    const section = await prisma.biographySection.update({
      where: { id: String(req.params.id) },
      data: { title, content, imageUrl, sortOrder },
    });
    res.json(section);
  } catch (err) {
    console.error("Update section error:", err);
    res.status(500).json({ error: "Failed to update section" });
  }
});

// DELETE /biography/sections/:id
router.delete("/sections/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.biographySection.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Section deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete section" });
  }
});

// GET /biography/public/:slug — public view
router.get("/public/:slug", async (req, res) => {
  try {
    const slug = String(req.params.slug);
    const bio = await prisma.biography.findUnique({
      where: { slug },
      include: {
        user: { select: { firstName: true, lastName: true, profileImage: true, bio: true, badges: { select: { label: true, icon: true } } } },
        sections: { orderBy: { sortOrder: "asc" } },
      },
    });
    if (!bio || !bio.isPublic) { res.status(404).json({ error: "Biography not found" }); return; }

    const portfolio = await prisma.portfolio.findUnique({ where: { userId: bio.userId } });
    const portfolioSlug = portfolio?.isPublic ? portfolio.slug : null;

    res.json({ ...bio, portfolioSlug });
  } catch (err) {
    console.error("Public biography error:", err);
    res.status(500).json({ error: "Failed to load biography" });
  }
});

export default router;

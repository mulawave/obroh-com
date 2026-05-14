import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";
import { sendPushNotification } from "../lib/fcm";
import { createMemoryUpload, createObjectName, saveUploadedFile } from "../lib/uploadStorage";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];
const upload = createMemoryUpload({
  errorMessage: "Only image uploads are allowed",
  fileSize: 5 * 1024 * 1024,
  accept: (mimetype) => mimetype.startsWith("image/"),
});

function sanitizeAssetUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith("https://") || trimmed.startsWith("http://")) {
    return trimmed;
  }

  if (trimmed.startsWith("https:/") && !trimmed.startsWith("https://")) {
    return `https://${trimmed.substring("https:/".length).replace(/^\/+/, "")}`;
  }

  if (trimmed.startsWith("http:/") && !trimmed.startsWith("http://")) {
    return `http://${trimmed.substring("http:/".length).replace(/^\/+/, "")}`;
  }

  if (trimmed.startsWith("//")) {
    return `https:${trimmed}`;
  }

  return trimmed;
}

function normalizePortfolioForResponse<T extends Record<string, any>>(portfolio: T): T {
  if (!portfolio) return portfolio;

  const galleryImages = Array.isArray(portfolio.galleryImages)
    ? portfolio.galleryImages.map((img: any) => ({
        ...img,
        url: sanitizeAssetUrl(img?.url) ?? img?.url,
      }))
    : portfolio.galleryImages;

  const experiences = Array.isArray(portfolio.experiences)
    ? portfolio.experiences.map((exp: any) => ({
        ...exp,
        imageUrl: sanitizeAssetUrl(exp?.imageUrl),
        images: Array.isArray(exp?.images)
          ? exp.images.map((img: any) => ({
              ...img,
              url: sanitizeAssetUrl(img?.url) ?? img?.url,
            }))
          : exp?.images,
      }))
    : portfolio.experiences;

  const education = Array.isArray(portfolio.education)
    ? portfolio.education.map((edu: any) => ({
        ...edu,
        imageUrl: sanitizeAssetUrl(edu?.imageUrl),
      }))
    : portfolio.education;

  const projects = Array.isArray(portfolio.projects)
    ? portfolio.projects.map((proj: any) => ({
        ...proj,
        imageUrl: sanitizeAssetUrl(proj?.imageUrl),
        images: Array.isArray(proj?.images)
          ? proj.images.map((img: any) => ({
              ...img,
              url: sanitizeAssetUrl(img?.url) ?? img?.url,
            }))
          : proj?.images,
      }))
    : portfolio.projects;

  const user = portfolio.user
    ? {
        ...portfolio.user,
        profileImage: sanitizeAssetUrl(portfolio.user.profileImage),
      }
    : portfolio.user;

  return {
    ...portfolio,
    user,
    galleryImages,
    experiences,
    education,
    projects,
  };
}

// GET /portfolio — own portfolio
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    let portfolio = await prisma.portfolio.findUnique({
      where: { userId: req.user!.id },
      include: { galleryImages: { orderBy: { sortOrder: "asc" } }, projects: { include: { images: true }, orderBy: { sortOrder: "asc" } }, skills: { orderBy: { sortOrder: "asc" } }, experiences: { include: { images: { orderBy: { sortOrder: "asc" } } }, orderBy: { sortOrder: "asc" } }, education: { orderBy: { sortOrder: "asc" } } },
    });
    if (!portfolio) {
      portfolio = await prisma.portfolio.create({
        data: { userId: req.user!.id },
        include: { galleryImages: true, projects: { include: { images: true } }, skills: true, experiences: { include: { images: true } }, education: true },
      });
    }
    res.json(normalizePortfolioForResponse(portfolio));
  } catch (err) {
    console.error("Get portfolio error:", err);
    res.status(500).json({ error: "Failed to load portfolio" });
  }
});

// PUT /portfolio — update portfolio settings
router.put("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const { headline, summary, isPublic, slug } = req.body;
    const portfolio = await prisma.portfolio.upsert({
      where: { userId: req.user!.id },
      create: { userId: req.user!.id, headline, summary, isPublic: !!isPublic, slug },
      update: { headline, summary, isPublic: isPublic !== undefined ? !!isPublic : undefined, slug },
    });
    res.json(portfolio);
  } catch (err) {
    console.error("Update portfolio error:", err);
    res.status(500).json({ error: "Failed to update portfolio" });
  }
});

// POST /portfolio/upload — upload portfolio image
router.post("/upload", ...auth, upload.single("image"), async (req: AuthRequest, res) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: "Image is required" });
      return;
    }
    const imageUrl = await saveUploadedFile(
      req.file,
      createObjectName("portfolio", req.file.originalname, req.user!.id),
    );
    res.json({ url: imageUrl });
  } catch (err) {
    console.error("Upload portfolio image error:", err);
    res.status(500).json({ error: "Failed to upload image" });
  }
});

// POST /portfolio/gallery — add gallery image
router.post("/gallery", ...auth, upload.single("image"), async (req: AuthRequest, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({ where: { userId: req.user!.id } });
    if (!portfolio) { res.status(400).json({ error: "Create portfolio first" }); return; }

    let imageUrl = sanitizeAssetUrl(req.body?.url as string | undefined) ?? undefined;
    if (req.file) {
      imageUrl = await saveUploadedFile(
        req.file,
        createObjectName("portfolio", req.file.originalname, req.user!.id),
      );
    }

    if (!imageUrl?.trim()) {
      res.status(400).json({ error: "Image url or image file is required" });
      return;
    }

    const { caption } = req.body;
    const maxSort = await prisma.portfolioGalleryImage.findFirst({
      where: { portfolioId: portfolio.id },
      orderBy: { sortOrder: "desc" },
    });
    const img = await prisma.portfolioGalleryImage.create({
      data: {
        portfolioId: portfolio.id,
        url: imageUrl.trim(),
        caption: caption || null,
        sortOrder: (maxSort?.sortOrder || 0) + 1,
      },
    });
    res.status(201).json(img);
  } catch (err) {
    console.error("Add gallery error:", err);
    res.status(500).json({ error: "Failed to add image" });
  }
});

// DELETE /portfolio/gallery/:id
router.delete("/gallery/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioGalleryImage.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete" });
  }
});

// POST /portfolio/skills
router.post("/skills", ...auth, async (req: AuthRequest, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({ where: { userId: req.user!.id } });
    if (!portfolio) { res.status(400).json({ error: "Create portfolio first" }); return; }
    const { name, yearsExperience, level } = req.body;
    const skill = await prisma.portfolioSkill.create({ data: { portfolioId: portfolio.id, name, yearsExperience, level } });
    res.status(201).json(skill);
  } catch (err) {
    res.status(500).json({ error: "Failed to add skill" });
  }
});

// DELETE /portfolio/skills/:id
router.delete("/skills/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioSkill.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete" });
  }
});

// POST /portfolio/experiences
router.post("/experiences", ...auth, async (req: AuthRequest, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({ where: { userId: req.user!.id } });
    if (!portfolio) { res.status(400).json({ error: "Create portfolio first" }); return; }
    const { title, company, location, startDate, endDate, description, imageUrl } = req.body;
    const exp = await prisma.portfolioExperience.create({ data: { portfolioId: portfolio.id, title, company, location, startDate, endDate, description, imageUrl: sanitizeAssetUrl(imageUrl) } });
    res.status(201).json(exp);
  } catch (err) {
    res.status(500).json({ error: "Failed to add experience" });
  }
});

// PUT /portfolio/experiences/:id
router.put("/experiences/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const { title, company, location, startDate, endDate, description, imageUrl } = req.body;
    const experience = await prisma.portfolioExperience.update({
      where: { id: String(req.params.id) },
      data: { title, company, location, startDate, endDate, description, imageUrl: sanitizeAssetUrl(imageUrl) },
    });
    res.json(experience);
  } catch (err) {
    res.status(500).json({ error: "Failed to update experience" });
  }
});

// DELETE /portfolio/experiences/:id
router.delete("/experiences/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioExperience.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete" });
  }
});

// POST /portfolio/experiences/:id/images - add image to experience
router.post("/experiences/:id/images", ...auth, upload.single("image"), async (req: AuthRequest, res) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: "Image is required" });
      return;
    }
    const experience = await prisma.portfolioExperience.findUnique({ where: { id: String(req.params.id) } });
    if (!experience) { res.status(404).json({ error: "Experience not found" }); return; }
    const imageUrl = await saveUploadedFile(
      req.file,
      createObjectName("portfolio", req.file.originalname, req.user!.id),
    );
    const { caption } = req.body;
    const maxSort = await prisma.portfolioExperienceImage.findFirst({
      where: { experienceId: experience.id },
      orderBy: { sortOrder: "desc" }
    });
    const image = await prisma.portfolioExperienceImage.create({
      data: {
        experienceId: experience.id,
        url: imageUrl,
        caption: caption || null,
        sortOrder: (maxSort?.sortOrder || 0) + 1
      }
    });
    res.status(201).json(image);
  } catch (err) {
    console.error("Add experience image error:", err);
    res.status(500).json({ error: "Failed to add image" });
  }
});

// DELETE /portfolio/experiences/:id/images/:imageId - delete experience image
router.delete("/experiences/:id/images/:imageId", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioExperienceImage.delete({ where: { id: String(req.params.imageId) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete image" });
  }
});

// POST /portfolio/education
router.post("/education", ...auth, async (req: AuthRequest, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({ where: { userId: req.user!.id } });
    if (!portfolio) { res.status(400).json({ error: "Create portfolio first" }); return; }
    const { institution, degree, field, startYear, endYear, description, imageUrl } = req.body;
    const edu = await prisma.portfolioEducation.create({ data: { portfolioId: portfolio.id, institution, degree, field, startYear, endYear, description, imageUrl: sanitizeAssetUrl(imageUrl) } });
    res.status(201).json(edu);
  } catch (err) {
    res.status(500).json({ error: "Failed to add education" });
  }
});

// PUT /portfolio/education/:id
router.put("/education/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const { institution, degree, field, startYear, endYear, description, imageUrl } = req.body;
    const edu = await prisma.portfolioEducation.update({
      where: { id: String(req.params.id) },
      data: {
        institution,
        degree,
        field,
        startYear,
        endYear,
        description,
        imageUrl: sanitizeAssetUrl(imageUrl),
      },
    });
    res.json(edu);
  } catch (err) {
    console.error("Update education error:", err);
    res.status(500).json({ error: "Failed to update education" });
  }
});

// POST /portfolio/education/:id/image - upload or replace education image
router.post("/education/:id/image", ...auth, upload.single("image"), async (req: AuthRequest, res) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: "Image is required" });
      return;
    }

    const edu = await prisma.portfolioEducation.findUnique({
      where: { id: String(req.params.id) },
    });
    if (!edu) {
      res.status(404).json({ error: "Education entry not found" });
      return;
    }

    const imageUrl = await saveUploadedFile(
      req.file,
      createObjectName("portfolio", req.file.originalname, req.user!.id),
    );

    const updated = await prisma.portfolioEducation.update({
      where: { id: edu.id },
      data: { imageUrl },
    });

    res.status(201).json({
      id: updated.id,
      url: updated.imageUrl,
    });
  } catch (err) {
    console.error("Upload education image error:", err);
    res.status(500).json({ error: "Failed to upload education image" });
  }
});

// DELETE /portfolio/education/:id/image - remove education image
router.delete("/education/:id/image", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioEducation.update({
      where: { id: String(req.params.id) },
      data: { imageUrl: null },
    });
    res.json({ message: "Deleted" });
  } catch (err) {
    console.error("Delete education image error:", err);
    res.status(500).json({ error: "Failed to delete education image" });
  }
});

// DELETE /portfolio/education/:id
router.delete("/education/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioEducation.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete" });
  }
});

// POST /portfolio/projects
router.post("/projects", ...auth, async (req: AuthRequest, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({ where: { userId: req.user!.id } });
    if (!portfolio) { res.status(400).json({ error: "Create portfolio first" }); return; }
    const { title, description, url, imageUrl, tags } = req.body;
    console.log("Creating project with data:", { portfolioId: portfolio.id, title, description, url, imageUrl, tags });
    const tagsStr = Array.isArray(tags) ? tags.join(",") : (tags || null);
    const project = await prisma.portfolioProject.create({ data: { portfolioId: portfolio.id, title, description, url, imageUrl: sanitizeAssetUrl(imageUrl), tags: tagsStr } });
    res.status(201).json(project);
  } catch (err) {
    console.error("Add project error:", err);
    res.status(500).json({ error: "Failed to add project" });
  }
});

// PUT /portfolio/projects/:id
router.put("/projects/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const { title, description, url, imageUrl, tags } = req.body;
    const tagsStr = Array.isArray(tags) ? tags.join(", ") : (tags || null);
    const project = await prisma.portfolioProject.update({
      where: { id: String(req.params.id) },
      data: { title, description, url, imageUrl: sanitizeAssetUrl(imageUrl), tags: tagsStr },
    });
    res.json(project);
  } catch (err) {
    res.status(500).json({ error: "Failed to update project" });
  }
});

// DELETE /portfolio/projects/:id
router.delete("/projects/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioProject.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete" });
  }
});

// POST /portfolio/projects/:id/images - add image to project
router.post("/projects/:id/images", ...auth, upload.single("image"), async (req: AuthRequest, res) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: "Image is required" });
      return;
    }
    const project = await prisma.portfolioProject.findUnique({ where: { id: String(req.params.id) } });
    if (!project) { res.status(404).json({ error: "Project not found" }); return; }
    const imageUrl = await saveUploadedFile(
      req.file,
      createObjectName("portfolio", req.file.originalname, req.user!.id),
    );
    const { caption } = req.body;
    const maxSort = await prisma.portfolioProjectImage.findFirst({
      where: { projectId: project.id },
      orderBy: { sortOrder: "desc" }
    });
    const image = await prisma.portfolioProjectImage.create({
      data: {
        projectId: project.id,
        url: imageUrl,
        caption: caption || null,
        sortOrder: (maxSort?.sortOrder || 0) + 1
      }
    });
    res.status(201).json(image);
  } catch (err) {
    console.error("Add project image error:", err);
    res.status(500).json({ error: "Failed to add image" });
  }
});

// DELETE /portfolio/projects/:id/images/:imageId - delete project image
router.delete("/projects/:id/images/:imageId", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.portfolioProjectImage.delete({ where: { id: String(req.params.imageId) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete image" });
  }
});

// GET /portfolio/public/:slug — public portfolio view
router.get("/public/:slug", async (req, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({
      where: { slug: req.params.slug, isPublic: true },
      include: {
        user: { select: { firstName: true, lastName: true, profileImage: true, bio: true, email: true, phone: true, profile: { select: { stateOfOrigin: true, localGovernment: true, dateOfBirth: true, gender: true } } } },
        galleryImages: { orderBy: { sortOrder: "asc" } },
        skills: { orderBy: { sortOrder: "asc" } },
        experiences: { include: { images: { orderBy: { sortOrder: "asc" } } }, orderBy: { sortOrder: "asc" } },
        education: { orderBy: { sortOrder: "asc" } },
        projects: { include: { images: { orderBy: { sortOrder: "asc" } } }, orderBy: { sortOrder: "asc" } },
      },
    });
    if (!portfolio) { res.status(404).json({ error: "Portfolio not found" }); return; }
    const books = await prisma.book.findMany({
      where: { userId: portfolio.userId },
      orderBy: { sortOrder: "asc" },
    });
    res.json({ ...normalizePortfolioForResponse(portfolio), books });
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch portfolio" });
  }
});

// GET /portfolio/public/resume/:slug — public resume view
router.get("/public/resume/:slug", async (req, res) => {
  try {
    const portfolio = await prisma.portfolio.findUnique({
      where: { slug: req.params.slug, isPublic: true },
      include: {
        user: { select: { firstName: true, lastName: true, profileImage: true, bio: true, email: true, phone: true, profile: { select: { stateOfOrigin: true, localGovernment: true, dateOfBirth: true, gender: true } } } },
        skills: { orderBy: { sortOrder: "asc" } },
        experiences: { include: { images: { orderBy: { sortOrder: "asc" } } }, orderBy: { sortOrder: "asc" } },
        education: { orderBy: { sortOrder: "asc" } },
        projects: { include: { images: { orderBy: { sortOrder: "asc" } } }, orderBy: { sortOrder: "asc" } },
      },
    });
    if (!portfolio) { res.status(404).json({ error: "Portfolio not found" }); return; }
    res.json(normalizePortfolioForResponse(portfolio));
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch resume" });
  }
});

// POST /portfolio/public/:slug/contact — public contact form
router.post("/public/:slug/contact", async (req, res) => {
  try {
    const slug = String(req.params.slug);
    const portfolio = await prisma.portfolio.findUnique({ where: { slug } });
    if (!portfolio || !portfolio.isPublic) { res.status(404).json({ error: "Portfolio not found" }); return; }
    const { name, email, message } = req.body;
    if (!name?.trim() || !email?.trim() || !message?.trim()) {
      res.status(400).json({ error: "Name, email, and message are required" }); return;
    }
    // Save public message
    await prisma.portfolioPublicMessage.create({ data: { portfolioId: portfolio.id, name: name.trim(), email: email.trim(), message: message.trim() } });
    // Also create internal message for the user
    await prisma.internalMessage.create({
      data: {
        senderId: portfolio.userId,
        subject: `Portfolio message from ${name.trim()}`,
        body: `From: ${name.trim()} <${email.trim()}>\n\n${message.trim()}`,
        isFromGuest: true,
        guestName: name.trim(),
        guestEmail: email.trim(),
        recipients: { create: { userId: portfolio.userId, folder: "inbox" } },
      },
    });
    // Create notification for the portfolio owner
    await prisma.notification.create({
      data: {
        userId: portfolio.userId,
        title: "New Portfolio Message",
        body: `${name.trim()} sent you a message via your portfolio`,
        type: "message",
        link: "/dashboard/messages",
      },
    });
    // Send push notification
    sendPushNotification(portfolio.userId, "New Portfolio Message", `${name.trim()} sent you a message via your portfolio`, "/dashboard/messages");
    res.status(201).json({ message: "Message sent successfully" });
  } catch (err) {
    console.error("Public contact error:", err);
    res.status(500).json({ error: "Failed to send message" });
  }
});

export default router;

import { Router } from "express";
import multer from "multer";
import prisma from "../lib/prisma";
import { createMemoryUpload, createObjectName, saveUploadedFile } from "../lib/uploadStorage";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];
const upload = createMemoryUpload({
  errorMessage: "Only image uploads are allowed",
  fileSize: 5 * 1024 * 1024,
  accept: (mimetype, originalName) => {
    if (mimetype.startsWith("image/")) return true;
    return /\.(png|jpe?g|webp|gif|heic|heif)$/i.test(originalName.toLowerCase());
  },
});

// GET /profile — get own full profile
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      include: { profile: { include: { identifyingMarks: true } }, badges: true },
    });
    if (!user) { res.status(404).json({ error: "User not found" }); return; }
    const { password, profile, badges, ...safeUser } = user;
    res.json({ user: safeUser, profile, badges });
  } catch (err) {
    console.error("Get profile error:", err);
    res.status(500).json({ error: "Failed to fetch profile" });
  }
});

// PUT /profile — update own profile
router.put("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const userId = req.user!.id;
    const {
      preferredName, gender, dateOfBirth, placeOfBirth, nationality,
      stateOfOrigin, localGovernment, religion, maritalStatus,
      height, lastWeight, skinTone, bloodGroup, genotype,
      waistSize, trouserLength, shoeSize, shirtSize,
      drinkAlcohol, smoke, bestMeals, languages,
      socialLinks, emergencyContact, customFields, fieldVisibility,
    } = req.body;

    const profile = await prisma.userProfile.upsert({
      where: { userId },
      create: {
        userId, preferredName, gender, dateOfBirth, placeOfBirth, nationality,
        stateOfOrigin, localGovernment, religion, maritalStatus,
        height, lastWeight, skinTone, bloodGroup, genotype,
        waistSize, trouserLength, shoeSize, shirtSize,
        drinkAlcohol, smoke, bestMeals, languages,
        socialLinks: socialLinks ? JSON.stringify(socialLinks) : undefined,
        emergencyContact: emergencyContact ? JSON.stringify(emergencyContact) : undefined,
        customFields: customFields ? JSON.stringify(customFields) : undefined,
        fieldVisibility: fieldVisibility ? JSON.stringify(fieldVisibility) : undefined,
      },
      update: {
        preferredName, gender, dateOfBirth, placeOfBirth, nationality,
        stateOfOrigin, localGovernment, religion, maritalStatus,
        height, lastWeight, skinTone, bloodGroup, genotype,
        waistSize, trouserLength, shoeSize, shirtSize,
        drinkAlcohol, smoke, bestMeals, languages,
        socialLinks: socialLinks ? JSON.stringify(socialLinks) : undefined,
        emergencyContact: emergencyContact ? JSON.stringify(emergencyContact) : undefined,
        customFields: customFields ? JSON.stringify(customFields) : undefined,
        fieldVisibility: fieldVisibility ? JSON.stringify(fieldVisibility) : undefined,
      },
    });
    res.json(profile);
  } catch (err) {
    console.error("Update profile error:", err);
    res.status(500).json({ error: "Failed to update profile" });
  }
});

// PUT /profile/user — update basic user fields (firstName, lastName, phone, location, bio, username)
router.put("/user", ...auth, async (req: AuthRequest, res) => {
  try {
    const { firstName, lastName, phone, location, bio, username } = req.body;
    const user = await prisma.user.update({
      where: { id: req.user!.id },
      data: { firstName, lastName, phone, location, bio, username },
    });
    const { password, ...safe } = user;
    res.json(safe);
  } catch (err) {
    console.error("Update user error:", err);
    res.status(500).json({ error: "Failed to update user info" });
  }
});

// POST /profile/avatar — upload profile image
router.post("/avatar", ...auth, (req: AuthRequest, res) => {
  upload.single("avatar")(req as any, res as any, async (uploadErr: any) => {
    if (uploadErr) {
      if (uploadErr instanceof multer.MulterError && uploadErr.code === "LIMIT_FILE_SIZE") {
        res.status(413).json({ error: "Image is too large. Please upload an image under 5MB." });
        return;
      }

      const message = uploadErr?.message || "Invalid image upload";
      res.status(400).json({ error: message });
      return;
    }

    try {
      if (!req.file) {
        res.status(400).json({ error: "Avatar image is required" });
        return;
      }

      const profileImage = await saveUploadedFile(
        req.file,
        createObjectName("avatars", req.file.originalname, req.user!.id),
      );
      const user = await prisma.user.update({
        where: { id: req.user!.id },
        data: { profileImage },
        select: { id: true, profileImage: true },
      });

      res.json(user);
    } catch (err) {
      console.error("Upload avatar error:", err);
      res.status(500).json({ error: "Failed to upload avatar" });
    }
  });
});

// GET /profile/:userId — get another member's profile (family-visible fields)
router.get("/:userId", ...auth, async (req: AuthRequest, res) => {
  try {
    const userId = String(req.params.userId);
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, badges: true },
    });
    if (!user) { res.status(404).json({ error: "Member not found" }); return; }
    const { password, ...safe } = user;
    res.json(safe);
  } catch (err) {
    console.error("Get member profile error:", err);
    res.status(500).json({ error: "Failed to fetch member profile" });
  }
});

// POST /profile/identifying-marks — add identifying mark
router.post("/identifying-marks", ...auth, async (req: AuthRequest, res) => {
  try {
    const profile = await prisma.userProfile.findUnique({ where: { userId: req.user!.id } });
    if (!profile) { res.status(400).json({ error: "Create your profile first" }); return; }
    const { type, description, imageUrl } = req.body;
    const mark = await prisma.profileIdentifyingMark.create({
      data: { profileId: profile.id, type, description, imageUrl },
    });
    res.status(201).json(mark);
  } catch (err) {
    console.error("Add mark error:", err);
    res.status(500).json({ error: "Failed to add identifying mark" });
  }
});

// DELETE /profile/identifying-marks/:id
router.delete("/identifying-marks/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    await prisma.profileIdentifyingMark.delete({ where: { id } });
    res.json({ message: "Mark deleted" });
  } catch (err) {
    console.error("Delete mark error:", err);
    res.status(500).json({ error: "Failed to delete mark" });
  }
});

export default router;

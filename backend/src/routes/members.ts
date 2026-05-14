import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireAdmin, AuthRequest } from "../middleware/auth";
import type { Prisma } from "@prisma/client";

const router = Router();

// GET /api/members/stats — must be before /:id
router.get("/stats", authenticate as any, requireAdmin as any, async (_req: AuthRequest, res) => {
  try {
    const [total, pending, approved, rejected] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { status: "pending" } }),
      prisma.user.count({ where: { status: "approved" } }),
      prisma.user.count({ where: { status: "rejected" } }),
    ]);
    const branches = await prisma.user.findMany({ where: { branchId: { not: null } }, select: { branchId: true }, distinct: ["branchId"] });
    res.json({ total, pending, approved, rejected, branches: branches.length });
  } catch (err) {
    console.error("Stats error:", err);
    res.status(500).json({ error: "Failed to fetch stats" });
  }
});

// GET /api/members
router.get("/", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const { status, role, search, page = "1", limit = "20" } = req.query;
    const where: Prisma.UserWhereInput = {};

    if (status) where.status = status as any;
    if (role) where.role = role as any;
    if (search) {
      const query = search as string;
      where.OR = [
        { firstName: { contains: query } },
        { lastName: { contains: query } },
        { email: { contains: query } },
      ];
    }

    const p = parseInt(page as string);
    const l = parseInt(limit as string);
    const total = await prisma.user.count({ where });
    const members = await prisma.user.findMany({
      where,
      select: { id: true, firstName: true, lastName: true, email: true, phone: true, location: true, branch: true, relationship: true, role: true, status: true, createdAt: true },
      orderBy: { createdAt: "desc" },
      skip: (p - 1) * l,
      take: l,
    });

    res.json({ members, total, page: p, pages: Math.ceil(total / l) });
  } catch (err) {
    console.error("List members error:", err);
    res.status(500).json({ error: "Failed to fetch members" });
  }
});

// GET /api/members/:id
router.get("/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const member = await prisma.user.findUnique({
      where: { id },
      select: { id: true, firstName: true, lastName: true, email: true, phone: true, location: true, branch: true, relationship: true, role: true, status: true, bio: true, createdAt: true },
    });
    if (!member) { res.status(404).json({ error: "Member not found" }); return; }
    res.json({ member });
  } catch (err) {
    console.error("Get member error:", err);
    res.status(500).json({ error: "Failed to fetch member" });
  }
});

// PATCH /api/members/:id
router.patch("/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { firstName, lastName, email, phone, location, branchId, relationship, role, bio, profileImage } = req.body;
    
    const member = await prisma.user.update({
      where: { id },
      data: {
        ...(firstName !== undefined && { firstName }),
        ...(lastName !== undefined && { lastName }),
        ...(email !== undefined && { email }),
        ...(phone !== undefined && { phone }),
        ...(location !== undefined && { location }),
        ...(branchId !== undefined && { branchId: branchId || null }),
        ...(relationship !== undefined && { relationship }),
        ...(role !== undefined && { role }),
        ...(bio !== undefined && { bio }),
        ...(profileImage !== undefined && { profileImage }),
      },
      select: { id: true, firstName: true, lastName: true, email: true, role: true, status: true, branchId: true, branch: true },
    });
    res.json({ member });
  } catch (err) {
    console.error("Update member error:", err);
    res.status(500).json({ error: "Failed to update member" });
  }
});

// PATCH /api/members/:id/status
router.patch("/:id/status", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { status } = req.body;
    if (!["pending", "approved", "rejected", "suspended"].includes(status)) {
      res.status(400).json({ error: "Invalid status" }); return;
    }
    const member = await prisma.user.update({
      where: { id },
      data: { status },
      select: { id: true, firstName: true, lastName: true, email: true, role: true, status: true },
    });
    res.json({ member });
  } catch (err) {
    console.error("Update status error:", err);
    res.status(500).json({ error: "Failed to update member status" });
  }
});

// DELETE /api/members/:id
router.delete("/:id", authenticate as any, requireAdmin as any, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    await prisma.user.delete({ where: { id } });
    res.json({ message: "Member deleted" });
  } catch (err) {
    console.error("Delete member error:", err);
    res.status(500).json({ error: "Failed to delete member" });
  }
});

export default router;

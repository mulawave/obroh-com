import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, requireAdmin, AuthRequest } from "../middleware/auth";

const router = Router();
const adminAuth: any[] = [authenticate as any, requireApproved as any, requireAdmin as any];

// GET /api/roles - Get all roles with member counts
router.get("/", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const roles = await prisma.role.findMany({
      orderBy: { createdAt: "asc" },
    });

    const users = await prisma.user.findMany({
      select: { role: true },
      take: 10000,
    });

    const roleCounts = users.reduce((acc, user) => {
      acc[user.role] = (acc[user.role] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const rolesWithCounts = roles.map((role) => ({
      ...role,
      permissions: JSON.parse(role.permissions),
      memberCount: roleCounts[role.name] || 0,
    }));

    res.json({ roles: rolesWithCounts, total: rolesWithCounts.length });
  } catch (err) {
    console.error("Roles fetch error:", err);
    res.status(500).json({ error: "Failed to load roles" });
  }
});

// GET /api/roles/members - Get all members with their roles
router.get("/members", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const members = await prisma.user.findMany({
      where: { status: "approved" },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
        role: true,
        status: true,
      },
      orderBy: { createdAt: "desc" },
    });

    res.json({ members, total: members.length });
  } catch (err) {
    console.error("Members fetch error:", err);
    res.status(500).json({ error: "Failed to load members" });
  }
});

// POST /api/roles - Create new role
router.post("/", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const { name, description, permissions } = req.body;

    if (!name || !permissions || !Array.isArray(permissions)) {
      res.status(400).json({ error: "Name and permissions array are required" });
      return;
    }

    const role = await prisma.role.create({
      data: {
        name,
        description,
        permissions: JSON.stringify(permissions),
      },
    });

    res.status(201).json({ ...role, permissions: JSON.parse(role.permissions) });
  } catch (err) {
    console.error("Create role error:", err);
    res.status(500).json({ error: "Failed to create role" });
  }
});

// PUT /api/roles/:id - Update role
router.put("/:id", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const { name, description, permissions } = req.body;

    const role = await prisma.role.update({
      where: { id },
      data: {
        name,
        description,
        permissions: JSON.stringify(permissions),
      },
    });

    res.json({ ...role, permissions: JSON.parse(role.permissions) });
  } catch (err) {
    console.error("Update role error:", err);
    res.status(500).json({ error: "Failed to update role" });
  }
});

// DELETE /api/roles/:id - Delete role
router.delete("/:id", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);

    const role = await prisma.role.findUnique({ where: { id } });
    if (!role) {
      res.status(404).json({ error: "Role not found" });
      return;
    }

    if (role.isSystem) {
      res.status(400).json({ error: "Cannot delete system roles" });
      return;
    }

    await prisma.role.delete({ where: { id } });
    res.json({ message: "Role deleted" });
  } catch (err) {
    console.error("Delete role error:", err);
    res.status(500).json({ error: "Failed to delete role" });
  }
});

// PATCH /api/roles/user/:userId - Update user role
router.patch("/user/:userId", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const userId = String(req.params.userId);
    const { role } = req.body;

    const validRole = await prisma.role.findUnique({ where: { name: role } });
    if (!validRole) {
      res.status(400).json({ error: "Invalid role" });
      return;
    }

    const user = await prisma.user.update({
      where: { id: userId },
      data: { role },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
        role: true,
      },
    });

    res.json(user);
  } catch (err) {
    console.error("Update user role error:", err);
    res.status(500).json({ error: "Failed to update user role" });
  }
});

// POST /api/roles/seed - Seed default roles
router.post("/seed", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const defaultRoles = [
      {
        name: "superadmin",
        description: "Full system access",
        permissions: JSON.stringify(["all"]),
        isSystem: true,
      },
      {
        name: "admin",
        description: "Administrative access",
        permissions: JSON.stringify(["manage_members", "manage_content", "view_analytics", "manage_roles"]),
        isSystem: true,
      },
      {
        name: "moderator",
        description: "Content moderation access",
        permissions: JSON.stringify(["manage_content", "view_analytics"]),
        isSystem: true,
      },
      {
        name: "member",
        description: "Standard member access",
        permissions: JSON.stringify(["view_content", "create_posts"]),
        isSystem: true,
      },
    ];

    for (const role of defaultRoles) {
      await prisma.role.upsert({
        where: { name: role.name },
        update: role,
        create: role,
      });
    }

    res.json({ message: "Default roles seeded successfully" });
  } catch (err) {
    console.error("Seed roles error:", err);
    res.status(500).json({ error: "Failed to seed roles" });
  }
});

export default router;

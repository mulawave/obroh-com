import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import type { SignOptions } from "jsonwebtoken";
import { Prisma } from "@prisma/client";
import prisma from "../lib/prisma";
import { authenticate, AuthRequest } from "../middleware/auth";
import { createRefreshToken, verifyRefreshToken, revokeRefreshToken } from "../lib/refreshTokens";

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || "obroh-dynasty-secret-key-2024-dev";

function signToken(userId: string) {
  const options: SignOptions = { expiresIn: (process.env.JWT_EXPIRES_IN || "7d") as SignOptions["expiresIn"] };
  return jwt.sign({ userId }, JWT_SECRET, options);
}

async function tryCreateRefreshToken(userId: string): Promise<string | null> {
  try {
    return await createRefreshToken(userId, 90);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2021") {
      console.warn("Refresh token table missing; continuing login without refresh token");
      return null;
    }
    throw err;
  }
}

// POST /api/auth/register
router.post("/register", async (req, res) => {
  try {
    const { firstName, lastName, email, phone, location, password, branch, relationship } = req.body;
    if (!firstName || !lastName || !email || !password) {
      res.status(400).json({ error: "First name, last name, email, and password are required" });
      return;
    }

    const existing = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
    if (existing) {
      res.status(409).json({ error: "An account with this email already exists" });
      return;
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const user = await prisma.user.create({
      data: { firstName, lastName, email: email.toLowerCase(), phone, location, password: hashedPassword, branch, relationship },
    });

    res.status(201).json({
      message: "Membership request submitted successfully. Your application will be reviewed by the Council of Elders.",
      userId: user.id,
    });
  } catch (err) {
    console.error("Register error:", err);
    res.status(500).json({ error: "Registration failed. Please try again." });
  }
});

// POST /api/auth/login
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      res.status(400).json({ error: "Email and password are required" });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: { badges: { select: { label: true, icon: true } } },
    });
    if (!user) {
      res.status(401).json({ error: "Invalid email or password" });
      return;
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      res.status(401).json({ error: "Invalid email or password" });
      return;
    }

    if (user.status !== "approved" && user.role !== "admin" && user.role !== "superadmin") {
      res.status(403).json({ error: `Your account is ${user.status}. Please contact the Council of Elders.` });
      return;
    }

    const token = signToken(user.id);
    const refreshToken = await tryCreateRefreshToken(user.id);
    res.json({
      token,
      refreshToken,
      user: {
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        role: user.role,
        status: user.status,
        profileImage: user.profileImage,
        bio: user.bio,
        username: user.username,
        phone: user.phone,
        location: user.location,
        branchId: user.branchId,
        badges: user.badges,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: "Login failed. Please try again." });
  }
});

// POST /api/auth/admin-login
router.post("/admin-login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      res.status(400).json({ error: "Email and password are required" });
      return;
    }

    const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
    if (!user || !["admin", "superadmin"].includes(user.role)) {
      res.status(401).json({ error: "Invalid credentials or insufficient privileges" });
      return;
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      res.status(401).json({ error: "Invalid credentials or insufficient privileges" });
      return;
    }

    const token = signToken(user.id);
    const refreshToken = await tryCreateRefreshToken(user.id);
    res.json({
      token,
      refreshToken,
      user: { id: user.id, firstName: user.firstName, lastName: user.lastName, email: user.email, role: user.role },
    });
  } catch (err) {
    console.error("Admin login error:", err);
    res.status(500).json({ error: "Login failed. Please try again." });
  }
});

// POST /api/auth/refresh
router.post("/refresh", async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      res.status(400).json({ error: "Refresh token is required" });
      return;
    }

    const userId = await verifyRefreshToken(refreshToken);
    if (!userId) {
      res.status(401).json({ error: "Invalid or expired refresh token" });
      return;
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || (user.status !== "approved" && user.role !== "admin" && user.role !== "superadmin")) {
      res.status(401).json({ error: "User not found or inactive" });
      return;
    }

    const newAccessToken = signToken(userId);
    res.json({ token: newAccessToken });
  } catch (err) {
    console.error("Refresh error:", err);
    res.status(500).json({ error: "Token refresh failed" });
  }
});

// POST /api/auth/logout
router.post("/logout", authenticate as any, async (req: AuthRequest, res) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await revokeRefreshToken(refreshToken);
    }
    res.json({ message: "Logged out successfully" });
  } catch (err) {
    console.error("Logout error:", err);
    res.status(500).json({ error: "Logout failed" });
  }
});

// GET /api/auth/me
router.get("/me", authenticate as any, async (req: AuthRequest, res) => {
  const u = await prisma.user.findUnique({
    where: { id: req.user!.id },
    include: {
      badges: { select: { label: true, icon: true } },
      branch: { select: { id: true, name: true } },
    },
  });
  if (!u) {
    res.status(401).json({ error: "User not found" });
    return;
  }
  res.json({
    user: {
      id: u.id,
      firstName: u.firstName,
      lastName: u.lastName,
      email: u.email,
      role: u.role,
      status: u.status,
      profileImage: u.profileImage,
      bio: u.bio,
      username: u.username,
      phone: u.phone,
      location: u.location,
      branchId: u.branchId,
      branch: u.branch,
      badges: u.badges,
    },
  });
});

export default router;

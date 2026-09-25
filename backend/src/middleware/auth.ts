import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import prisma from "../lib/prisma";
import { JWT_SECRET } from "../lib/jwtSecret";
import type { User } from "@prisma/client";

export interface AuthRequest extends Request {
  user?: User;
}

export const authenticate = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const token = req.headers.authorization?.replace("Bearer ", "");
    if (!token) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }

    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
    if (!user) {
      res.status(401).json({ error: "User not found" });
      return;
    }

    req.user = user;
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
};

export const requireAdmin = (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.user || !["admin", "superadmin"].includes(req.user.role)) {
    res.status(403).json({ error: "Admin access required" });
    return;
  }
  next();
};

export const requireApproved = (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.user) {
    res.status(401).json({ error: "Authentication required" });
    return;
  }
  if (req.user.status !== "approved" && !["admin", "superadmin"].includes(req.user.role)) {
    res.status(403).json({ error: "Your account is not yet approved" });
    return;
  }
  next();
};

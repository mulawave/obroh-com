import "./lib/asyncErrors";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import dotenv from "dotenv";
import path from "path";
import prisma from "./lib/prisma";
import { streamUploadedFile } from "./lib/uploadStorage";

import authRoutes from "./routes/auth";
import memberRoutes from "./routes/members";
import familyTreeRoutes from "./routes/familyTree";
import knowledgeBaseRoutes from "./routes/knowledgeBase";
import legacyRoutes from "./routes/legacy";
import contactRoutes from "./routes/contact";
import contentRoutes from "./routes/content";
import profileRoutes from "./routes/profile";
import timelineRoutes from "./routes/timeline";
import messagingRoutes from "./routes/messaging";
import portfolioRoutes from "./routes/portfolio";
import biographyRoutes from "./routes/biographyRoutes";
import lineageRoutes from "./routes/lineage";
import legalRoutes from "./routes/legal";
import notificationRoutes from "./routes/notifications";
import fcmRoutes from "./routes/fcm";
import analyticsRoutes from "./routes/analytics";
import rolesRoutes from "./routes/roles";
import settingsRoutes from "./routes/settings";
import booksRoutes from "./routes/books";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));
app.use(cors({
  origin: (origin, callback) => {
    if (!origin) {
      callback(null, true);
      return;
    }

    const configuredOrigins = (process.env.ALLOWED_ORIGINS || "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);

    const allowedOrigins = [
      "https://obroh.com",
      "https://www.obroh.com",
      process.env.WEBSITE_URL || "http://localhost:3000",
      process.env.ADMIN_URL || "http://localhost:3001",
      ...configuredOrigins,
    ];

    if (
      allowedOrigins.includes(origin) ||
      /^https:\/\/(.+\.)?obroh\.com$/.test(origin) ||
      /^http:\/\/localhost:\d+$/.test(origin) ||
      /^http:\/\/127\.0\.0\.1:\d+$/.test(origin)
    ) {
      callback(null, true);
      return;
    }

    // Do not throw hard errors for unknown origins; just deny CORS headers.
    // Throwing here can surface as opaque 500s in browsers.
    callback(null, false);
  },
  credentials: true,
}));
// Cloud Run already logs every request; in production only add lines for failures
// to keep Cloud Logging volume (shared project quota) down.
app.use(process.env.NODE_ENV === "production"
  ? morgan("tiny", { skip: (_req, res) => res.statusCode < 400 })
  : morgan("dev"));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Serve uploads with CORS headers
app.use("/uploads", (req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  res.header("Cross-Origin-Resource-Policy", "cross-origin");
  next();
}, streamUploadedFile, express.static(path.join(process.cwd(), "uploads")));

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/members", memberRoutes);
app.use("/api/family-tree", familyTreeRoutes);
app.use("/api/knowledge-base", knowledgeBaseRoutes);
app.use("/api/legacy", legacyRoutes);
app.use("/api/contact", contactRoutes);
app.use("/api/content", contentRoutes);
app.use("/api/profile", profileRoutes);
app.use("/api/timeline", timelineRoutes);
app.use("/api/messages", messagingRoutes);
app.use("/api/portfolio", portfolioRoutes);
app.use("/api/biography", biographyRoutes);
app.use("/api/lineage", lineageRoutes);
app.use("/api/legal", legalRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/fcm", fcmRoutes);
app.use("/api/analytics", analyticsRoutes);
app.use("/api/roles", rolesRoutes);
app.use("/api/settings", settingsRoutes);
app.use("/api/books", booksRoutes);

// Serve static files from public directory
app.use(express.static(path.join(process.cwd(), "public")));

// Health check
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", service: "Obroh Ancestry API", timestamp: new Date().toISOString() });
});

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: "Endpoint not found" });
});

// Error handler. CORS headers are already set by the cors() middleware above,
// which runs before every route. Async route errors reach here via lib/asyncErrors.
app.use((err: Error, _req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error("Unhandled error:", err);
  if (res.headersSent) {
    next(err);
    return;
  }
  res.status(500).json({ error: "Internal server error" });
});

// Backstop for rejections outside the request cycle (timers, fire-and-forget calls).
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled promise rejection:", reason);
});
// State is unknown after a synchronous crash: log and exit so Cloud Run restarts cleanly.
process.on("uncaughtException", (err) => {
  console.error("Uncaught exception:", err);
  process.exit(1);
});

// Start server
const startServer = async () => {
  try {
    await prisma.$connect();
    console.log("Connected to database");

    app.listen(PORT, () => {
      console.log(`Obroh API running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
};

startServer();

export default app;

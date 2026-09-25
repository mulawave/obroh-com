import { Storage } from "@google-cloud/storage";
import type { NextFunction, Request, Response } from "express";
import fs from "fs";
import multer from "multer";
import path from "path";

const uploadsRoot = path.join(process.cwd(), "uploads");
const bucketName = process.env.GCS_BUCKET;
const isProduction = process.env.NODE_ENV === "production";
const storage = bucketName ? new Storage() : null;
const bucket = bucketName ? storage!.bucket(bucketName) : null;

type UploadOptions = {
  errorMessage: string;
  fileSize: number;
  files?: number;
  accept: (mimetype: string, originalName: string) => boolean;
};

function inferContentTypeFromPath(filePath: string) {
  const ext = path.extname(filePath).toLowerCase();
  // Images
  if (ext === ".png") return "image/png";
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".webp") return "image/webp";
  if (ext === ".gif") return "image/gif";
  if (ext === ".svg") return "image/svg+xml";
  if (ext === ".avif") return "image/avif";
  // Videos
  if (ext === ".mp4") return "video/mp4";
  if (ext === ".webm") return "video/webm";
  if (ext === ".mov") return "video/quicktime";
  if (ext === ".m4v") return "video/x-m4v";
  if (ext === ".mkv") return "video/x-matroska";
  if (ext === ".avi") return "video/x-msvideo";
  return null;
}

function isLikelyImagePath(filePath: string) {
  return /\.(png|jpe?g|webp|gif|svg|avif)$/i.test(filePath);
}

function isLikelyVideoPath(filePath: string) {
  return /\.(mp4|webm|mov|m4v|mkv|avi)$/i.test(filePath);
}

function normalizeUploadPath(uploadPath: string) {
  return uploadPath.replace(/^\/+/, "").replace(/^uploads\//, "");
}

function assertPersistentUploadStorage(operation: string) {
  if (isProduction && !bucket) {
    throw new Error(
      `GCS_BUCKET must be configured in production before ${operation}. ` +
      "Local filesystem uploads are ephemeral on Cloud Run."
    );
  }
}

export function createMemoryUpload(options: UploadOptions) {
  return multer({
    storage: multer.memoryStorage(),
    fileFilter: (_req, file, cb) => {
      if (!options.accept(file.mimetype, file.originalname)) {
        cb(new Error(options.errorMessage));
        return;
      }

      cb(null, true);
    },
    limits: {
      fileSize: options.fileSize,
      ...(options.files ? { files: options.files } : {}),
    },
  });
}

const UPLOAD_CACHE_CONTROL = "public, max-age=31536000, immutable";

export function buildStoredObjectPath(folder: string, filename: string) {
  return `${folder.replace(/^\/+|\/+$/g, "")}/${filename}`;
}

export function createObjectName(prefix: string, originalName: string, ownerId?: string) {
  const ext = path.extname(originalName).toLowerCase();
  const unique = Math.random().toString(36).slice(2, 8);
  const base = ownerId ? `${ownerId}-${Date.now()}-${unique}` : `${Date.now()}-${unique}`;
  return buildStoredObjectPath(prefix, `${base}${ext}`);
}

export function buildUploadUrl(objectPath: string) {
  return `/uploads/${normalizeUploadPath(objectPath)}`;
}

export async function saveUploadedFile(file: Express.Multer.File, objectPath: string) {
  const normalized = normalizeUploadPath(objectPath);

  assertPersistentUploadStorage("saving uploaded files");

  if (bucket) {
    const target = bucket.file(normalized);
    await target.save(file.buffer, {
      resumable: false,
      metadata: {
        contentType: file.mimetype,
        cacheControl: UPLOAD_CACHE_CONTROL,
      },
    });
    return buildUploadUrl(normalized);
  }

  const fullPath = path.join(uploadsRoot, normalized);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  await fs.promises.writeFile(fullPath, file.buffer);
  return buildUploadUrl(normalized);
}

export async function streamUploadedFile(req: Request, res: Response, next: NextFunction) {
  const normalized = normalizeUploadPath(req.path);

  if (!bucket) {
    if (isProduction) {
      res.status(500).json({
        error: "Persistent upload storage is not configured",
      });
      return;
    }

    next();
    return;
  }

  // getMetadata doubles as the existence check: one Storage call per request instead of two.
  const loadMetadata = async (objectPath: string) => {
    const target = bucket.file(objectPath);
    try {
      const [metadata] = await target.getMetadata();
      return { objectPath, target, metadata };
    } catch (error) {
      if ((error as { code?: number }).code === 404) return null;
      throw error;
    }
  };

  try {
    let found = await loadMetadata(normalized);

    // Backward-compatibility: older objects may have been stored as uploads/<path>.
    if (!found && !normalized.startsWith("uploads/")) {
      found = await loadMetadata(`uploads/${normalized}`);
    }

    if (!found) {
      res.status(404).json({ error: "File not found" });
      return;
    }

    const { objectPath, target, metadata } = found;
    const inferredContentType = inferContentTypeFromPath(objectPath);
    const contentType = metadata.contentType && metadata.contentType !== "application/octet-stream"
      ? metadata.contentType
      : inferredContentType;

    if (contentType) {
      res.setHeader("Content-Type", contentType);
      res.setHeader("Content-Disposition", "inline");
    }
    // Object names are unique per upload (createObjectName), so content never changes:
    // let browsers and the Firebase CDN keep it, instead of re-running Cloud Run per view.
    // Ignores older objects' stored 1-hour metadata on purpose.
    res.setHeader("Cache-Control", UPLOAD_CACHE_CONTROL);
    res.setHeader("Accept-Ranges", "bytes");

    target.createReadStream().on("error", next).pipe(res);
  } catch (error) {
    next(error);
  }
}
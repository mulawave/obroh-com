import express from "express";
import prisma from "../lib/prisma";
import { createMemoryUpload, createObjectName, saveUploadedFile } from "../lib/uploadStorage";
import { authenticate } from "../middleware/auth";
import type { AuthRequest } from "../middleware/auth";

const router = express.Router();
const pdfUpload = createMemoryUpload({
  errorMessage: "Only PDF files are allowed",
  fileSize: 50 * 1024 * 1024,
  accept: (mimetype) => mimetype === "application/pdf",
});

const coverUpload = createMemoryUpload({
  errorMessage: "Only image files are allowed",
  fileSize: 5 * 1024 * 1024,
  accept: (mimetype) => mimetype.startsWith("image/"),
});

// GET /api/books - Get all books for logged-in user
router.get("/", ...[authenticate], async (req: AuthRequest, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    const books = await prisma.book.findMany({
      where: { userId: req.user.id },
      orderBy: { sortOrder: "asc" },
    });
    res.json(books);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch books" });
  }
});

// GET /api/books/:id - Get a specific book
router.get("/:id", ...[authenticate], async (req: AuthRequest, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    const id = String(req.params.id);
    const book = await prisma.book.findFirst({
      where: { id, userId: req.user.id },
    });
    if (!book) {
      res.status(404).json({ error: "Book not found" });
      return;
    }
    res.json(book);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch book" });
  }
});

// POST /api/books - Create a new book
router.post("/", ...[authenticate], async (req: AuthRequest, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    const { title, synopsis, pdfUrl, coverImageUrl, purchaseLinks, sortOrder } = req.body;
    if (!title?.trim()) {
      res.status(400).json({ error: "Title is required" });
      return;
    }
    const book = await prisma.book.create({
      data: {
        userId: req.user.id,
        title: title.trim(),
        synopsis: synopsis?.trim() || null,
        pdfUrl: pdfUrl || null,
        coverImageUrl: coverImageUrl || null,
        purchaseLinks: purchaseLinks || null,
        sortOrder: sortOrder || 0,
      },
    });
    res.json(book);
  } catch (err) {
    res.status(500).json({ error: "Failed to create book" });
  }
});

// PUT /api/books/:id - Update a book
router.put("/:id", ...[authenticate], async (req: AuthRequest, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    const id = String(req.params.id);
    const { title, synopsis, pdfUrl, coverImageUrl, purchaseLinks, sortOrder } = req.body;
    const book = await prisma.book.update({
      where: { id },
      data: {
        title: title?.trim(),
        synopsis: synopsis?.trim() || null,
        pdfUrl: pdfUrl || null,
        coverImageUrl: coverImageUrl || null,
        purchaseLinks: purchaseLinks || null,
        sortOrder: sortOrder || 0,
      },
    });
    res.json(book);
  } catch (err) {
    res.status(500).json({ error: "Failed to update book" });
  }
});

// DELETE /api/books/:id - Delete a book
router.delete("/:id", ...[authenticate], async (req: AuthRequest, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    const id = String(req.params.id);
    await prisma.book.delete({ where: { id } });
    res.json({ message: "Book deleted successfully" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete book" });
  }
});

// POST /api/books/upload-pdf - Upload PDF file
router.post("/upload-pdf", authenticate, (req: AuthRequest, res, next) => {
  pdfUpload.single("file")(req, res, (err) => {
    if (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : "Upload failed" });
      return;
    }
    void (async () => {
      try {
        if (!req.file) {
          res.status(400).json({ error: "PDF file is required" });
          return;
        }

        const pdfUrl = await saveUploadedFile(
          req.file,
          createObjectName("books/pdfs", req.file.originalname, req.user?.id),
        );
        res.json({ url: pdfUrl });
      } catch (error) {
        next(error);
      }
    })();
  });
});

// POST /api/books/upload-cover - Upload cover image
router.post("/upload-cover", authenticate, (req: AuthRequest, res, next) => {
  coverUpload.single("file")(req, res, (err) => {
    if (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : "Upload failed" });
      return;
    }
    void (async () => {
      try {
        if (!req.file) {
          res.status(400).json({ error: "Image file is required" });
          return;
        }

        const coverUrl = await saveUploadedFile(
          req.file,
          createObjectName("books/covers", req.file.originalname, req.user?.id),
        );
        res.json({ url: coverUrl });
      } catch (error) {
        next(error);
      }
    })();
  });
});

export default router;

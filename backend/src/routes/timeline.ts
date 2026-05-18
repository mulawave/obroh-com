import { Router } from "express";
import multer from "multer";
import prisma from "../lib/prisma";
import { createMemoryUpload, createObjectName, saveUploadedFile } from "../lib/uploadStorage";
import { generateAndSaveThumbnail } from "../lib/thumbnailGenerator";
import { sendPushNotification, FCM_CHANNELS } from "../lib/fcm";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

function isSupportedMediaUpload(mimetype: string, originalName: string) {
  if (/^(image|video)\//.test(mimetype)) return true;
  const lowerName = originalName.toLowerCase();
  return /\.(png|jpe?g|webp|gif|heic|heif|mp4|mov|m4v|webm)$/i.test(lowerName);
}

const upload = createMemoryUpload({
  errorMessage: "Only image and video uploads are allowed",
  fileSize: 50 * 1024 * 1024,
  files: 12,
  accept: (mimetype, originalName) => isSupportedMediaUpload(mimetype, originalName),
});

const POST_CATEGORIES = [
  "general", "event", "work", "household", "nuclear-family",
  "biography", "fun", "community", "legal", "memory", "announcement",
];

const TIMELINE_AUTHOR_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  profileImage: true,
} as const;

const TIMELINE_COMMENT_INCLUDE = {
  author: { select: TIMELINE_AUTHOR_SELECT },
  replies: {
    include: { author: { select: TIMELINE_AUTHOR_SELECT } },
    orderBy: { createdAt: "asc" },
  },
  reactions: {
    select: { id: true, userId: true, emoji: true, createdAt: true },
    orderBy: { createdAt: "asc" },
  },
} as const;

const VIDEO_THUMBNAIL_TIMEOUT_MS = 8000;
const VIDEO_THUMBNAIL_MAX_BYTES = 25 * 1024 * 1024;

async function buildVideoThumbnail(file: Express.Multer.File) {
  // For larger videos, skip expensive thumbnail extraction to keep post creation reliable.
  if (file.size > VIDEO_THUMBNAIL_MAX_BYTES) {
    return null;
  }

  const timeout = new Promise<null>((resolve) => {
    setTimeout(() => resolve(null), VIDEO_THUMBNAIL_TIMEOUT_MS);
  });

  try {
    return await Promise.race<string | null>([
      generateAndSaveThumbnail(file.buffer, file.originalname, "timeline/thumbnails"),
      timeout,
    ]);
  } catch (err) {
    console.warn("Video thumbnail generation failed; continuing without thumbnail", {
      originalName: file.originalname,
      size: file.size,
      error: err instanceof Error ? err.message : String(err),
    });
    return null;
  }
}

async function notifyPostAuthorAboutComment(postId: string, commenterId: string) {
  const post = await prisma.timelinePost.findUnique({
    where: { id: postId },
    select: { authorId: true },
  });

  if (!post || post.authorId === commenterId) return;

  const commenter = await prisma.user.findUnique({
    where: { id: commenterId },
    select: { firstName: true, lastName: true },
  });

  if (!commenter) return;

  await sendPushNotification(
    post.authorId,
    "New Comment on Your Post",
    `${commenter.firstName} ${commenter.lastName} commented on your post`,
    {
      type: "post_activity",
      deepLink: `/timeline`,
      channelId: FCM_CHANNELS.social,
      data: { postId },
    }
  );
}

async function notifyMembersAboutNewPost(
  postId: string,
  authorId: string,
  authorName: string,
) {
  const recipients = await prisma.user.findMany({
    where: { status: "approved", id: { not: authorId } },
    select: { id: true },
    take: 500,
  });
  if (recipients.length === 0) return;

  await prisma.notification.createMany({
    data: recipients.map((u) => ({
      userId: u.id,
      title: "New Post",
      body: `${authorName} shared a new timeline post`,
      type: "post",
      link: `/timeline`,
    })),
  });

  await Promise.all(
    recipients.map((u) =>
      sendPushNotification(u.id, "New Post", `${authorName} shared a new timeline post`, {
        type: "new_post",
        deepLink: "/timeline",
        channelId: FCM_CHANNELS.post,
        data: { postId },
      })
    )
  );
}

// GET /timeline — paginated feed
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, parseInt(req.query.limit as string) || 20);
    const category = req.query.category as string | undefined;
    const skip = (page - 1) * limit;

    const where: any = { hidden: false };
    if (category && POST_CATEGORIES.includes(category)) where.category = category;

    const [posts, total] = await Promise.all([
      prisma.timelinePost.findMany({
        where,
        include: {
          author: { select: TIMELINE_AUTHOR_SELECT },
          media: true,
          likes: { select: { userId: true } },
          comments: {
            include: TIMELINE_COMMENT_INCLUDE,
            orderBy: { createdAt: "asc" },
          },
          _count: { select: { likes: true, comments: true } },
        },
        orderBy: [{ pinned: "desc" }, { createdAt: "desc" }],
        skip,
        take: limit,
      }),
      prisma.timelinePost.count({ where }),
    ]);

    res.json({ posts, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    console.error("Timeline fetch error:", err);
    res.status(500).json({ error: "Failed to load feed" });
  }
});

// POST /timeline — create post with optional media
router.post("/", ...auth, (req: AuthRequest, res) => {
  upload.array("media", 12)(req as any, res as any, async (uploadErr: any) => {
    if (uploadErr) {
      if (uploadErr instanceof multer.MulterError && uploadErr.code === "LIMIT_FILE_SIZE") {
        res.status(413).json({ error: "Media file too large. Maximum allowed is 50MB per file." });
        return;
      }

      const message = uploadErr?.message || "Invalid media upload";
      res.status(400).json({ error: message });
      return;
    }

    try {
      const { content, category } = req.body;
      const files = (req.files as Express.Multer.File[]) || [];

      if (!content?.trim() && files.length == 0) {
        res.status(400).json({ error: "Content or media is required" });
        return;
      }

      const images = files.filter((f) => f.mimetype.startsWith("image/") || /\.(png|jpe?g|webp|gif|heic|heif)$/i.test(f.originalname));
      const videos = files.filter((f) => f.mimetype.startsWith("video/") || /\.(mp4|mov|m4v|webm)$/i.test(f.originalname));

      if (images.length > 10) {
        res.status(400).json({ error: "Maximum 10 images per post" });
        return;
      }
      if (videos.length > 2) {
        res.status(400).json({ error: "Maximum 2 videos per post" });
        return;
      }

      const cat = POST_CATEGORIES.includes(category) ? category : "general";

      const mediaData = await Promise.all(files.map(async (file, i) => {
        const isVideo = file.mimetype.startsWith("video/") || /\.(mp4|mov|m4v|webm)$/i.test(file.originalname);
        const url = await saveUploadedFile(
          file,
          createObjectName("timeline", file.originalname, req.user!.id),
        );
        
        let thumbnailUrl: string | null = null;
        if (isVideo) {
          thumbnailUrl = await buildVideoThumbnail(file);
        }

        return {
          url,
          type: isVideo ? "video" : "image",
          sortOrder: i,
          ...(thumbnailUrl ? { thumbnailUrl } : {}),
        };
      }));

      const postData: any = {
        authorId: req.user!.id,
        content: (content || "").trim(),
        category: cat,
      };

      if (mediaData.length > 0) {
        postData.media = { create: mediaData };
      }

      const post = await prisma.timelinePost.create({
        data: postData,
        include: {
          author: { select: TIMELINE_AUTHOR_SELECT },
          media: { orderBy: { sortOrder: "asc" } },
          likes: { select: { userId: true } },
          comments: {
            include: TIMELINE_COMMENT_INCLUDE,
            orderBy: { createdAt: "asc" },
          },
          _count: { select: { likes: true, comments: true } },
        },
      });

      const authorName = `${req.user!.firstName} ${req.user!.lastName}`;
      await notifyMembersAboutNewPost(post.id, req.user!.id, authorName.trim());

      res.status(201).json(post);
    } catch (err) {
      console.error("Create post error:", err);
      res.status(500).json({ error: "Failed to create post" });
    }
  });
});

// GET /timeline/unread-count — get unread timeline posts count
// For MVP, returns count of new posts in the last 24 hours
router.get("/unread-count", ...auth, async (req: AuthRequest, res) => {
  try {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const count = await prisma.timelinePost.count({
      where: {
        hidden: false,
        createdAt: { gte: twentyFourHoursAgo },
      },
    });
    res.json({ count });
  } catch (err) {
    console.error("Unread count error:", err);
    res.status(500).json({ error: "Failed to fetch unread count" });
  }
});

// POST /timeline/:id/like — toggle like
router.post("/:id/like", ...auth, async (req: AuthRequest, res) => {
  try {
    const postId = String(req.params.id);
    const userId = req.user!.id;
    const existing = await prisma.timelinePostLike.findUnique({ where: { postId_userId: { postId, userId } } });

    if (existing) {
      await prisma.timelinePostLike.delete({ where: { id: existing.id } });
      res.json({ liked: false });
    } else {
      await prisma.timelinePostLike.create({ data: { postId, userId } });

      const post = await prisma.timelinePost.findUnique({
        where: { id: postId },
        select: { authorId: true },
      });

      if (post && post.authorId !== userId) {
        const liker = await prisma.user.findUnique({
          where: { id: userId },
          select: { firstName: true, lastName: true },
        });

        if (liker) {
          await sendPushNotification(
            post.authorId,
            "Timeline Post Liked",
            `${liker.firstName} ${liker.lastName} liked your post`,
            {
              type: "post_activity",
              deepLink: "/timeline",
              channelId: FCM_CHANNELS.social,
              data: { postId },
            }
          );
        }
      }

      res.json({ liked: true });
    }
  } catch (err) {
    console.error("Like error:", err);
    res.status(500).json({ error: "Failed to toggle like" });
  }
});

// POST /timeline/:id/comments — add comment
router.post("/:id/comments", ...auth, async (req: AuthRequest, res) => {
  try {
    const postId = String(req.params.id);
    const { content } = req.body;
    if (!content?.trim()) { res.status(400).json({ error: "Comment content is required" }); return; }

    const comment = await prisma.timelinePostComment.create({
      data: { postId, authorId: req.user!.id, content: content.trim() },
      include: TIMELINE_COMMENT_INCLUDE,
    });

    await notifyPostAuthorAboutComment(postId, req.user!.id);

    res.status(201).json(comment);
  } catch (err) {
    console.error("Comment error:", err);
    res.status(500).json({ error: "Failed to add comment" });
  }
});

router.post("/:id/comment", ...auth, async (req: AuthRequest, res) => {
  try {
    const postId = String(req.params.id);
    const { content } = req.body;
    if (!content?.trim()) { res.status(400).json({ error: "Comment content is required" }); return; }

    const comment = await prisma.timelinePostComment.create({
      data: { postId, authorId: req.user!.id, content: content.trim() },
      include: TIMELINE_COMMENT_INCLUDE,
    });

    await notifyPostAuthorAboutComment(postId, req.user!.id);

    res.status(201).json(comment);
  } catch (err) {
    console.error("Comment error:", err);
    res.status(500).json({ error: "Failed to add comment" });
  }
});

// POST /timeline/comments/:commentId/replies — add reply to comment
router.post("/comments/:commentId/replies", ...auth, async (req: AuthRequest, res) => {
  try {
    const prismaWithCommentModels = prisma as any;
    const commentId = String(req.params.commentId);
    const { content } = req.body;
    if (!content?.trim()) { res.status(400).json({ error: "Reply content is required" }); return; }

    const comment = await prisma.timelinePostComment.findUnique({
      where: { id: commentId },
      select: { id: true },
    });
    if (!comment) { res.status(404).json({ error: "Comment not found" }); return; }

    const reply = await prismaWithCommentModels.timelineCommentReply.create({
      data: { commentId, authorId: req.user!.id, content: content.trim() },
      include: { author: { select: TIMELINE_AUTHOR_SELECT } },
    });

    res.status(201).json(reply);
  } catch (err) {
    console.error("Reply error:", err);
    res.status(500).json({ error: "Failed to add reply" });
  }
});

// POST /timeline/comments/:commentId/reactions — toggle comment reaction
router.post("/comments/:commentId/reactions", ...auth, async (req: AuthRequest, res) => {
  try {
    const prismaWithCommentModels = prisma as any;
    const commentId = String(req.params.commentId);
    const userId = req.user!.id;
    const emoji = typeof req.body?.emoji === "string" && req.body.emoji.trim()
      ? req.body.emoji.trim().slice(0, 8)
      : "👍";

    const comment = await prisma.timelinePostComment.findUnique({
      where: { id: commentId },
      select: { id: true },
    });
    if (!comment) { res.status(404).json({ error: "Comment not found" }); return; }

    const existing = await prismaWithCommentModels.timelineCommentReaction.findUnique({
      where: { commentId_userId: { commentId, userId } },
    });

    if (existing && existing.emoji === emoji) {
      await prismaWithCommentModels.timelineCommentReaction.delete({ where: { id: existing.id } });
      res.json({ reacted: false, removed: true });
      return;
    }

    const reaction = existing
      ? await prismaWithCommentModels.timelineCommentReaction.update({
          where: { id: existing.id },
          data: { emoji },
          select: { id: true, userId: true, emoji: true, createdAt: true },
        })
      : await prismaWithCommentModels.timelineCommentReaction.create({
          data: { commentId, userId, emoji },
          select: { id: true, userId: true, emoji: true, createdAt: true },
        });

    res.json({ reacted: true, removed: false, reaction });
  } catch (err) {
    console.error("Comment reaction error:", err);
    res.status(500).json({ error: "Failed to toggle reaction" });
  }
});

// DELETE /timeline/:id — delete own post
router.delete("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const postId = String(req.params.id);
    const post = await prisma.timelinePost.findUnique({ where: { id: postId } });
    if (!post) { res.status(404).json({ error: "Post not found" }); return; }
    if (post.authorId !== req.user!.id && !["admin", "superadmin"].includes(req.user!.role)) {
      res.status(403).json({ error: "Not authorized" }); return;
    }
    await prisma.timelinePost.delete({ where: { id: postId } });
    res.json({ message: "Post deleted" });
  } catch (err) {
    console.error("Delete post error:", err);
    res.status(500).json({ error: "Failed to delete post" });
  }
});

export default router;

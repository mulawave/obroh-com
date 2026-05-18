import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, AuthRequest } from "../middleware/auth";
import { sendPushNotification, FCM_CHANNELS } from "../lib/fcm";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];

// GET /messages/inbox
router.get("/inbox", ...auth, async (req: AuthRequest, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, parseInt(req.query.limit as string) || 20);
    const items = await prisma.internalMessageRecipient.findMany({
      where: { userId: req.user!.id, folder: "inbox" },
      include: { message: { include: { sender: { select: { id: true, firstName: true, lastName: true, profileImage: true } } } } },
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * limit,
      take: limit,
    });
    const total = await prisma.internalMessageRecipient.count({ where: { userId: req.user!.id, folder: "inbox" } });
    res.json({ messages: items, total, page });
  } catch (err) {
    console.error("Inbox error:", err);
    res.status(500).json({ error: "Failed to load inbox" });
  }
});

// GET /messages/sent
router.get("/sent", ...auth, async (req: AuthRequest, res) => {
  try {
    const messages = await prisma.internalMessage.findMany({
      where: { senderId: req.user!.id },
      include: { recipients: { include: { user: { select: { id: true, firstName: true, lastName: true } } } } },
      orderBy: { createdAt: "desc" },
    });
    res.json({ messages });
  } catch (err) {
    console.error("Sent error:", err);
    res.status(500).json({ error: "Failed to load sent messages" });
  }
});

// GET /messages/drafts
router.get("/drafts", ...auth, async (req: AuthRequest, res) => {
  try {
    const drafts = await prisma.messageDraft.findMany({
      where: { userId: req.user!.id },
      orderBy: { updatedAt: "desc" },
    });
    res.json({ drafts });
  } catch (err) {
    console.error("Drafts error:", err);
    res.status(500).json({ error: "Failed to load drafts" });
  }
});

// GET /messages/spam
router.get("/spam", ...auth, async (req: AuthRequest, res) => {
  try {
    const items = await prisma.internalMessageRecipient.findMany({
      where: { userId: req.user!.id, folder: "spam" },
      include: { message: { include: { sender: { select: { id: true, firstName: true, lastName: true } } } } },
      orderBy: { createdAt: "desc" },
    });
    res.json({ messages: items });
  } catch (err) {
    console.error("Spam error:", err);
    res.status(500).json({ error: "Failed to load spam" });
  }
});

// GET /messages/unread-count
router.get("/unread-count", ...auth, async (req: AuthRequest, res) => {
  try {
    const count = await prisma.internalMessageRecipient.count({
      where: { userId: req.user!.id, folder: "inbox", isRead: false },
    });
    res.json({ count });
  } catch (err) {
    res.status(500).json({ error: "Failed to count" });
  }
});

// GET /messages/:id — read single message
router.get("/:id", ...auth, async (req: AuthRequest, res) => {
  try {
    const id = String(req.params.id);
    const recipient = await prisma.internalMessageRecipient.findFirst({
      where: { messageId: id, userId: req.user!.id },
      include: { message: { include: { sender: { select: { id: true, firstName: true, lastName: true, profileImage: true } }, recipients: { include: { user: { select: { id: true, firstName: true, lastName: true } } } }, attachments: true } } },
    });
    if (!recipient) { res.status(404).json({ error: "Message not found" }); return; }
    if (!recipient.isRead) {
      await prisma.internalMessageRecipient.update({ where: { id: recipient.id }, data: { isRead: true, readAt: new Date() } });
    }
    res.json(recipient.message);
  } catch (err) {
    console.error("Read message error:", err);
    res.status(500).json({ error: "Failed to read message" });
  }
});

// POST /messages — send message
router.post("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const { recipientIds, subject, body } = req.body;
    if (!recipientIds?.length || !subject?.trim() || !body?.trim()) {
      res.status(400).json({ error: "Recipients, subject, and body are required" }); return;
    }
    const message = await prisma.internalMessage.create({
      data: {
        senderId: req.user!.id,
        subject: subject.trim(),
        body: body.trim(),
        recipients: {
          create: (recipientIds as string[]).map((userId: string) => ({ userId, folder: "inbox" })),
        },
      },
      include: { recipients: true },
    });
    // Also create a "sent" copy for sender
    await prisma.internalMessageRecipient.create({
      data: { messageId: message.id, userId: req.user!.id, folder: "sent", isRead: true },
    });
    // Create notifications for each recipient
    const sender = await prisma.user.findUnique({ where: { id: req.user!.id }, select: { firstName: true, lastName: true } });
    const senderName = sender ? `${sender.firstName} ${sender.lastName}` : "Someone";
    const notifications = await prisma.notification.createMany({
      data: (recipientIds as string[]).map((userId: string) => ({
        userId,
        title: "New Message",
        body: `${senderName} sent you a message: "${subject.trim()}"`,
        type: "message",
        link: "/dashboard/messages",
      })),
    });

    // Send push notifications
    for (const userId of recipientIds as string[]) {
      sendPushNotification(userId, "New Message", `${senderName} sent you a message: "${subject.trim()}"`, {
        type: "new_message",
        deepLink: "/dashboard/messages",
        channelId: FCM_CHANNELS.message,
      });
    }

    res.status(201).json(message);
  } catch (err) {
    console.error("Send message error:", err);
    res.status(500).json({ error: "Failed to send message" });
  }
});

// POST /messages/drafts — save draft
router.post("/drafts", ...auth, async (req: AuthRequest, res) => {
  try {
    const { id, recipients, subject, body } = req.body;
    if (id) {
      const draft = await prisma.messageDraft.update({
        where: { id },
        data: { recipients: JSON.stringify(recipients), subject, body },
      });
      res.json(draft);
    } else {
      const draft = await prisma.messageDraft.create({
        data: { userId: req.user!.id, recipients: JSON.stringify(recipients), subject, body },
      });
      res.status(201).json(draft);
    }
  } catch (err) {
    console.error("Draft error:", err);
    res.status(500).json({ error: "Failed to save draft" });
  }
});

// PATCH /messages/:id/folder — move message to folder
router.patch("/:id/folder", ...auth, async (req: AuthRequest, res) => {
  try {
    const messageId = String(req.params.id);
    const { folder } = req.body;
    if (!["inbox", "spam", "trash", "archive"].includes(folder)) {
      res.status(400).json({ error: "Invalid folder" }); return;
    }
    await prisma.internalMessageRecipient.updateMany({
      where: { messageId, userId: req.user!.id },
      data: { folder },
    });
    res.json({ message: "Moved" });
  } catch (err) {
    console.error("Move message error:", err);
    res.status(500).json({ error: "Failed to move message" });
  }
});

// GET /messages/search/recipients?q= — autocomplete
router.get("/search/recipients", ...auth, async (req: AuthRequest, res) => {
  try {
    const q = (req.query.q as string || "").trim();
    if (q.length < 2) { res.json({ users: [] }); return; }
    const users = await prisma.user.findMany({
      where: {
        status: "approved",
        id: { not: req.user!.id },
        OR: [
          { firstName: { contains: q } },
          { lastName: { contains: q } },
          { email: { contains: q } },
        ],
      },
      select: { id: true, firstName: true, lastName: true, email: true, profileImage: true },
      take: 10,
    });
    res.json({ users });
  } catch (err) {
    console.error("Recipient search error:", err);
    res.status(500).json({ error: "Search failed" });
  }
});

export default router;

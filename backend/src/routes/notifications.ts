import { Router } from "express";
import prisma from "../lib/prisma";
import { authenticate, requireApproved, requireAdmin, AuthRequest } from "../middleware/auth";
import nodemailer from "nodemailer";

const router = Router();
const auth: any[] = [authenticate as any, requireApproved as any];
const adminAuth: any[] = [authenticate as any, requireApproved as any, requireAdmin as any];

// GET /notifications - User notifications
router.get("/", ...auth, async (req: AuthRequest, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, parseInt(req.query.limit as string) || 20);
    const [notifications, total, unread] = await Promise.all([
      prisma.notification.findMany({
        where: { userId: req.user!.id },
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.notification.count({ where: { userId: req.user!.id } }),
      prisma.notification.count({ where: { userId: req.user!.id, isRead: false } }),
    ]);
    res.json({ notifications, total, unread, page });
  } catch (err) {
    console.error("Notifications error:", err);
    res.status(500).json({ error: "Failed to load notifications" });
  }
});

// GET /notifications/admin - Admin view of all notifications
router.get("/admin", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const notifications = await prisma.notification.findMany({
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });
    res.json({ notifications, total: notifications.length });
  } catch (err) {
    console.error("Admin notifications error:", err);
    res.status(500).json({ error: "Failed to load admin notifications" });
  }
});

// POST /notifications/admin - Admin sends notification
router.post("/admin", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const { title, body, type, link, recipientIds } = req.body;

    if (!title) {
      res.status(400).json({ error: "Title is required" });
      return;
    }

    // If recipientIds provided, send to specific users
    if (recipientIds && Array.isArray(recipientIds) && recipientIds.length > 0) {
      const notifications = await prisma.notification.createMany({
        data: recipientIds.map((userId: string) => ({
          userId,
          title,
          body,
          type: type || "info",
          link,
        })),
      });
      res.status(201).json({ message: `Sent ${notifications.count} notifications` });
    } else {
      // Send to all users
      const users = await prisma.user.findMany({ where: { status: "approved" }, select: { id: true } });
      const notifications = await prisma.notification.createMany({
        data: users.map((user) => ({
          userId: user.id,
          title,
          body,
          type: type || "info",
          link,
        })),
      });
      res.status(201).json({ message: `Sent ${notifications.count} notifications` });
    }
  } catch (err) {
    console.error("Send notification error:", err);
    res.status(500).json({ error: "Failed to send notification" });
  }
});

// GET /notifications/unread-count
router.get("/unread-count", ...auth, async (req: AuthRequest, res) => {
  try {
    const count = await prisma.notification.count({ where: { userId: req.user!.id, isRead: false } });
    res.json({ count });
  } catch (err) {
    res.status(500).json({ error: "Failed to count" });
  }
});

// PATCH /notifications/:id/read
router.patch("/:id/read", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.notification.update({ where: { id: String(req.params.id) }, data: { isRead: true } });
    res.json({ message: "Marked as read" });
  } catch (err) {
    res.status(500).json({ error: "Failed to mark as read" });
  }
});

// DELETE /notifications/:id - Admin delete notification
router.delete("/:id", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    await prisma.notification.delete({ where: { id: String(req.params.id) } });
    res.json({ message: "Notification deleted" });
  } catch (err) {
    console.error("Delete notification error:", err);
    res.status(500).json({ error: "Failed to delete notification" });
  }
});

// POST /notifications/read-all
router.post("/read-all", ...auth, async (req: AuthRequest, res) => {
  try {
    await prisma.notification.updateMany({ where: { userId: req.user!.id, isRead: false }, data: { isRead: true } });
    res.json({ message: "All marked as read" });
  } catch (err) {
    res.status(500).json({ error: "Failed to mark all as read" });
  }
});

// ─── SMTP Settings ─────────────────────────────────────────────────────────────

// GET /notifications/smtp-settings - Get SMTP settings
router.get("/smtp-settings", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const settings = await prisma.smtpSettings.findFirst();
    if (!settings) {
      res.json({ settings: null });
      return;
    }
    // Don't return password for security
    const { password, ...safeSettings } = settings;
    res.json({ settings: safeSettings });
  } catch (err) {
    console.error("Get SMTP settings error:", err);
    res.status(500).json({ error: "Failed to load SMTP settings" });
  }
});

// POST /notifications/smtp-settings - Save SMTP settings
router.post("/smtp-settings", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const { host, port, secure, user, password, fromName, fromEmail } = req.body;

    if (!host || !port || !user || !password || !fromEmail) {
      res.status(400).json({ error: "Host, port, user, password, and fromEmail are required" });
      return;
    }

    const existing = await prisma.smtpSettings.findFirst();

    if (existing) {
      const settings = await prisma.smtpSettings.update({
        where: { id: existing.id },
        data: { host, port, secure, user, password, fromName, fromEmail },
      });
      const { password: _, ...safeSettings } = settings;
      res.json({ settings: safeSettings });
    } else {
      const settings = await prisma.smtpSettings.create({
        data: { host, port, secure, user, password, fromName, fromEmail },
      });
      const { password: _, ...safeSettings } = settings;
      res.status(201).json({ settings: safeSettings });
    }
  } catch (err) {
    console.error("Save SMTP settings error:", err);
    res.status(500).json({ error: "Failed to save SMTP settings" });
  }
});

// POST /notifications/smtp-settings/test - Test SMTP connection and send test email
router.post("/smtp-settings/test", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const { toEmail } = req.body;

    if (!toEmail) {
      res.status(400).json({ error: "Test email address is required" });
      return;
    }

    const settings = await prisma.smtpSettings.findFirst();
    if (!settings) {
      res.status(400).json({ error: "SMTP settings not configured" });
      return;
    }

    // Create transporter
    const transporter = nodemailer.createTransport({
      host: settings.host,
      port: settings.port,
      secure: settings.secure,
      auth: {
        user: settings.user,
        pass: settings.password,
      },
    });

    // Verify connection
    await transporter.verify();

    // Send test email
    await transporter.sendMail({
      from: `"${settings.fromName}" <${settings.fromEmail}>`,
      to: toEmail,
      subject: "SMTP Test Email from Obroh Admin",
      text: "This is a test email from the Obroh Family admin panel. If you received this, your SMTP settings are working correctly.",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #d4af37;">SMTP Test Email</h2>
          <p>This is a test email from the Obroh Family admin panel.</p>
          <p>If you received this, your SMTP settings are working correctly.</p>
          <p style="color: #666; font-size: 12px;">Sent from Obroh Ancestry Datacenter</p>
        </div>
      `,
    });

    res.json({ message: "Test email sent successfully" });
  } catch (err) {
    console.error("Test SMTP error:", err);
    res.status(500).json({ error: "Failed to send test email: " + (err as Error).message });
  }
});

// ─── Email Sending ───────────────────────────────────────────────────────────

// POST /notifications/send-email - Send email to members
router.post("/send-email", ...adminAuth, async (req: AuthRequest, res) => {
  try {
    const { subject, body, recipientType, recipientIds, singleRecipientEmail } = req.body;

    if (!subject || !body || !recipientType) {
      res.status(400).json({ error: "Subject, body, and recipientType are required" });
      return;
    }

    const settings = await prisma.smtpSettings.findFirst();
    if (!settings) {
      res.status(400).json({ error: "SMTP settings not configured" });
      return;
    }

    let recipients: { email: string; firstName: string; lastName: string }[] = [];

    if (recipientType === "all") {
      const users = await prisma.user.findMany({
        where: { status: "approved" },
        select: { email: true, firstName: true, lastName: true },
      });
      recipients = users;
    } else if (recipientType === "selected" && recipientIds && Array.isArray(recipientIds)) {
      const users = await prisma.user.findMany({
        where: { id: { in: recipientIds } },
        select: { email: true, firstName: true, lastName: true },
      });
      recipients = users;
    } else if (recipientType === "single" && singleRecipientEmail) {
      const user = await prisma.user.findFirst({
        where: { email: singleRecipientEmail },
        select: { email: true, firstName: true, lastName: true },
      });
      if (user) recipients = [user];
    }

    if (recipients.length === 0) {
      res.status(400).json({ error: "No recipients found" });
      return;
    }

    // Create transporter
    const transporter = nodemailer.createTransport({
      host: settings.host,
      port: settings.port,
      secure: settings.secure,
      auth: {
        user: settings.user,
        pass: settings.password,
      },
    });

    // Send emails
    const emailPromises = recipients.map((recipient) =>
      transporter.sendMail({
        from: `"${settings.fromName}" <${settings.fromEmail}>`,
        to: recipient.email,
        subject,
        text: body,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #d4af37;">${subject}</h2>
            <div>${body.replace(/\n/g, "<br>")}</div>
            <p style="color: #666; font-size: 12px; margin-top: 30px;">Sent from Obroh Ancestry Datacenter</p>
          </div>
        `,
      })
    );

    await Promise.all(emailPromises);

    res.json({ message: `Email sent to ${recipients.length} recipient(s)` });
  } catch (err) {
    console.error("Send email error:", err);
    res.status(500).json({ error: "Failed to send email: " + (err as Error).message });
  }
});

// GET /notifications/members - Get approved members for email selection
router.get("/members", ...adminAuth, async (_req: AuthRequest, res) => {
  try {
    const members = await prisma.user.findMany({
      where: { status: "approved" },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
      },
      orderBy: { createdAt: "desc" },
    });
    res.json({ members, total: members.length });
  } catch (err) {
    console.error("Get members error:", err);
    res.status(500).json({ error: "Failed to load members" });
  }
});

export default router;

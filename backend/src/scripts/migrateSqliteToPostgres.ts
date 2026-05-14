import { DatabaseSync } from "node:sqlite";
import path from "path";
import prisma from "../lib/prisma";

const TABLE_ORDER = [
  "users",
  "contact_submissions",
  "roles",
  "site_content",
  "user_profiles",
  "profile_identifying_marks",
  "user_badges",
  "timeline_posts",
  "timeline_post_media",
  "timeline_post_likes",
  "timeline_post_comments",
  "internal_messages",
  "internal_message_recipients",
  "internal_message_attachments",
  "message_drafts",
  "portfolios",
  "portfolio_gallery_images",
  "portfolio_projects",
  "portfolio_project_images",
  "portfolio_skills",
  "portfolio_experiences",
  "portfolio_experience_images",
  "portfolio_education",
  "portfolio_public_messages",
  "books",
  "biographies",
  "biography_sections",
  "legacy",
  "knowledge_base",
  "family_branches",
  "lineage_relationships",
  "child_registration_requests",
  "legal_declarations",
  "legal_declaration_documents",
  "notifications",
  "smtp_settings",
  "fcm_device_tokens",
  "legacy_milestones",
  "legacy_achievements",
  "knowledge_base_articles",
] as const;

const BOOLEAN_FIELDS: Record<string, string[]> = {
  timeline_posts: ["pinned", "hidden"],
  internal_messages: ["isFromGuest"],
  internal_message_recipients: ["isRead"],
  portfolios: ["isPublic"],
  portfolio_public_messages: ["isRead"],
  biographies: ["isPublic"],
  roles: ["isSystem"],
  legal_declarations: ["publishedToFeed"],
  notifications: ["isRead"],
  smtp_settings: ["secure"],
  knowledge_base_articles: ["published"],
};

const OMIT_ON_INSERT: Record<string, string[]> = {
  users: ["branchId"],
};

function quoteIdentifier(identifier: string) {
  return `"${identifier.replace(/"/g, '""')}"`;
}

function getSqlitePath() {
  const configured = process.env.SQLITE_DATABASE_URL || "file:./prisma/dev.db";
  if (configured.startsWith("file:")) {
    return path.resolve(process.cwd(), configured.slice(5));
  }
  return path.resolve(process.cwd(), configured);
}

function normalizeValue(table: string, column: string, value: unknown) {
  if (value === undefined) {
    return null;
  }

  if (value === null) {
    return null;
  }

  if ((BOOLEAN_FIELDS[table] || []).includes(column)) {
    return Boolean(value);
  }

  if (typeof value === "number" && /At$/.test(column)) {
    return new Date(value);
  }

  if (typeof value === "string" && /^\d+$/.test(value) && /At$/.test(column)) {
    return new Date(Number(value));
  }

  return value;
}

async function truncateTarget() {
  const joinedTables = TABLE_ORDER.slice().reverse().map(quoteIdentifier).join(", ");
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${joinedTables} CASCADE`);
}

async function insertRows(db: DatabaseSync, table: string) {
  const rows = db.prepare(`SELECT * FROM ${quoteIdentifier(table)}`).all() as Record<string, unknown>[];

  if (rows.length === 0) {
    console.log(`Skipping ${table} (0 rows)`);
    return;
  }

  const omitted = new Set(OMIT_ON_INSERT[table] || []);

  for (const row of rows) {
    const entries = Object.entries(row).filter(([column]) => !omitted.has(column));
    if (entries.length === 0) {
      continue;
    }

    const columns = entries.map(([column]) => quoteIdentifier(column)).join(", ");
    const placeholders = entries.map((_, index) => `$${index + 1}`).join(", ");
    const values = entries.map(([column, value]) => normalizeValue(table, column, value));

    await prisma.$executeRawUnsafe(
      `INSERT INTO ${quoteIdentifier(table)} (${columns}) VALUES (${placeholders})`,
      ...values,
    );
  }

  console.log(`Imported ${rows.length} rows into ${table}`);
}

async function restoreUserBranchAssignments(db: DatabaseSync) {
  const rows = db.prepare("SELECT id, branchId FROM users WHERE branchId IS NOT NULL").all() as Array<{ id: string; branchId: string }>;

  for (const row of rows) {
    await prisma.user.update({
      where: { id: row.id },
      data: { branchId: row.branchId },
    });
  }

  console.log(`Restored ${rows.length} user branch assignments`);
}

async function main() {
  const sqlitePath = getSqlitePath();
  const resetTarget = process.env.RESET_TARGET_DB === "true";

  console.log(`Using SQLite source: ${sqlitePath}`);

  const db = new DatabaseSync(sqlitePath, { readOnly: true });

  try {
    if (resetTarget) {
      console.log("RESET_TARGET_DB=true, truncating target tables before import");
      await truncateTarget();
    }

    for (const table of TABLE_ORDER) {
      await insertRows(db, table);
    }

    await restoreUserBranchAssignments(db);
    console.log("SQLite to PostgreSQL migration completed successfully");
  } finally {
    db.close();
    await prisma.$disconnect();
  }
}

main().catch(async (error) => {
  console.error("SQLite to PostgreSQL migration failed:", error);
  await prisma.$disconnect();
  process.exit(1);
});
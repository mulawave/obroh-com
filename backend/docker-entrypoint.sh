#!/bin/sh
set -e

echo "[entrypoint] Running database migrations..."

# Repair legacy production drift before Prisma checks migration state.
# This is safe on every startup because the SQL is idempotent.
echo "[entrypoint] Applying idempotent schema repairs..."
echo 'CREATE TABLE IF NOT EXISTS "refresh_tokens" ("token" VARCHAR(255) PRIMARY KEY, "userId" VARCHAR(255) NOT NULL, "expiresAt" TIMESTAMP NOT NULL, CONSTRAINT "fk_refresh_token_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE); CREATE INDEX IF NOT EXISTS "idx_refresh_token_user" ON "refresh_tokens" ("userId");' \
  | npx prisma db execute --schema prisma/schema.prisma --stdin || true

echo 'ALTER TABLE "timeline_post_media" ADD COLUMN IF NOT EXISTS "thumbnailUrl" TEXT;' \
  | npx prisma db execute --schema prisma/schema.prisma --stdin || true

echo 'CREATE TABLE IF NOT EXISTS "timeline_comment_replies" ("id" TEXT PRIMARY KEY, "commentId" TEXT NOT NULL, "authorId" TEXT NOT NULL, "content" TEXT NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "timeline_comment_replies_commentId_fkey" FOREIGN KEY ("commentId") REFERENCES "timeline_post_comments"("id") ON DELETE CASCADE, CONSTRAINT "timeline_comment_replies_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "users"("id") ON DELETE CASCADE); CREATE TABLE IF NOT EXISTS "timeline_comment_reactions" ("id" TEXT PRIMARY KEY, "commentId" TEXT NOT NULL, "userId" TEXT NOT NULL, "emoji" TEXT NOT NULL DEFAULT ''👍'', "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "timeline_comment_reactions_commentId_fkey" FOREIGN KEY ("commentId") REFERENCES "timeline_post_comments"("id") ON DELETE CASCADE, CONSTRAINT "timeline_comment_reactions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE); CREATE UNIQUE INDEX IF NOT EXISTS "timeline_comment_reactions_commentId_userId_key" ON "timeline_comment_reactions" ("commentId", "userId");' \
  | npx prisma db execute --schema prisma/schema.prisma --stdin || true

# Attempt migrate deploy. If the DB was originally set up with prisma db push,
# the _prisma_migrations table won't exist and Prisma throws P3005.
# In that case we baseline all existing migrations (mark as applied without
# re-running their SQL), then retry — which will only apply truly new ones.
migrate_output=$(npx prisma migrate deploy 2>&1) || {
  exit_code=$?
  echo "$migrate_output"
  if echo "$migrate_output" | grep -q "P3005"; then
    echo "[entrypoint] P3005 detected: baselining existing migrations..."

    # Now mark both migrations as already applied (baseline)
    npx prisma migrate resolve --applied add-refresh-token   || true
    npx prisma migrate resolve --applied add_thumbnail_to_media || true
    npx prisma migrate resolve --applied add_timeline_comment_relations || true
    echo "[entrypoint] Baseline complete. Re-running migrate deploy..."
    npx prisma migrate deploy || {
      echo "[entrypoint] WARNING: Migration failed but continuing with server startup (exit $?)"
    }
  else
    echo "[entrypoint] WARNING: Migration failed but continuing with server startup (exit $exit_code)"
  fi
}

echo "[entrypoint] Migrations done. Starting server..."
exec node dist/server.js

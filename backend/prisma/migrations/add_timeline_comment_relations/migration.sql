-- Add reply and reaction support for timeline comments
CREATE TABLE IF NOT EXISTS "timeline_comment_replies" (
  "id" TEXT PRIMARY KEY,
  "commentId" TEXT NOT NULL,
  "authorId" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "timeline_comment_replies_commentId_fkey"
    FOREIGN KEY ("commentId") REFERENCES "timeline_post_comments"("id") ON DELETE CASCADE,
  CONSTRAINT "timeline_comment_replies_authorId_fkey"
    FOREIGN KEY ("authorId") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "timeline_comment_reactions" (
  "id" TEXT PRIMARY KEY,
  "commentId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "emoji" TEXT NOT NULL DEFAULT '👍',
  "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "timeline_comment_reactions_commentId_fkey"
    FOREIGN KEY ("commentId") REFERENCES "timeline_post_comments"("id") ON DELETE CASCADE,
  CONSTRAINT "timeline_comment_reactions_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "timeline_comment_reactions_commentId_userId_key"
  ON "timeline_comment_reactions" ("commentId", "userId");
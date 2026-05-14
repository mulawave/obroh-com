-- Add RefreshToken model for persistent login
CREATE TABLE "refresh_tokens" (
  "token" VARCHAR(255) PRIMARY KEY,
  "userId" VARCHAR(255) NOT NULL,
  "expiresAt" TIMESTAMP NOT NULL,
  CONSTRAINT "fk_refresh_token_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE INDEX "idx_refresh_token_user" ON "refresh_tokens" ("userId");

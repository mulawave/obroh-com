// Single source for the JWT signing secret. The dev fallback is public (it's in
// the repo), so production must never use it: fail at startup instead.
const DEV_FALLBACK = "obroh-local-dev-only-secret";

const configured = process.env.JWT_SECRET?.trim();

if (!configured && process.env.NODE_ENV === "production") {
  throw new Error("JWT_SECRET is not set. Refusing to start: tokens would be signed with a public fallback.");
}

export const JWT_SECRET = configured || DEV_FALLBACK;

// The owner's secret: one long random string in FORGE_OWNER_SECRET that opens
// the spend numbers, /api/usage and the /owner dashboard. Never sent to a
// user's phone; the owner types it into their own copy of the app once.
import type { VercelRequest } from "@vercel/node";
import { timingSafeEqual } from "node:crypto";
import { config } from "./env.js";
import { HttpError } from "./http.js";

export function isOwnerSecret(candidate: string): boolean {
  const secret = config.ownerSecret;
  if (!secret || !candidate) return false;
  const a = Buffer.from(candidate), b = Buffer.from(secret);
  return a.length === b.length && timingSafeEqual(a, b);
}

/// Throws unless the request carries the owner's secret as a bearer token.
export function requireOwner(req: VercelRequest): void {
  if (!config.ownerSecret) throw new HttpError(503, "not_configured", "FORGE_OWNER_SECRET is not set (16 characters or more).");
  const auth = req.headers.authorization ?? "";
  const bearer = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (!isOwnerSecret(bearer)) throw new HttpError(401, "unauthorized", "The owner's secret is required.");
}

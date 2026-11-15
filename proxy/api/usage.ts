import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config } from "../lib/env.js";
import { requireMethod, sendError } from "../lib/http.js";
import { requireOwner } from "../lib/owner.js";
import { dayKey, store } from "../lib/store.js";
import { usageFor } from "../lib/limits.js";

/// GET /api/usage?day=YYYY-MM-DD — the developer's view: every device that
/// called today (or that day), how many checks and calls, what they cost, and
/// the day's spend against the ceiling. Needs FORGE_OWNER_SECRET as a bearer.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    requireMethod(req, "GET");
    requireOwner(req);
    const day = typeof req.query.day === "string" && /^\d{4}-\d{2}-\d{2}$/.test(req.query.day) ? req.query.day : dayKey();
    const usage = await usageFor(day);
    res.status(200).json({ ...usage, store: store().kind, limits: { checksPerDevicePerDay: config.checksPerDevicePerDay } });
  } catch (err) {
    sendError(res, err, "usage");
  }
}

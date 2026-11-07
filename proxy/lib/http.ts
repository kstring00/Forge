import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config, missingConfig } from "./env.js";

export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

/// Bearer-token check. Constant-time compare so timing does not leak the token.
export function requireAuth(req: VercelRequest): void {
  const missing = missingConfig();
  if (missing.length > 0) {
    throw new HttpError(503, "not_configured", `Proxy is missing: ${missing.join(", ")}`);
  }
  const header = req.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token || !timingSafeEqual(token, config.proxyToken)) {
    throw new HttpError(401, "unauthorized", "Missing or invalid proxy token.");
  }
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/// Best-effort per-instance rate limit. Serverless instances do not share
/// memory, so this bounds bursts, not totals; the app's monthly ceiling is the
/// real control for a one-person tool.
const window: number[] = [];
export function rateLimit(): void {
  const now = Date.now();
  while (window.length && now - window[0] > 60_000) window.shift();
  if (window.length >= config.requestsPerMinute) {
    throw new HttpError(429, "rate_limited", "Too many requests this minute.");
  }
  window.push(now);
}

export function requireMethod(req: VercelRequest, method: string): void {
  if (req.method !== method) throw new HttpError(405, "method_not_allowed", `Use ${method}.`);
}

export function readJSON<T>(req: VercelRequest): T {
  const body = req.body;
  if (body === undefined || body === null) throw new HttpError(400, "bad_request", "Body must be JSON.");
  if (typeof body === "string") {
    try { return JSON.parse(body) as T; } catch { throw new HttpError(400, "bad_request", "Body is not valid JSON."); }
  }
  return body as T;
}

export function sendError(res: VercelResponse, err: unknown): void {
  if (err instanceof HttpError) {
    res.status(err.status).json({ error: { code: err.code, message: err.message } });
    return;
  }
  // Anthropic SDK errors carry a status; surface it without the body.
  const status = (err as { status?: number })?.status;
  if (typeof status === "number") {
    const code = status === 429 ? "upstream_rate_limited" : status >= 500 ? "upstream_error" : "upstream_rejected";
    res.status(status === 429 ? 429 : 502).json({ error: { code, message: `Claude API answered ${status}.` } });
    return;
  }
  console.error(err);
  res.status(500).json({ error: { code: "internal", message: "Something failed in the proxy." } });
}

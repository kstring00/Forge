import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config } from "./env.js";
import { logUpstream, upstreamMessage } from "./upstream.js";

export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

/// The kill switch (PARKED.md). With PROXY_DISABLED set to "true", every route
/// answers 503 {"error":"Service paused"} and returns true. It is the first
/// thing each handler does: before the method check, before any auth, before
/// anything is read from the request or sent upstream.
export function paused(res: VercelResponse): boolean {
  if ((process.env.PROXY_DISABLED ?? "").trim().toLowerCase() !== "true") return false;
  res.status(503).json({ error: "Service paused" });
  return true;
}

/// The proxy used to accept one shared bearer token (FORGE_PROXY_TOKEN). That
/// token was exposed and Hunch is parked, so the token is gone from the code:
/// nothing reads it, and no Authorization header opens anything. There is no
/// other door on this branch, so every request is refused here. A future app
/// would bring its own (the App Attest work in PR #16 is the starting point).
export function requireAuth(_req: VercelRequest): void {
  throw new HttpError(401, "unauthorized", "This proxy accepts no requests.");
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

export function sendError(res: VercelResponse, err: unknown, route = "proxy"): void {
  if (err instanceof HttpError) {
    // Our own 4xx are expected (bad token, bad body); log the 5xx ones.
    if (err.status >= 500) console.error(JSON.stringify({ at: route, status: err.status, code: err.code, message: err.message }));
    res.status(err.status).json({ error: { code: err.code, message: err.message } });
    return;
  }
  // Claude API errors: log Anthropic's full body, and pass its message on so
  // the app can show what was rejected.
  const status = (err as { status?: number })?.status;
  if (typeof status === "number") {
    logUpstream(route, err);
    const code = status === 429 ? "upstream_rate_limited" : status >= 500 ? "upstream_error" : "upstream_rejected";
    const detail = upstreamMessage(err);
    res.status(status === 429 ? 429 : 502).json({
      error: { code, message: `Claude API answered ${status}${detail ? `: ${detail}` : "."}` },
    });
    return;
  }
  logUpstream(route, err);
  res.status(500).json({ error: { code: "internal", message: "Something failed in the proxy." } });
}

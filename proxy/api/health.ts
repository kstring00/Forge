import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config, missingConfig } from "../lib/env.js";
import { paused, requireAuth, requireMethod, sendError } from "../lib/http.js";
import { realityCheckEstimateUSD } from "../lib/pricing.js";
import { content } from "../lib/content.js";
import { hunchConfig, models } from "../lib/config.js";

/// GET /api/health — is the deployment alive? With the kill switch on it
/// answers 503 like every other route. Nothing is "authorized" any more (the
/// bearer token is gone), so the configuration detail is never returned.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (paused(res)) return;
  try {
    requireMethod(req, "GET");
    const missing = missingConfig();
    let authorized = false;
    try { requireAuth(req); authorized = true; } catch { authorized = false; }
    res.status(200).json({
      ok: missing.length === 0,
      version: config.version,
      contentVersion: content.version,
      authorized,
      missing: authorized ? missing : undefined,
      models: authorized ? models() : undefined,
      limits: authorized ? { searches: config.maxSearchesPerResearchCall, fetches: config.maxFetchesPerResearchCall, tokensPerFetch: config.maxTokensPerFetch } : undefined,
      estimate: { realityCheckUSD: realityCheckEstimateUSD(config.maxSearchesPerResearchCall) },
      // Decision 0042: the plan numbers, for every app, authorized or not.
      rules: hunchConfig.rules,
    });
  } catch (err) {
    sendError(res, err, "health");
  }
}

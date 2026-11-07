import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config, missingConfig } from "../lib/env.js";
import { requireAuth, requireMethod, sendError } from "../lib/http.js";
import { realityCheckEstimateUSD } from "../lib/pricing.js";
import { content } from "../lib/content.js";

/// GET /api/health — is the proxy configured and is this token accepted?
/// Without a token it still answers, minus the configuration detail, so a
/// browser can tell the deployment is alive.
export default async function handler(req: VercelRequest, res: VercelResponse) {
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
      models: authorized ? { research: config.researchModel, spheres: config.sphereModel, fast: config.fastModel } : undefined,
      limits: authorized ? { searches: config.maxSearchesPerResearchCall, fetches: config.maxFetchesPerResearchCall, tokensPerFetch: config.maxTokensPerFetch } : undefined,
      estimate: { realityCheckUSD: realityCheckEstimateUSD(config.maxSearchesPerResearchCall) },
    });
  } catch (err) {
    sendError(res, err, "health");
  }
}

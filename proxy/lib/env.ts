// Configuration from environment variables. Only ANTHROPIC_API_KEY and
// FORGE_PROXY_TOKEN are required. Nothing here is ever sent to the app.
// Read on access, not at import, so load order never decides what is seen.
import { modelFor } from "./config.js";

const num = (name: string, fallback: number) => {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v > 0 ? v : fallback;
};

export const config = {
  // Trimmed: a trailing newline from a pasted `openssl rand` or a piped
  // `vercel env add` must not make a correct token fail.
  get anthropicApiKey() { return (process.env.ANTHROPIC_API_KEY ?? "").trim(); },
  get proxyToken() { return (process.env.FORGE_PROXY_TOKEN ?? "").trim(); },
  /// Models live in config/hunch.ts (decision 0042), read through lib/config.ts.
  get researchModel() { return modelFor("research"); },
  /// Per research turn; a paused turn's continuations count against the same
  /// cap. Searches are billed per use ($0.01 each), so this is the main cost
  /// lever. Fetches are billed only as the tokens they add.
  get maxSearchesPerResearchCall() { return num("FORGE_MAX_SEARCHES", 5); },
  get maxFetchesPerResearchCall() { return num("FORGE_MAX_FETCHES", 4); },
  /// Each fetched page is cut to about this many tokens before the model reads it.
  get maxTokensPerFetch() { return num("FORGE_MAX_FETCH_TOKENS", 4000); },
  get requestsPerMinute() { return num("FORGE_REQUESTS_PER_MINUTE", 30); },
  version: "0.2.0",
};

export function missingConfig(): string[] {
  const missing: string[] = [];
  if (!config.anthropicApiKey) missing.push("ANTHROPIC_API_KEY");
  if (!config.proxyToken) missing.push("FORGE_PROXY_TOKEN");
  return missing;
}

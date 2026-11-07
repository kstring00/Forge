// Configuration from environment variables. Only ANTHROPIC_API_KEY and
// FORGE_PROXY_TOKEN are required. Nothing here is ever sent to the app.

// Trimmed: a trailing newline from a pasted `openssl rand` or a piped
// `vercel env add` must not make a correct token fail.
export const config = {
  anthropicApiKey: (process.env.ANTHROPIC_API_KEY ?? "").trim(),
  proxyToken: (process.env.FORGE_PROXY_TOKEN ?? "").trim(),
  /// Spheres, synthesis, research. Brief v4 §11: Sonnet.
  researchModel: process.env.FORGE_RESEARCH_MODEL ?? "claude-sonnet-5-5",
  /// Summaries, expansions, transcript cleanup. Brief v4 §11: Haiku.
  fastModel: process.env.FORGE_FAST_MODEL ?? "claude-haiku-5-5",
  /// Hard caps, so a runaway loop cannot run up a bill.
  maxSearchesPerResearchCall: Number(process.env.FORGE_MAX_SEARCHES ?? 8),
  maxFetchesPerResearchCall: Number(process.env.FORGE_MAX_FETCHES ?? 8),
  requestsPerMinute: Number(process.env.FORGE_REQUESTS_PER_MINUTE ?? 30),
  version: "0.1.0",
} as const;

export function missingConfig(): string[] {
  const missing: string[] = [];
  if (!config.anthropicApiKey) missing.push("ANTHROPIC_API_KEY");
  if (!config.proxyToken) missing.push("FORGE_PROXY_TOKEN");
  return missing;
}

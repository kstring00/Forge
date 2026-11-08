// Configuration from environment variables. Only ANTHROPIC_API_KEY and
// FORGE_PROXY_TOKEN are required. Nothing here is ever sent to the app.
// Read on access, not at import, so load order never decides what is seen.

const num = (name: string, fallback: number) => {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v > 0 ? v : fallback;
};

export const config = {
  // Trimmed: a trailing newline from a pasted `openssl rand` or a piped
  // `vercel env add` must not make a correct token fail.
  get anthropicApiKey() { return (process.env.ANTHROPIC_API_KEY ?? "").trim(); },
  /// Developer tokens, for simulators and development builds only. A release
  /// build carries no token; it proves itself with App Attest. Comma-separated.
  /// FORGE_PROXY_TOKEN is still read as the first of them.
  get devTokens(): string[] {
    return [process.env.FORGE_PROXY_TOKEN ?? "", ...(process.env.FORGE_DEV_TOKENS ?? "").split(",")]
      .map((t) => t.trim()).filter((t) => t.length >= 16);
  },
  /// Kept for the health endpoint's "configured" check.
  get proxyToken() { return this.devTokens[0] ?? ""; },
  /// App Attest: "TEAMID.bundle.id". Both parts come from the developer account.
  get appleTeamID() { return (process.env.APPLE_TEAM_ID ?? "").trim(); },
  get appBundleID() { return (process.env.APP_BUNDLE_ID ?? "com.stringhamwebdesign.hunch").trim(); },
  get appID() { return `${this.appleTeamID}.${this.appBundleID}`; },
  /// "production" for TestFlight and the App Store; "development" accepts
  /// development attestations too (Xcode builds on a device).
  get appAttestEnvironment(): "production" | "development" {
    return process.env.APP_ATTEST_ENVIRONMENT === "development" ? "development" : "production";
  },
  /// DeviceCheck fallback: a key from the developer account.
  get deviceCheckKeyID() { return (process.env.DEVICECHECK_KEY_ID ?? "").trim(); },
  get deviceCheckPrivateKey() { return (process.env.DEVICECHECK_PRIVATE_KEY ?? "").trim(); },
  /// The developer's token for /api/usage.
  get adminToken() { return (process.env.FORGE_ADMIN_TOKEN ?? "").trim(); },
  /// Limits. Both fail politely.
  get checksPerDevicePerDay() { return num("FORGE_CHECKS_PER_DEVICE_PER_DAY", 5); },
  get dailySpendUSD() { return num("FORGE_DAILY_SPEND_USD", 5); },
  /// Desk research (web search and fetch, writing notes). Haiku: reading is
  /// most of the tokens and needs little judgment.
  get researchModel() { return process.env.FORGE_RESEARCH_MODEL ?? "claude-haiku-5-5"; },
  /// Spheres, the prefill and every verdict. Brief v4 §11: Sonnet.
  get sphereModel() { return process.env.FORGE_SPHERE_MODEL ?? "claude-sonnet-5-5"; },
  /// Summaries, expansions, transcript cleanup. Brief v4 §11: Haiku.
  get fastModel() { return process.env.FORGE_FAST_MODEL ?? "claude-haiku-5-5"; },
  /// Per research turn; a paused turn's continuations count against the same
  /// cap. Searches are billed per use ($0.01 each), so this is the main cost
  /// lever. Fetches are billed only as the tokens they add.
  get maxSearchesPerResearchCall() { return num("FORGE_MAX_SEARCHES", 5); },
  get maxFetchesPerResearchCall() { return num("FORGE_MAX_FETCHES", 4); },
  /// Each fetched page is cut to about this many tokens before the model reads it.
  get maxTokensPerFetch() { return num("FORGE_MAX_FETCH_TOKENS", 4000); },
  get requestsPerMinute() { return num("FORGE_REQUESTS_PER_MINUTE", 30); },
  version: "0.3.0",
};

export function missingConfig(): string[] {
  const missing: string[] = [];
  if (!config.anthropicApiKey) missing.push("ANTHROPIC_API_KEY");
  if (!config.appleTeamID) missing.push("APPLE_TEAM_ID");
  return missing;
}

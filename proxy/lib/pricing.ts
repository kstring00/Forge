// USD per million tokens, from the Claude pricing page at the time of writing.
// The app shows an estimate before a Reality Check and the actual after; both
// come from here. Update when prices change; nothing else depends on them.

export interface ModelPrice {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
}

/// A rate card, not a choice: which model runs each role is set in
/// config/hunch.ts. Every model that file might name needs a row here.
export const prices: Record<string, ModelPrice> = {
  "claude-sonnet-5-5": { input: 2.0, output: 10.0, cacheRead: 0.2, cacheWrite: 2.5 },
  "claude-haiku-5-5": { input: 0.1, output: 0.5, cacheRead: 0.01, cacheWrite: 0.125 },
  "claude-opus-5-5": { input: 4.0, output: 20.0, cacheRead: 0.2, cacheWrite: 5.0 },
};

/// Haiku 5.5 has a second rate card for prompts over 100K tokens (input
/// cached or not). A long research continuation can cross it.
const longPromptRates: Record<string, { threshold: number; price: ModelPrice }> = {
  "claude-haiku-5-5": { threshold: 100_000, price: { input: 0.5, output: 2.5, cacheRead: 0.05, cacheWrite: 0.625 } },
};

/// Web search is billed per search on top of tokens.
export const webSearchUSD = 0.01;

export interface UsageLike {
  input_tokens: number;
  output_tokens: number;
  cache_read_input_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
  server_tool_use?: { web_search_requests?: number | null; web_fetch_requests?: number | null } | null;
}

export function costUSD(model: string, usage: UsageLike): number {
  const prompt = (usage.input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0);
  const long = longPromptRates[model];
  const p = long && prompt > long.threshold ? long.price : prices[model] ?? prices["claude-sonnet-5-5"];
  const perTok = (n: number | null | undefined, rate: number) => ((n ?? 0) / 1_000_000) * rate;
  const searches = usage.server_tool_use?.web_search_requests ?? 0;
  return (
    perTok(usage.input_tokens, p.input) +
    perTok(usage.output_tokens, p.output) +
    perTok(usage.cache_read_input_tokens, p.cacheRead) +
    perTok(usage.cache_creation_input_tokens, p.cacheWrite) +
    searches * webSearchUSD
  );
}

/// A Reality Check is desk research on Haiku (tokens are cheap; the searches,
/// at $0.01 each, are most of its cost) plus one prefill on Sonnet, whose
/// output dominates. Rough but honest: the app shows "about" before its first
/// run, then the average of the user's real runs.
export function realityCheckEstimateUSD(maxSearches = 5): { low: number; high: number } {
  const searchesLow = Math.ceil(maxSearches * 0.6) * webSearchUSD;
  const searchesHigh = maxSearches * webSearchUSD;
  const researchTokens = { low: 0.01, high: 0.02 };
  const prefill = { low: 0.06, high: 0.18 };
  return {
    low: round4(searchesLow + researchTokens.low + prefill.low),
    high: round4(searchesHigh + researchTokens.high + prefill.high),
  };
}

export function round4(n: number): number {
  return Math.round(n * 10_000) / 10_000;
}

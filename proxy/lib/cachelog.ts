// Prompt caching, made visible (decision 0042). Every call logs what the API
// says it read from cache, wrote to it, and read fresh, so Vercel → Logs shows
// whether the stable prefix (house rules, lens, panel instructions, output
// formats) is actually being reused.
export interface CacheUsage {
  input_tokens: number;
  cache_read_input_tokens?: number | null;
  cache_creation_input_tokens?: number | null;
}

export interface CacheLine {
  at: "cache";
  label: string;
  model: string;
  read: number;
  written: number;
  fresh: number;
  /// Share of the prompt served from cache, 0 to 1.
  hitRate: number;
  result: "hit" | "miss";
}

export function cacheLine(label: string, model: string, u: CacheUsage): CacheLine {
  const read = u.cache_read_input_tokens ?? 0;
  const written = u.cache_creation_input_tokens ?? 0;
  const fresh = u.input_tokens ?? 0;
  const total = read + written + fresh;
  return { at: "cache", label, model, read, written, fresh, hitRate: total ? Math.round((read / total) * 1000) / 1000 : 0, result: read > 0 ? "hit" : "miss" };
}

export function logCache(label: string, model: string, u: CacheUsage): void {
  console.log(JSON.stringify(cacheLine(label, model, u)));
}

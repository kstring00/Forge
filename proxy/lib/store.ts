// Shared state for the proxy: attested device keys, one-time challenges,
// per-device and global usage. Upstash Redis (Vercel KV) when its REST env
// vars are set; otherwise an in-memory map, which is per instance and resets
// on every cold start. Health reports which one is in use, so a deployment
// without a store is never mistaken for a protected one.
import { Redis } from "@upstash/redis";

export interface Store {
  readonly kind: "redis" | "memory";
  get<T>(key: string): Promise<T | null>;
  /// Sets a JSON value. `ttlSeconds` expires it.
  set(key: string, value: unknown, ttlSeconds?: number): Promise<void>;
  /// Deletes and returns whether the key existed.
  take(key: string): Promise<boolean>;
  /// Adds to a numeric field of a hash, creating it. Returns the new value.
  incrField(key: string, field: string, by: number, ttlSeconds?: number): Promise<number>;
  /// Every field of a hash as numbers.
  hash(key: string): Promise<Record<string, number>>;
  /// Keys matching a prefix (small sets only: a day's devices).
  keys(prefix: string): Promise<string[]>;
}

class MemoryStore implements Store {
  readonly kind = "memory" as const;
  private values = new Map<string, { value: unknown; expires: number | null }>();
  private hashes = new Map<string, { fields: Map<string, number>; expires: number | null }>();

  private live<T extends { expires: number | null }>(map: Map<string, T>, key: string): T | undefined {
    const v = map.get(key);
    if (!v) return undefined;
    if (v.expires !== null && v.expires < Date.now()) { map.delete(key); return undefined; }
    return v;
  }

  async get<T>(key: string): Promise<T | null> { return (this.live(this.values, key)?.value as T) ?? null; }
  async set(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
    this.values.set(key, { value, expires: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null });
  }
  async take(key: string): Promise<boolean> {
    const had = this.live(this.values, key) !== undefined;
    this.values.delete(key);
    return had;
  }
  async incrField(key: string, field: string, by: number, ttlSeconds?: number): Promise<number> {
    let h = this.live(this.hashes, key);
    if (!h) { h = { fields: new Map(), expires: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null }; this.hashes.set(key, h); }
    const next = (h.fields.get(field) ?? 0) + by;
    h.fields.set(field, next);
    return next;
  }
  async hash(key: string): Promise<Record<string, number>> {
    const h = this.live(this.hashes, key);
    return h ? Object.fromEntries(h.fields) : {};
  }
  async keys(prefix: string): Promise<string[]> {
    return [...this.values.keys(), ...this.hashes.keys()].filter((k) => k.startsWith(prefix));
  }
}

class RedisStore implements Store {
  readonly kind = "redis" as const;
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> { return (await this.redis.get<T>(key)) ?? null; }
  async set(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds) await this.redis.set(key, value, { ex: ttlSeconds });
    else await this.redis.set(key, value);
  }
  async take(key: string): Promise<boolean> { return (await this.redis.del(key)) > 0; }
  async incrField(key: string, field: string, by: number, ttlSeconds?: number): Promise<number> {
    const next = Number.isInteger(by)
      ? await this.redis.hincrby(key, field, by)
      : await this.redis.hincrbyfloat(key, field, by);
    if (ttlSeconds) await this.redis.expire(key, ttlSeconds);
    return Number(next);
  }
  async hash(key: string): Promise<Record<string, number>> {
    const h = (await this.redis.hgetall<Record<string, string | number>>(key)) ?? {};
    return Object.fromEntries(Object.entries(h).map(([k, v]) => [k, Number(v)]));
  }
  async keys(prefix: string): Promise<string[]> {
    const out: string[] = [];
    let cursor = "0";
    do {
      const [next, batch] = await this.redis.scan(cursor, { match: `${prefix}*`, count: 200 });
      out.push(...(batch as string[]));
      cursor = String(next);
    } while (cursor !== "0");
    return out;
  }
}

let shared: Store | null = null;

/// Vercel's KV integration sets KV_REST_API_URL / KV_REST_API_TOKEN; the
/// Upstash marketplace integration sets UPSTASH_REDIS_REST_URL / _TOKEN.
export function store(): Store {
  if (shared) return shared;
  const url = process.env.KV_REST_API_URL ?? process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.KV_REST_API_TOKEN ?? process.env.UPSTASH_REDIS_REST_TOKEN;
  shared = url && token ? new RedisStore(new Redis({ url, token })) : new MemoryStore();
  if (shared.kind === "memory") {
    console.warn(JSON.stringify({ at: "store", note: "no Redis configured; device keys and limits are per instance and reset on cold start" }));
  }
  return shared;
}

/// Tests swap the store for a fresh memory one.
export function useMemoryStore(): Store {
  shared = new MemoryStore();
  return shared;
}

/// Where "today" and "tomorrow" are decided for ceilings and usage. A day
/// that rolled over at UTC midnight would reset at 6 or 7 in the evening in
/// Texas, and "resting until tomorrow" would be wrong for the people reading it.
export function dayTimeZone(): string {
  const tz = (process.env.FORGE_DAY_TIMEZONE ?? "").trim() || "America/Chicago";
  try { new Intl.DateTimeFormat("en-CA", { timeZone: tz }); return tz; } catch { return "America/Chicago"; }
}

/// "2026-11-08" in the day's time zone: when usage and ceilings roll over.
export function dayKey(d: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: dayTimeZone(), year: "numeric", month: "2-digit", day: "2-digit" }).format(d);
}

/// Seconds until the next midnight in the day's time zone, for daily keys' TTL.
export function secondsUntilTomorrow(d: Date = new Date()): number {
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone: dayTimeZone(), hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" }).formatToParts(d);
  const n = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  return Math.max(60, 86_400 - (n("hour") * 3600 + n("minute") * 60 + n("second")));
}

/// The `count` days ending on `last` ("2026-11-08"), oldest first. Calendar arithmetic only.
export function daysEnding(last: string, count: number): string[] {
  const [y, m, d] = last.split("-").map(Number);
  return Array.from({ length: Math.max(0, count) }, (_, i) =>
    new Date(Date.UTC(y, m - 1, d - (count - 1 - i))).toISOString().slice(0, 10));
}

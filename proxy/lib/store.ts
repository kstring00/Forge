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

/// "2026-11-08" in UTC: the day usage and ceilings roll over.
export function dayKey(d: Date = new Date()): string {
  return d.toISOString().slice(0, 10);
}

/// Seconds until the next UTC midnight, for daily keys' TTL (plus a day of slack for the admin view).
export function secondsUntilTomorrow(d: Date = new Date()): number {
  const next = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1);
  return Math.max(60, Math.floor((next - d.getTime()) / 1000));
}

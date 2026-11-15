// What one device may spend, and what the whole proxy may spend in a day.
// Both fail politely: the app shows "The panel is resting until tomorrow."
import { config } from "./env.js";
import { HttpError } from "./http.js";
import { dayKey, secondsUntilTomorrow, store } from "./store.js";
import type { DeviceIdentity } from "./auth.js";
import { DeviceCheckError, deviceCheckConfigured, queryBits, updateBits } from "./devicecheck.js";

export const restingLine = "The panel is resting until tomorrow.";

/// Decision 0027: the first Reality Check on a device is free and counts
/// against no allowance. Remembered in Apple's per-device bits when the app
/// sends a DeviceCheck token (so a reinstall does not reset it), and in the
/// store by device id otherwise.
export interface CheckStart {
  free: boolean;
}

const freeKey = (device: DeviceIdentity) => `free:${device.id}`;

/// Whether this device has had its free check, and how we know.
async function freeCheckUsed(device: DeviceIdentity, deviceToken: string | null): Promise<{ used: boolean; via: "apple" | "store" }> {
  if (deviceToken && deviceCheckConfigured()) {
    try {
      const bits = await queryBits(deviceToken);
      return { used: bits?.bit0 ?? false, via: "apple" };
    } catch (err) {
      if (!(err instanceof DeviceCheckError)) throw err;
      console.error(JSON.stringify({ at: "freeCheck", note: "Apple bits unavailable, falling back to the store", code: err.code }));
    }
  }
  return { used: Boolean(await store().get<boolean>(freeKey(device))), via: "store" };
}

async function markFreeCheckUsed(device: DeviceIdentity, deviceToken: string | null, via: "apple" | "store"): Promise<void> {
  await store().set(freeKey(device), true);   // no TTL: for good
  if (via === "apple" && deviceToken) {
    try { await updateBits(deviceToken, { bit0: true, bit1: false }); } catch (err) {
      if (!(err instanceof DeviceCheckError)) throw err;
      console.error(JSON.stringify({ at: "freeCheck", note: "Apple bits not updated; the store remembers", code: err.code }));
    }
  }
}

const ttl = () => secondsUntilTomorrow() + 86_400 * 2;   // keep two days for the usage view

export function usageKey(device: DeviceIdentity, day = dayKey()): string {
  return `usage:${day}:${device.id}`;
}

/// A Reality Check starts. The device's first is free and counts against no
/// allowance; after that each counts against the daily allowance and is
/// refused past it. Developer tokens are neither free nor limited. The daily
/// spend ceiling applies to everything, free included.
export async function startCheck(device: DeviceIdentity, deviceToken: string | null = null): Promise<CheckStart> {
  await refuseIfResting();
  if (device.door === "dev") return { free: false };
  const s = store();
  const { used, via } = await freeCheckUsed(device, deviceToken);
  if (!used) {
    await markFreeCheckUsed(device, deviceToken, via);
    await s.incrField(usageKey(device), "freeChecks", 1, ttl());
    console.log(JSON.stringify({ at: "freeCheck", device: device.id, via }));
    return { free: true };
  }
  const n = await s.incrField(usageKey(device), "checks", 1, ttl());
  if (n > config.checksPerDevicePerDay) {
    await s.incrField(usageKey(device), "checks", -1);
    throw new HttpError(429, "device_limit", `That's ${config.checksPerDevicePerDay} Reality Checks today. ${restingLine}`);
  }
  return { free: false };
}

/// Every call: refuse when today's spend across all devices has reached the ceiling.
export async function refuseIfResting(): Promise<void> {
  const spent = (await store().hash(`spend:${dayKey()}`)).usd ?? 0;
  if (spent >= config.dailySpendUSD) {
    throw new HttpError(429, "panel_resting", restingLine);
  }
}

/// After a call: what it cost, on the device and on the day.
export async function recordUsage(device: DeviceIdentity, action: string, costUSD: number): Promise<void> {
  const s = store();
  const key = usageKey(device);
  await s.incrField(key, "calls", 1, ttl());
  await s.incrField(key, `calls:${action}`, 1, ttl());
  if (costUSD > 0) {
    await s.incrField(key, "usd", costUSD, ttl());
    await s.incrField(`spend:${dayKey()}`, "usd", costUSD, ttl());
  }
  await s.set(`device:seen:${device.id}`, { door: device.door, at: new Date().toISOString() });
  console.log(JSON.stringify({ at: "usage", device: device.id, door: device.door, action, costUSD }));
}

export interface DayUsage {
  day: string;
  spendUSD: number;
  ceilingUSD: number;
  devices: Array<{ id: string; checks: number; freeChecks: number; calls: number; usd: number; byAction: Record<string, number> }>;
}

/// The developer's view of a day: every device, what it did, what it cost.
export async function usageFor(day: string): Promise<DayUsage> {
  const s = store();
  const keys = await s.keys(`usage:${day}:`);
  const devices = await Promise.all(keys.map(async (k) => {
    const h = await s.hash(k);
    const byAction: Record<string, number> = {};
    for (const [f, v] of Object.entries(h)) if (f.startsWith("calls:")) byAction[f.slice(6)] = v;
    return { id: k.slice(`usage:${day}:`.length), checks: h.checks ?? 0, freeChecks: h.freeChecks ?? 0, calls: h.calls ?? 0, usd: Math.round((h.usd ?? 0) * 10_000) / 10_000, byAction };
  }));
  devices.sort((a, b) => b.usd - a.usd);
  const spend = (await s.hash(`spend:${day}`)).usd ?? 0;
  return { day, spendUSD: Math.round(spend * 10_000) / 10_000, ceilingUSD: config.dailySpendUSD, devices };
}

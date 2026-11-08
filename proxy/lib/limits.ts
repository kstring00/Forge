// What one device may spend, and what the whole proxy may spend in a day.
// Both fail politely: the app shows "The panel is resting until tomorrow."
import { config } from "./env.js";
import { HttpError } from "./http.js";
import { dayKey, secondsUntilTomorrow, store } from "./store.js";
import type { DeviceIdentity } from "./auth.js";

export const restingLine = "The panel is resting until tomorrow.";

const ttl = () => secondsUntilTomorrow() + 86_400 * 2;   // keep two days for the usage view

export function usageKey(device: DeviceIdentity, day = dayKey()): string {
  return `usage:${day}:${device.id}`;
}

/// A Reality Check starts: count it against the device's daily allowance and
/// refuse past it. Developer tokens are not limited.
export async function startCheck(device: DeviceIdentity): Promise<void> {
  await refuseIfResting();
  if (device.door === "dev") return;
  const s = store();
  const n = await s.incrField(usageKey(device), "checks", 1, ttl());
  if (n > config.checksPerDevicePerDay) {
    await s.incrField(usageKey(device), "checks", -1);
    throw new HttpError(429, "device_limit", `That's ${config.checksPerDevicePerDay} Reality Checks today. ${restingLine}`);
  }
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
  devices: Array<{ id: string; checks: number; calls: number; usd: number; byAction: Record<string, number> }>;
}

/// The developer's view of a day: every device, what it did, what it cost.
export async function usageFor(day: string): Promise<DayUsage> {
  const s = store();
  const keys = await s.keys(`usage:${day}:`);
  const devices = await Promise.all(keys.map(async (k) => {
    const h = await s.hash(k);
    const byAction: Record<string, number> = {};
    for (const [f, v] of Object.entries(h)) if (f.startsWith("calls:")) byAction[f.slice(6)] = v;
    return { id: k.slice(`usage:${day}:`.length), checks: h.checks ?? 0, calls: h.calls ?? 0, usd: Math.round((h.usd ?? 0) * 10_000) / 10_000, byAction };
  }));
  devices.sort((a, b) => b.usd - a.usd);
  const spend = (await s.hash(`spend:${day}`)).usd ?? 0;
  return { day, spendUSD: Math.round(spend * 10_000) / 10_000, ceilingUSD: config.dailySpendUSD, devices };
}

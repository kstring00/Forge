// What one device may spend, and what the whole proxy may spend in a day.
// Both fail politely: the app shows "The panel is resting until tomorrow."
//
// The day's ceiling (FORGE_DAILY_SPEND_USD) is counted from actual token
// usage. At 70% of it, free-tier users can no longer start a check; paid
// plans carry on to 100%, where everything stops until tomorrow. The owner is
// emailed once when a day reaches each mark.
import { config } from "./env.js";
import { sendOwnerEmail } from "./email.js";
import { addToDay, dayTotalsKey, isCheckAction } from "./ledger.js";
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
export async function startCheck(device: DeviceIdentity, deviceToken: string | null = null, plan: Plan = "free"): Promise<CheckStart> {
  const tier = tierOf(device, plan);
  await refuseIfResting(tier, true);
  if (device.door === "dev") { await addToDay({ checks: 1 }); return { free: false }; }
  const s = store();
  const { used, via } = await freeCheckUsed(device, deviceToken);
  if (!used) {
    await markFreeCheckUsed(device, deviceToken, via);
    await s.incrField(usageKey(device), "freeChecks", 1, ttl());
    await addToDay({ checks: 1, freeFirstChecks: 1 });
    console.log(JSON.stringify({ at: "freeCheck", device: device.id, via }));
    return { free: true };
  }
  const n = await s.incrField(usageKey(device), "checks", 1, ttl());
  if (n > config.checksPerDevicePerDay) {
    await s.incrField(usageKey(device), "checks", -1);
    throw new HttpError(429, "device_limit", `That's ${config.checksPerDevicePerDay} Reality Checks today. ${restingLine}`);
  }
  await addToDay({ checks: 1 });
  return { free: false };
}

/// What the app says its plan is. The app is attested, so a genuine copy
/// reports its real plan; the proxy does not yet verify the App Store receipt
/// itself (that arrives with the server-side ledger).
export type Plan = "free" | "plus" | "pro";
export type Tier = "free" | "paid";

/// Developer tokens are the owner's own builds: never held back at the free mark.
export function tierOf(device: DeviceIdentity, plan: Plan | undefined): Tier {
  return device.door === "dev" || plan === "plus" || plan === "pro" ? "paid" : "free";
}

export type PanelState = "open" | "paidOnly" | "resting";

/// Where the day stands against the ceiling.
export function panelState(spentUSD: number, ceilingUSD = config.dailySpendUSD, freeShare = config.freeTierShare): PanelState {
  if (spentUSD >= ceilingUSD) return "resting";
  return spentUSD >= ceilingUSD * freeShare ? "paidOnly" : "open";
}

export async function spentToday(): Promise<number> {
  return (await store().hash(dayTotalsKey(dayKey()))).usd ?? 0;
}

/// Every call: refuse when today's spend has reached the ceiling. A new check
/// from a free-tier user is refused from 70% of it; work already under way
/// (the rest of a check, follow-ups on a checked idea) carries on to 100%.
export async function refuseIfResting(tier: Tier = "paid", startingCheck = false): Promise<void> {
  const state = panelState(await spentToday());
  if (state === "resting" || (state === "paidOnly" && tier === "free" && startingCheck)) {
    throw new HttpError(429, "panel_resting", restingLine);
  }
}

/// After a call: what it cost, on the device and on the day. Emails the owner
/// the first time a day's spend reaches each mark.
export async function recordUsage(device: DeviceIdentity, action: string, costUSD: number): Promise<void> {
  const s = store();
  const key = usageKey(device);
  await s.incrField(key, "calls", 1, ttl());
  await s.incrField(key, `calls:${action}`, 1, ttl());
  if (costUSD > 0) await s.incrField(key, "usd", costUSD, ttl());
  const after = await addToDay({ calls: 1, usd: costUSD > 0 ? costUSD : 0, checkUSD: costUSD > 0 && isCheckAction(action) ? costUSD : 0 });
  await s.set(`device:seen:${device.id}`, { door: device.door, at: new Date().toISOString() });
  console.log(JSON.stringify({ at: "usage", device: device.id, door: device.door, action, costUSD }));
  if (costUSD > 0) await alertOnCrossing(after - costUSD, after);
}

const money = (n: number) => `$${n.toFixed(2)}`;

/// One email per mark per day, however many calls cross it at once.
async function alertOnCrossing(before: number, after: number): Promise<void> {
  const ceiling = config.dailySpendUSD;
  const freeMark = ceiling * config.freeTierShare;
  const day = dayKey();
  const crossed = (mark: number) => before < mark && after >= mark;
  const first = async (name: string) => (await store().incrField(`alerts:${day}`, name, 1, ttl())) === 1;
  if (crossed(ceiling) && await first("ceiling")) {
    await sendOwnerEmail({
      subject: `Hunch: today's spend hit the ${money(ceiling)} ceiling`,
      text: `Today (${day}) the proxy has spent ${money(after)} of its ${money(ceiling)} daily ceiling.\n\nEvery check is now refused with "${restingLine}" until midnight. Nothing else is needed; it reopens by itself.\n\nTo raise the ceiling: Vercel → the proxy project → Settings → Environment Variables → FORGE_DAILY_SPEND_USD, then redeploy.`,
    });
  } else if (crossed(freeMark) && freeMark < ceiling && await first("free")) {
    await sendOwnerEmail({
      subject: `Hunch: today's spend passed ${Math.round(config.freeTierShare * 100)}% of the ceiling`,
      text: `Today (${day}) the proxy has spent ${money(after)} of its ${money(ceiling)} daily ceiling.\n\nFree-tier users can no longer start a check today; they see "${restingLine}". Paid plans carry on until ${money(ceiling)}.`,
    });
  }
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
  const spend = (await s.hash(dayTotalsKey(day))).usd ?? 0;
  return { day, spendUSD: Math.round(spend * 10_000) / 10_000, ceilingUSD: config.dailySpendUSD, devices };
}

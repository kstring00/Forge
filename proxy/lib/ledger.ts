// The proxy's own books: what each day cost and how many checks it served,
// from actual token usage. One small hash per day, kept for over a year, so
// the owner's Spend view and dashboard can add up weeks and months.
import { dayKey, daysEnding, store } from "./store.js";

/// Day totals are tiny; keep them long enough for a year-over-year look.
const keepSeconds = 400 * 86_400;

export const dayTotalsKey = (day: string) => `spend:${day}`;
export const lifetimeKey = "spend:lifetime";

export async function lifetimeSpendUSD(): Promise<number> {
  return (await store().hash(lifetimeKey)).usd ?? 0;
}

/// Who was active each day, by tier, for the owner's dashboard. Kept 45 days.
const activeKey = (day: string, tier: "free" | "paid") => `active:${day}:${tier}`;
const knownDevicesKey = "devices:known";

/// A real device made a call. Returns true the first time this device is ever seen.
export async function noteDevice(deviceID: string, tier: "free" | "paid", day = dayKey()): Promise<boolean> {
  const s = store();
  await s.addToSet(activeKey(day, tier), deviceID, 45 * 86_400);
  const fresh = await s.addToSet(knownDevicesKey, deviceID);
  if (fresh) await s.incrField(dayTotalsKey(day), "newDevices", 1, keepSeconds);
  return fresh;
}

export interface ActiveDevices { total: number; free: number; paid: number }

/// Distinct devices active on any of `days`. A device that was paid on any of them counts as paid.
export async function activeDevices(days: string[]): Promise<ActiveDevices> {
  const s = store();
  const [free, paid] = await Promise.all((["free", "paid"] as const).map(async (tier) =>
    new Set((await Promise.all(days.map((d) => s.members(activeKey(d, tier))))).flat())));
  const freeOnly = [...free].filter((id) => !paid.has(id)).length;
  return { total: freeOnly + paid.size, free: freeOnly, paid: paid.size };
}

export interface DayTotals {
  day: string;
  usd: number;
  /// Reality Checks started (free first checks included).
  checks: number;
  freeFirstChecks: number;
  calls: number;
  /// Dollars that went on checks themselves (research and the panel's take), not follow-ups.
  checkUSD: number;
  /// Devices seen for the first time that day.
  newDevices: number;
}

const round4 = (n: number) => Math.round(n * 10_000) / 10_000;

/// Adds to today's totals. Returns the day's dollars after the add.
export async function addToDay(fields: Record<string, number>, day = dayKey()): Promise<number> {
  const s = store();
  let usd = NaN;
  for (const [field, by] of Object.entries(fields)) {
    if (!by) continue;
    const next = await s.incrField(dayTotalsKey(day), field, by, keepSeconds);
    if (field === "usd") {
      usd = next;
      // Everything ever spent, so a credit balance set by hand can be counted down from.
      await s.incrField(lifetimeKey, "usd", by);
    }
  }
  return Number.isNaN(usd) ? (await s.hash(dayTotalsKey(day))).usd ?? 0 : usd;
}

/// Which actions are the check itself. Everything else is a follow-up on a checked idea.
const checkActions = new Set(["research", "prefill", "realityCheck"]);
export const isCheckAction = (action: string) => checkActions.has(action);

export async function dayTotals(day: string): Promise<DayTotals> {
  const h = await store().hash(dayTotalsKey(day));
  return {
    day,
    usd: round4(h.usd ?? 0),
    checks: h.checks ?? 0,
    freeFirstChecks: h.freeFirstChecks ?? 0,
    calls: h.calls ?? 0,
    checkUSD: round4(h.checkUSD ?? 0),
    newDevices: h.newDevices ?? 0,
  };
}

export async function totalsFor(days: string[]): Promise<DayTotals[]> {
  return Promise.all(days.map(dayTotals));
}

export interface Period { from: string; to: string; days: number; usd: number; checks: number; checkUSD: number; averagePerCheckUSD: number | null }

export function sumPeriod(totals: DayTotals[]): Period {
  const usd = round4(totals.reduce((a, t) => a + t.usd, 0));
  const checks = totals.reduce((a, t) => a + t.checks, 0);
  const checkUSD = round4(totals.reduce((a, t) => a + t.checkUSD, 0));
  return {
    from: totals[0]?.day ?? "", to: totals[totals.length - 1]?.day ?? "", days: totals.length,
    usd, checks, checkUSD,
    averagePerCheckUSD: checks > 0 ? round4(checkUSD / checks) : null,
  };
}

/// Monday of the week `day` is in, and the first of its month. Calendar arithmetic only.
export function weekStart(day: string): string {
  const [y, m, d] = day.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  const sinceMonday = (date.getUTCDay() + 6) % 7;
  return new Date(Date.UTC(y, m - 1, d - sinceMonday)).toISOString().slice(0, 10);
}
export const monthStart = (day: string) => `${day.slice(0, 8)}01`;

function daysBetween(from: string, to: string): number {
  const t = (s: string) => { const [y, m, d] = s.split("-").map(Number); return Date.UTC(y, m - 1, d); };
  return Math.round((t(to) - t(from)) / 86_400_000) + 1;
}

/// Today, this week (from Monday) and this month (from the 1st), up to `today`.
export async function spendSummary(today = dayKey()): Promise<{ today: Period; week: Period; month: Period }> {
  const month = await totalsFor(daysEnding(today, daysBetween(monthStart(today), today)));
  const weekFrom = weekStart(today);
  // A week that began last month reaches back before the 1st.
  const week = weekFrom < monthStart(today)
    ? await totalsFor(daysEnding(today, daysBetween(weekFrom, today)))
    : month.filter((t) => t.day >= weekFrom);
  return { today: sumPeriod(month.slice(-1)), week: sumPeriod(week), month: sumPeriod(month) };
}

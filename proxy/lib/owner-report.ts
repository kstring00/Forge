// Everything the owner's dashboard shows, gathered from the day records and
// the per-device activity the proxy keeps as it serves calls.
import { config } from "./env.js";
import { creditStatus, dailyPace, type CreditStatus } from "./credit.js";
import { activeDevices, monthStart, sumPeriod, totalsFor, weekStart, type ActiveDevices, type DayTotals, type Period } from "./ledger.js";
import { panelState, type PanelState } from "./limits.js";
import { dayKey, dayTimeZone, daysEnding, store } from "./store.js";

export interface OwnerReport {
  day: string;
  timeZone: string;
  store: "redis" | "memory";
  ceilingUSD: number;
  freeTierStopsAtUSD: number;
  state: PanelState;
  devices: { today: ActiveDevices; week: ActiveDevices; month: ActiveDevices };
  checks: { today: Period; week: Period; month: Period };
  spend: {
    monthUSD: number;
    /// Dollars a day over the last seven days.
    dailyPaceUSD: number;
    /// This month so far plus the pace for every day left in it.
    projectedMonthEndUSD: number;
    daysLeftInMonth: number;
  };
  /// The last 14 days, oldest first.
  newDevices: Array<{ day: string; count: number }>;
  credit: CreditStatus | null;
}

const round2 = (n: number) => Math.round(n * 100) / 100;

function lastDayOfMonth(day: string): number {
  const [y, m] = day.split("-").map(Number);
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

export async function ownerReport(today = dayKey()): Promise<OwnerReport> {
  // Thirty days covers the month view except on the 31st; take whichever reaches further back.
  const dayOfMonth = Number(today.slice(8, 10));
  const span = Math.max(30, dayOfMonth);
  const days = daysEnding(today, span);
  const totals = await totalsFor(days);
  const from = (start: string): DayTotals[] => totals.filter((t) => t.day >= start);

  const [devToday, devWeek, devMonth, credit] = await Promise.all([
    activeDevices([today]), activeDevices(daysEnding(today, 7)), activeDevices(daysEnding(today, 30)), creditStatus(today),
  ]);
  const month = from(monthStart(today));
  const pace = dailyPace(totals.slice(-7));
  const monthUSD = month.reduce((a, t) => a + t.usd, 0);
  const daysLeftInMonth = lastDayOfMonth(today) - dayOfMonth;
  const ceiling = config.dailySpendUSD;
  const todayTotals = totals.slice(-1);
  return {
    day: today,
    timeZone: dayTimeZone(),
    store: store().kind,
    ceilingUSD: ceiling,
    freeTierStopsAtUSD: round2(ceiling * config.freeTierShare),
    state: panelState(todayTotals[0]?.usd ?? 0),
    devices: { today: devToday, week: devWeek, month: devMonth },
    checks: { today: sumPeriod(todayTotals), week: sumPeriod(from(weekStart(today))), month: sumPeriod(month) },
    spend: {
      monthUSD: round2(monthUSD),
      dailyPaceUSD: Math.round(pace * 10_000) / 10_000,
      projectedMonthEndUSD: round2(monthUSD + pace * daysLeftInMonth),
      daysLeftInMonth,
    },
    newDevices: totals.slice(-14).map((t) => ({ day: t.day, count: t.newDevices })),
    credit,
  };
}

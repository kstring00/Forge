// The owner's credit balance. Anthropic does not tell the proxy what is left
// on the account, so the owner types in the balance when they top up, and the
// proxy counts down from there with what it has spent since. From the pace of
// the last seven days it says how many days are left, and emails the owner
// when that drops below 10 and again below 3.
import { config } from "./env.js";
import { sendOwnerEmail } from "./email.js";
import { lifetimeSpendUSD, totalsFor, type DayTotals } from "./ledger.js";
import { dayKey, daysEnding, store } from "./store.js";

const creditKey = "owner:credit";
const checkedKey = "owner:credit:checked";

export interface CreditRecord {
  /// The balance the owner entered.
  usd: number;
  /// When they entered it.
  setAt: string;
  /// Everything the proxy had ever spent at that moment.
  spentAtSet: number;
  /// Which low-credit emails have gone out since.
  alerted: { ten: boolean; three: boolean };
}

export interface CreditStatus {
  enteredUSD: number;
  setAt: string;
  spentSinceUSD: number;
  remainingUSD: number;
  /// Dollars a day, over the last seven days (fewer when the proxy is newer than that).
  dailyPaceUSD: number;
  /// Null when nothing has been spent lately: there is no pace to divide by.
  daysLeft: number | null;
}

const round2 = (n: number) => Math.round(n * 100) / 100;

/// The daily pace: the last seven days' spend over the days since spending
/// began inside that window. Two days into a beta, the pace is the average of
/// those two days, not a seventh of them.
export function dailyPace(lastSeven: DayTotals[]): number {
  const firstActive = lastSeven.findIndex((d) => d.usd > 0);
  if (firstActive < 0) return 0;
  const active = lastSeven.slice(firstActive);
  return active.reduce((a, d) => a + d.usd, 0) / active.length;
}

export async function setCredit(usd: number, now = new Date()): Promise<CreditRecord> {
  const record: CreditRecord = { usd: round2(Math.max(0, usd)), setAt: now.toISOString(), spentAtSet: await lifetimeSpendUSD(), alerted: { ten: false, three: false } };
  await store().set(creditKey, record);
  return record;
}

export async function creditStatus(today = dayKey()): Promise<CreditStatus | null> {
  const record = await store().get<CreditRecord>(creditKey);
  if (!record) return null;
  const spentSince = Math.max(0, (await lifetimeSpendUSD()) - record.spentAtSet);
  const remaining = record.usd - spentSince;
  const pace = dailyPace(await totalsFor(daysEnding(today, 7)));
  return {
    enteredUSD: record.usd,
    setAt: record.setAt,
    spentSinceUSD: round2(spentSince),
    remainingUSD: round2(remaining),
    dailyPaceUSD: Math.round(pace * 10_000) / 10_000,
    daysLeft: pace > 0 ? Math.max(0, Math.round((remaining / pace) * 10) / 10) : null,
  };
}

/// After a call that cost something: is the credit running low? Looked at no
/// more than once every half hour, and each mark emails once until the owner
/// enters a new balance.
export async function checkCreditAlerts(): Promise<void> {
  try {
    const s = store();
    if (await s.get<boolean>(checkedKey)) return;
    await s.set(checkedKey, true, 30 * 60);
    const record = await s.get<CreditRecord>(creditKey);
    if (!record) return;
    const status = await creditStatus();
    if (!status || status.daysLeft === null) return;
    const money = (n: number) => `$${n.toFixed(2)}`;
    const body = (mark: number) =>
      `About ${status.daysLeft} days of credit are left at the current pace (below ${mark}).\n\n` +
      `Balance entered: ${money(status.enteredUSD)} on ${status.setAt.slice(0, 10)}\n` +
      `Spent since: ${money(status.spentSinceUSD)}\nLeft: ${money(status.remainingUSD)}\n` +
      `Pace: ${money(status.dailyPaceUSD)} a day over the last week\n\n` +
      `After you top up at Anthropic, enter the new balance on the dashboard (/owner) so the count starts again.` +
      (config.dailySpendUSD ? `\n\nThe daily ceiling is ${money(config.dailySpendUSD)}.` : "");
    if (status.daysLeft < 3 && !record.alerted.three) {
      await s.set(creditKey, { ...record, alerted: { ten: true, three: true } });
      await sendOwnerEmail({ subject: `Hunch: under 3 days of credit left (${money(status.remainingUSD)})`, text: body(3) });
    } else if (status.daysLeft < 10 && !record.alerted.ten) {
      await s.set(creditKey, { ...record, alerted: { ...record.alerted, ten: true } });
      await sendOwnerEmail({ subject: `Hunch: under 10 days of credit left (${money(status.remainingUSD)})`, text: body(10) });
    }
  } catch (err) {
    console.error(JSON.stringify({ at: "credit", error: String(err).slice(0, 200) }));
  }
}

/// Tests look again straight away.
export async function forgetCreditCheck(): Promise<void> { await store().take(checkedKey); }

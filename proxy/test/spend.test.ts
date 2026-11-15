import { test } from "node:test";
import assert from "node:assert/strict";

process.env.ANTHROPIC_API_KEY = "sk-test";
process.env.APPLE_TEAM_ID = "ABCDE12345";
process.env.FORGE_PROXY_TOKEN = "dev-token-0123456789abcdef";
process.env.FORGE_DAILY_SPEND_USD = "3";
process.env.FORGE_CHECKS_PER_DEVICE_PER_DAY = "50";
process.env.FORGE_OWNER_SECRET = "owner-secret-0123456789";
delete process.env.FORGE_FREE_TIER_SHARE;
delete process.env.FORGE_DAY_TIMEZONE;

const { useMemoryStore, dayKey, daysEnding, secondsUntilTomorrow } = await import("../lib/store.js");
const { startCheck, recordUsage, refuseIfResting, panelState, tierOf, restingLine } = await import("../lib/limits.js");
const { spendSummary, weekStart, monthStart, addToDay, sumPeriod, totalsFor } = await import("../lib/ledger.js");
const { useEmailTransport } = await import("../lib/email.js");
const { HttpError } = await import("../lib/http.js");
const { config } = await import("../lib/env.js");
const { isOwnerSecret } = await import("../lib/owner.js");

const free = { id: "free-phone", door: "appattest" as const };
const paid = { id: "paid-phone", door: "appattest" as const };
const resting = (e: unknown) => e instanceof HttpError && e.status === 429 && e.code === "panel_resting" && e.message === restingLine;

test("the ceiling is $3 unless set, and free checks stop at 70% of it", () => {
  assert.equal(config.dailySpendUSD, 3);
  assert.equal(config.freeTierShare, 0.7);
  assert.equal(panelState(0), "open");
  assert.equal(panelState(2.09), "open");
  assert.equal(panelState(2.1), "paidOnly");
  assert.equal(panelState(2.99), "paidOnly");
  assert.equal(panelState(3), "resting");
  assert.equal(panelState(9), "resting");
  assert.equal(tierOf(free, undefined), "free", "an app that says nothing is free");
  assert.equal(tierOf(free, "free"), "free");
  assert.equal(tierOf(paid, "plus"), "paid");
  assert.equal(tierOf(paid, "pro"), "paid");
  assert.equal(tierOf({ id: "dev:1", door: "dev" }, undefined), "paid", "the owner's own builds are never held back at 70%");
});

test("at 70% free users cannot start a check, paid users can; at 100% nobody can; the owner is emailed once at each mark", async () => {
  useMemoryStore();
  const sent: { subject: string; text: string }[] = [];
  useEmailTransport(async (e) => { sent.push(e); return true; });

  // Under 70%: everyone starts a check.
  await startCheck(free, null, "free");
  await startCheck(paid, null, "plus");
  await recordUsage(paid, "research", 1.0);
  await recordUsage(paid, "prefill", 1.0);
  assert.equal(sent.length, 0, "$2.00 of $3.00 is under the mark");

  // Crossing 70% ($2.10).
  await recordUsage(free, "research", 0.15);
  assert.equal(sent.length, 1);
  assert.match(sent[0].subject, /passed 70% of the ceiling/);
  assert.match(sent[0].text, /\$2\.15 of its \$3\.00/);
  await recordUsage(free, "prefill", 0.05);
  assert.equal(sent.length, 1, "one email per mark per day");

  // A free user's new check rests; their check already under way and their follow-ups carry on.
  await assert.rejects(startCheck({ id: "another-free-phone", door: "appattest" }, null, "free"), resting);
  await assert.rejects(startCheck(free, null, undefined), resting);
  await refuseIfResting("free", false);
  // A paid user still starts one.
  await startCheck(paid, null, "pro");
  await refuseIfResting("paid", true);

  // Crossing 100%.
  await recordUsage(paid, "research", 0.9);
  assert.equal(sent.length, 2);
  assert.match(sent[1].subject, /hit the \$3\.00 ceiling/);
  await assert.rejects(startCheck(paid, null, "pro"), resting);
  await assert.rejects(refuseIfResting("paid", false), resting);
  await assert.rejects(refuseIfResting("free", false), resting);
  await recordUsage(paid, "launchPlan", 0.2);
  assert.equal(sent.length, 2, "nothing more is sent today");

  useEmailTransport(null);
});

test("one large call that jumps both marks sends the ceiling email, not two", async () => {
  useMemoryStore();
  const sent: { subject: string }[] = [];
  useEmailTransport(async (e) => { sent.push(e); return true; });
  await recordUsage(paid, "prefill", 3.5);
  assert.equal(sent.length, 1);
  assert.match(sent[0].subject, /ceiling/);
  useEmailTransport(null);
});

test("an email that cannot be sent never fails the request", async () => {
  useMemoryStore();
  useEmailTransport(async () => { throw new Error("network down"); });
  await recordUsage(paid, "prefill", 2.5);
  useEmailTransport(null);
  // And with no key configured the real sender just logs.
  delete process.env.RESEND_API_KEY;
  await recordUsage(paid, "prefill", 1);
});

test("the ledger adds up today, this week from Monday, and this month", async () => {
  useMemoryStore();
  // Wednesday 2026-11-11. The week began Monday the 9th; the month on the 1st.
  assert.equal(weekStart("2026-11-11"), "2026-11-09");
  assert.equal(weekStart("2026-11-09"), "2026-11-09", "Monday is its own start");
  assert.equal(weekStart("2026-11-15"), "2026-11-09", "Sunday closes the week");
  assert.equal(weekStart("2026-11-01"), "2026-10-26", "a week can begin last month");
  assert.equal(monthStart("2026-11-11"), "2026-11-01");
  assert.deepEqual(daysEnding("2026-03-02", 4), ["2026-02-27", "2026-02-28", "2026-03-01", "2026-03-02"]);

  await addToDay({ usd: 1.0, checks: 5, checkUSD: 0.9 }, "2026-11-03");
  await addToDay({ usd: 0.5, checks: 2, checkUSD: 0.4 }, "2026-11-09");
  await addToDay({ usd: 0.25, checks: 1, checkUSD: 0.17 }, "2026-11-11");
  await addToDay({ usd: 9, checks: 9 }, "2026-10-31");
  const s = await spendSummary("2026-11-11");
  assert.equal(s.today.usd, 0.25);
  assert.equal(s.today.checks, 1);
  assert.equal(s.week.usd, 0.75);
  assert.equal(s.week.from, "2026-11-09");
  assert.equal(s.month.usd, 1.75);
  assert.equal(s.month.checks, 8);
  assert.equal(s.month.from, "2026-11-01");
  assert.equal(s.month.averagePerCheckUSD, 0.1838, "from what the checks themselves cost");

  // On the 1st, a week that began in October reaches back into it.
  const first = await spendSummary("2026-11-01");
  assert.equal(first.week.from, "2026-10-26");
  assert.equal(first.week.usd, 9);
  assert.equal(first.month.usd, 0);
  assert.equal(sumPeriod(await totalsFor([])).averagePerCheckUSD, null);
});

test("recordUsage keeps the day's books: dollars, calls, and what the checks themselves cost", async () => {
  useMemoryStore();
  useEmailTransport(async () => true);
  await startCheck(free, null, "free");
  await recordUsage(free, "research", 0.108);
  await recordUsage(free, "prefill", 0.075);
  await recordUsage(free, "launchPlan", 0.02);
  const s = await spendSummary();
  assert.equal(s.today.usd, 0.203);
  assert.equal(s.today.checks, 1);
  assert.equal(s.today.checkUSD, 0.183, "the launch plan is a follow-up, not part of the check");
  assert.equal(s.today.averagePerCheckUSD, 0.183);
  useEmailTransport(null);
});

test("the day rolls over at midnight in the owner's time zone, not UTC", () => {
  // 03:30 UTC on Nov 12 is still the evening of Nov 11 in Texas.
  const lateEvening = new Date("2026-11-12T03:30:00Z");
  assert.equal(dayKey(lateEvening), "2026-11-11");
  assert.equal(secondsUntilTomorrow(lateEvening), 2.5 * 3600);
  assert.equal(dayKey(new Date("2026-11-12T06:00:00Z")), "2026-11-12", "midnight Central (CST is UTC-6)");
  process.env.FORGE_DAY_TIMEZONE = "UTC";
  assert.equal(dayKey(lateEvening), "2026-11-12");
  process.env.FORGE_DAY_TIMEZONE = "Not/AZone";
  assert.equal(dayKey(lateEvening), "2026-11-11", "a bad zone falls back to Central");
  delete process.env.FORGE_DAY_TIMEZONE;
});

test("the owner's secret: long, exact, and FORGE_ADMIN_TOKEN still works as the old name", () => {
  assert.equal(isOwnerSecret("owner-secret-0123456789"), true);
  assert.equal(isOwnerSecret("owner-secret-012345678X"), false);
  assert.equal(isOwnerSecret(""), false);
  process.env.FORGE_OWNER_SECRET = "short";
  assert.equal(config.ownerSecret, "", "a short secret is no secret");
  assert.equal(isOwnerSecret("short"), false);
  delete process.env.FORGE_OWNER_SECRET;
  process.env.FORGE_ADMIN_TOKEN = "admin-token-0123456789";
  assert.equal(isOwnerSecret("admin-token-0123456789"), true);
  delete process.env.FORGE_ADMIN_TOKEN;
  process.env.FORGE_OWNER_SECRET = "owner-secret-0123456789";
});

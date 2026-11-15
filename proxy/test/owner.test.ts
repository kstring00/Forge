import { test } from "node:test";
import assert from "node:assert/strict";

process.env.ANTHROPIC_API_KEY = "sk-test";
process.env.APPLE_TEAM_ID = "ABCDE12345";
process.env.FORGE_PROXY_TOKEN = "dev-token-0123456789abcdef";
process.env.FORGE_DAILY_SPEND_USD = "3";
process.env.FORGE_CHECKS_PER_DEVICE_PER_DAY = "50";
process.env.FORGE_OWNER_SECRET = "owner-secret-0123456789";
delete process.env.FORGE_DAY_TIMEZONE;

const { useMemoryStore, dayKey, daysEnding } = await import("../lib/store.js");
const { addToDay, noteDevice, activeDevices } = await import("../lib/ledger.js");
const { recordUsage, startCheck } = await import("../lib/limits.js");
const { setCredit, creditStatus, dailyPace, checkCreditAlerts, forgetCreditCheck } = await import("../lib/credit.js");
const { ownerReport } = await import("../lib/owner-report.js");
const { dashboardPage, loginPage } = await import("../lib/owner-page.js");
const { useEmailTransport } = await import("../lib/email.js");
const { default: owner, sessionCookie, validSession, formToken } = await import("../api/owner.js");

const day = (usd: number) => ({ day: "", usd, checks: 0, freeFirstChecks: 0, calls: 0, checkUSD: 0, newDevices: 0 });

test("active devices are counted once, and paid at any point is paid", async () => {
  useMemoryStore();
  const today = "2026-11-15";
  await noteDevice("a", "free", "2026-11-15");
  await noteDevice("a", "free", "2026-11-15");
  await noteDevice("b", "paid", "2026-11-15");
  await noteDevice("c", "free", "2026-11-12");
  await noteDevice("c", "paid", "2026-11-14");      // upgraded during the week
  await noteDevice("d", "free", "2026-10-20");      // 26 days ago
  await noteDevice("e", "free", "2026-10-01");      // outside 30 days
  assert.deepEqual(await activeDevices([today]), { total: 2, free: 1, paid: 1 });
  assert.deepEqual(await activeDevices(daysEnding(today, 7)), { total: 3, free: 1, paid: 2 });
  assert.deepEqual(await activeDevices(daysEnding(today, 30)), { total: 4, free: 2, paid: 2 });
});

test("a device is new once, on the day it first appears; the owner's own builds are not devices", async () => {
  useMemoryStore();
  useEmailTransport(async () => true);
  assert.equal(await noteDevice("phone-1", "free", "2026-01-02"), true);
  assert.equal(await noteDevice("phone-1", "paid", "2026-01-03"), false);
  await recordUsage({ id: "dev:1", door: "dev" }, "research", 0.1);
  await recordUsage({ id: "phone-2", door: "appattest" }, "research", 0.1, "plus");
  const r = await ownerReport(dayKey());
  assert.equal(r.devices.today.total, 1, "the developer token is not a device");
  assert.equal(r.devices.today.paid, 1);
  assert.equal(r.newDevices.at(-1)?.count, 1);
  assert.equal(r.checks.today.usd, 0.2, "its spend still counts");
  useEmailTransport(null);
});

test("the report: checks and cost per check, the month's projection from the last 7 days", async () => {
  useMemoryStore();
  const today = "2026-11-20";                       // a Friday; 10 days left in November
  for (const d of daysEnding(today, 7)) await addToDay({ usd: 1.4, checks: 8, checkUSD: 1.36 }, d);
  await addToDay({ usd: 2.0, checks: 10, checkUSD: 1.8 }, "2026-11-03");
  const r = await ownerReport(today);
  assert.equal(r.checks.today.checks, 8);
  assert.equal(r.checks.today.averagePerCheckUSD, 0.17);
  assert.equal(r.checks.week.from, "2026-11-16");
  assert.equal(r.checks.week.checks, 40, "Monday to Friday");
  assert.equal(r.checks.month.checks, 66);
  assert.equal(r.spend.monthUSD, 11.8);
  assert.equal(r.spend.dailyPaceUSD, 1.4);
  assert.equal(r.spend.daysLeftInMonth, 10);
  assert.equal(r.spend.projectedMonthEndUSD, 25.8, "11.80 so far + 1.40 a day for 10 days");
  assert.equal(r.newDevices.length, 14);
  assert.equal(r.state, "open");
  assert.equal(r.credit, null);
});

test("the pace is over the days since spending began, not always seven", () => {
  assert.equal(dailyPace([day(0), day(0), day(0), day(0), day(0), day(2), day(4)]), 3, "two days in: the average of those two");
  assert.equal(dailyPace([day(1), day(0), day(0), day(0), day(0), day(0), day(6)]), 1, "quiet days inside the stretch count");
  assert.equal(dailyPace([day(0), day(0)]), 0);
  assert.equal(dailyPace([]), 0);
});

test("credit counts down from the balance entered, and emails below 10 days and again below 3", async () => {
  useMemoryStore();
  const sent: { subject: string; text: string }[] = [];
  useEmailTransport(async (e) => { sent.push(e); return true; });
  const phone = { id: "phone-1", door: "appattest" as const };

  await addToDay({ usd: 7 });                        // spent before the balance was entered: not counted
  await setCredit(30);
  let c = (await creditStatus())!;
  assert.equal(c.remainingUSD, 30);
  assert.equal(c.spentSinceUSD, 0);

  // $7 today is the whole pace, so $30 is about 4 days: below 10, not below 3.
  await recordUsage(phone, "research", 2);
  c = (await creditStatus())!;
  assert.equal(c.spentSinceUSD, 2);
  assert.equal(c.remainingUSD, 28);
  assert.equal(c.dailyPaceUSD, 9);
  assert.equal(c.daysLeft, 3.1);
  assert.equal(sent.filter((e) => /credit/.test(e.subject)).length, 1);
  assert.match(sent.find((e) => /credit/.test(e.subject))!.subject, /under 10 days/);

  // Looked at no more than once every half hour.
  await recordUsage(phone, "prefill", 5);
  assert.equal(sent.filter((e) => /credit/.test(e.subject)).length, 1);
  await forgetCreditCheck();
  await checkCreditAlerts();
  const credit = sent.filter((e) => /credit/.test(e.subject));
  assert.equal(credit.length, 2);
  assert.match(credit[1].subject, /under 3 days/);
  assert.match(credit[1].text, /Left: \$23\.00/);

  // Each mark once, until a new balance is entered.
  await forgetCreditCheck();
  await checkCreditAlerts();
  assert.equal(sent.filter((e) => /credit/.test(e.subject)).length, 2);
  await setCredit(500);
  await forgetCreditCheck();
  await checkCreditAlerts();
  assert.equal(sent.filter((e) => /credit/.test(e.subject)).length, 2, "plenty left: nothing sent");
  assert.equal((await creditStatus())!.remainingUSD, 500);
  useEmailTransport(null);
});

test("a balance that jumps straight below 3 days sends one email, not two", async () => {
  useMemoryStore();
  const sent: { subject: string }[] = [];
  useEmailTransport(async (e) => { sent.push(e); return true; });
  await setCredit(1);
  await recordUsage({ id: "p", door: "appattest" }, "research", 0.6);
  const credit = sent.filter((e) => /credit/.test(e.subject));
  assert.equal(credit.length, 1);
  assert.match(credit[0].subject, /under 3 days/);
  useEmailTransport(null);
});

test("the session cookie proves the secret without holding it, and expires", () => {
  const now = Date.UTC(2026, 10, 15);
  const cookie = sessionCookie(now);
  assert.ok(!cookie.includes("owner-secret"));
  assert.equal(validSession(cookie, now), true);
  assert.equal(validSession(cookie, now + 29 * 86_400_000), true);
  assert.equal(validSession(cookie, now + 31 * 86_400_000), false, "thirty days");
  assert.equal(validSession(cookie.replace(/.$/, (c) => (c === "A" ? "B" : "A")), now), false);
  assert.equal(validSession(`${Math.floor(now / 1000) + 999_999_999}.${cookie.split(".")[1]}`, now), false, "a later expiry needs its own signature");
  assert.equal(validSession(undefined, now), false);
  process.env.FORGE_OWNER_SECRET = "a-different-secret-0123456789";
  assert.equal(validSession(cookie, now), false, "changing the secret signs everyone out");
  process.env.FORGE_OWNER_SECRET = "owner-secret-0123456789";
});

function fakeRes() {
  const out = { status: 0, headers: {} as Record<string, string>, body: "" as unknown };
  const res = {
    setHeader(k: string, v: string) { out.headers[k.toLowerCase()] = v; },
    status(c: number) { out.status = c; return res; },
    send(b: string) { out.body = b; },
    json(b: unknown) { out.body = b; },
  };
  return { res: res as never, out };
}

test("/owner: no page without the secret; sign in, see the numbers, save a balance, sign out", async () => {
  useMemoryStore();
  useEmailTransport(async () => true);
  await startCheck({ id: "phone-1", door: "appattest" }, null, "free");
  await recordUsage({ id: "phone-1", door: "appattest" }, "research", 0.11, "free");

  // No cookie: the sign-in form, and none of the numbers.
  let r = fakeRes();
  await owner({ method: "GET", headers: {} } as never, r.res);
  assert.equal(r.out.status, 200);
  assert.match(r.out.body as string, /Owner's secret/);
  assert.doesNotMatch(r.out.body as string, /Active devices/);

  // A wrong secret.
  r = fakeRes();
  await owner({ method: "POST", headers: {}, body: { secret: "nope-nope-nope-nope-nope" } } as never, r.res);
  assert.equal(r.out.status, 401);
  assert.equal(r.out.headers["set-cookie"], undefined);

  // The right one: a cookie and a redirect.
  r = fakeRes();
  await owner({ method: "POST", headers: {}, body: "secret=owner-secret-0123456789" } as never, r.res);
  assert.equal(r.out.status, 303);
  const setCookie = r.out.headers["set-cookie"];
  assert.match(setCookie, /HttpOnly; Secure; SameSite=Strict/);
  const cookie = setCookie.split(";")[0];
  const value = cookie.split("=").slice(1).join("=");

  r = fakeRes();
  await owner({ method: "GET", headers: { cookie } } as never, r.res);
  assert.equal(r.out.status, 200);
  const page = r.out.body as string;
  assert.match(page, /Active devices/);
  assert.match(page, /\$0\.11 <span class="muted">of \$3\.00/);
  assert.match(page, /No balance entered yet/);
  assert.equal(r.out.headers["x-frame-options"], "DENY");

  // Saving a balance needs the form's token.
  r = fakeRes();
  await owner({ method: "POST", headers: { cookie }, body: { credit: "50" } } as never, r.res);
  assert.equal(r.out.status, 403);
  r = fakeRes();
  await owner({ method: "POST", headers: { cookie }, body: { credit: "$50.00", token: formToken(value) } } as never, r.res);
  assert.equal(r.out.status, 200);
  assert.match(r.out.body as string, /Balance saved: \$50\.00/);
  assert.equal((await creditStatus())!.enteredUSD, 50);
  r = fakeRes();
  await owner({ method: "POST", headers: { cookie }, body: { credit: "lots", token: formToken(value) } } as never, r.res);
  assert.equal(r.out.status, 400);

  // The same numbers as JSON, for a script, with the secret as a bearer token.
  r = fakeRes();
  await owner({ method: "GET", headers: { authorization: "Bearer owner-secret-0123456789" } } as never, r.res);
  assert.equal((r.out.body as { devices: { today: { total: number } } }).devices.today.total, 1);
  r = fakeRes();
  await owner({ method: "GET", headers: { authorization: "Bearer wrong-wrong-wrong-wrong" } } as never, r.res);
  assert.equal(r.out.status, 401);

  r = fakeRes();
  await owner({ method: "POST", headers: { cookie }, body: { signout: "1", token: formToken(value) } } as never, r.res);
  assert.match(r.out.headers["set-cookie"], /Max-Age=0/);
  useEmailTransport(null);
});

test("without a secret on the server the page says so and shows nothing", async () => {
  useMemoryStore();
  delete process.env.FORGE_OWNER_SECRET;
  const r = fakeRes();
  await owner({ method: "GET", headers: {} } as never, r.res);
  assert.equal(r.out.status, 503);
  assert.match(r.out.body as string, /FORGE_OWNER_SECRET is not set/);
  process.env.FORGE_OWNER_SECRET = "owner-secret-0123456789";
});

test("the page escapes what it is given", () => {
  assert.match(loginPage("<script>x</script>"), /&lt;script&gt;x&lt;\/script&gt;/);
  assert.doesNotMatch(loginPage("<script>x</script>"), /<script>x/);
});

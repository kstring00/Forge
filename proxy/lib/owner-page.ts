// The owner's dashboard as one plain HTML page: no scripts, no dependencies,
// readable on a phone. Everything that comes from outside is escaped.
import type { OwnerReport } from "./owner-report.js";
import type { Period } from "./ledger.js";

const esc = (s: unknown) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const money = (n: number) => `$${n.toFixed(2)}`;
const cents = (n: number | null) => (n === null ? "–" : n < 1 ? `${Math.round(n * 100)}¢` : money(n));
const shortDay = (day: string) => `${Number(day.slice(5, 7))}/${Number(day.slice(8, 10))}`;

const css = `
:root{color-scheme:light dark;--bg:#f6f4f0;--card:#fff;--ink:#1c1916;--muted:#6b645b;--line:#e2ddd5;--accent:#b8480f;--on-accent:#fff;--bar:#d9d3c9}
@media (prefers-color-scheme:dark){:root{--bg:#1c1916;--card:#272320;--ink:#f1ebe2;--muted:#a39b8f;--line:#3a342e;--accent:#e58a62;--on-accent:#1c1916;--bar:#3a342e}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
main{max-width:720px;margin:0 auto;padding:16px}
h1{font-size:22px;margin:8px 0 2px}h2{font-size:15px;margin:0 0 10px;color:var(--muted);font-weight:600}
p{margin:6px 0}.muted{color:var(--muted);font-size:14px}
section{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px;margin:12px 0;overflow:hidden}
td:last-child{white-space:nowrap}.nowrap{white-space:nowrap}
table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums}
th,td{text-align:right;padding:7px 0 7px 10px;border-top:1px solid var(--line);font-weight:400}
th:first-child,td:first-child{text-align:left;padding-left:0}thead th{border-top:0;color:var(--muted);font-size:13px;font-weight:600}
.big{font-size:28px;font-weight:650;letter-spacing:-.01em}
.meter{height:10px;background:var(--bar);border-radius:5px;overflow:hidden;margin:10px 0 6px;position:relative}
.meter i{display:block;height:100%;background:var(--accent)}.meter b{position:absolute;top:0;bottom:0;width:2px;background:var(--ink);opacity:.55}
.bars{display:flex;align-items:flex-end;gap:4px;height:84px;margin-top:8px}
.bars div{flex:1 1 0;min-width:0;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:3px;height:100%;font-size:11px;color:var(--muted)}
.bars i{display:block;width:100%;background:var(--accent);border-radius:3px 3px 0 0;min-height:2px}.bars i.zero{background:var(--bar)}
form{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}
input{font:inherit;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:var(--bg);color:var(--ink);min-width:0;flex:1 1 150px}
button{font:inherit;font-weight:600;padding:10px 16px;border:0;border-radius:10px;background:var(--accent);color:var(--on-accent)}
button.plain{background:transparent;color:var(--muted);border:1px solid var(--line);font-weight:400}
.warn{color:var(--accent);font-weight:600}`;

function shell(title: string, body: string): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="robots" content="noindex,nofollow"><title>${esc(title)}</title><style>${css}</style></head><body><main>${body}</main></body></html>`;
}

export function loginPage(message?: string): string {
  return shell("Hunch · owner", `<h1>Hunch · owner</h1>
<section><h2>Owner's secret</h2>${message ? `<p class="warn">${esc(message)}</p>` : ""}
<form method="post" action="/owner"><input type="password" name="secret" autocomplete="current-password" placeholder="Paste the secret" required>
<button type="submit">Open</button></form>
<p class="muted">The value of FORGE_OWNER_SECRET on Vercel. It is remembered on this browser for 30 days.</p></section>`);
}

function periodRows(p: { today: Period; week: Period; month: Period }): string {
  const row = (name: string, x: Period) => `<tr><td>${name}</td><td>${x.checks}</td><td>${money(x.usd)}</td><td>${cents(x.averagePerCheckUSD)}</td></tr>`;
  return row("Today", p.today) + row("This week", p.week) + row("This month", p.month);
}

const stateLine: Record<OwnerReport["state"], string> = {
  open: "Everyone is being served.",
  paidOnly: "Free users can't start a check for the rest of today. Paid plans carry on.",
  resting: "The ceiling is reached. Every check rests until midnight.",
};

export function dashboardPage(r: OwnerReport, token: string, notice?: string): string {
  const share = r.ceilingUSD > 0 ? Math.min(100, (r.checks.today.usd / r.ceilingUSD) * 100) : 0;
  const mark = r.ceilingUSD > 0 ? Math.min(100, (r.freeTierStopsAtUSD / r.ceilingUSD) * 100) : 0;
  const maxNew = Math.max(1, ...r.newDevices.map((d) => d.count));
  const devRow = (name: string, d: OwnerReport["devices"]["today"]) => `<tr><td>${name}</td><td>${d.total}</td><td>${d.free}</td><td>${d.paid}</td></tr>`;
  const c = r.credit;
  const low = c && c.daysLeft !== null && c.daysLeft < 10;
  return shell("Hunch · owner", `<h1>Hunch · owner</h1>
<p class="muted">${esc(r.day)} · days roll over at midnight ${esc(r.timeZone)}${r.store === "memory" ? ` · <span class="warn">no database connected: these numbers reset whenever the server restarts</span>` : ""}</p>
${notice ? `<section><p>${esc(notice)}</p></section>` : ""}
<section><h2>Today against the ceiling</h2>
<div class="big">${money(r.checks.today.usd)} <span class="muted">of ${money(r.ceilingUSD)}</span></div>
<div class="meter"><i style="width:${share.toFixed(1)}%"></i><b style="left:${mark.toFixed(1)}%"></b></div>
<p class="${r.state === "open" ? "muted" : "warn"}">${stateLine[r.state]}</p>
<p class="muted">Free checks stop at ${money(r.freeTierStopsAtUSD)} (the line on the bar). Everything stops at ${money(r.ceilingUSD)}.</p></section>

<section><h2>Active devices</h2>
<table><thead><tr><th></th><th>All</th><th>Free</th><th>Paid</th></tr></thead><tbody>
${devRow("Today", r.devices.today)}${devRow("Last 7 days", r.devices.week)}${devRow("Last 30 days", r.devices.month)}</tbody></table>
<p class="muted">A device counts as paid if it was on Plus or Pro at any point in the period. In TestFlight nobody is charged, so "paid" means "chose a plan".</p></section>

<section><h2>Checks</h2>
<table><thead><tr><th></th><th>Checks</th><th>Spend</th><th>Per check</th></tr></thead><tbody>${periodRows(r.checks)}</tbody></table>
<p class="muted">"Per check" is what the checks themselves cost (research and the panel's take), from actual token usage. Spend also includes follow-ups such as launch plans. The week starts on Monday.</p></section>

<section><h2>Spend this month</h2>
<div class="big">${money(r.spend.monthUSD)}</div>
<p>Projected month-end: <strong>${money(r.spend.projectedMonthEndUSD)}</strong></p>
<p class="muted">At ${money(r.spend.dailyPaceUSD)} a day (the last 7 days' average) for the ${r.spend.daysLeftInMonth} ${r.spend.daysLeftInMonth === 1 ? "day" : "days"} left this month.</p></section>

<section><h2>New devices per day, last 14 days</h2>
<div class="bars">${r.newDevices.map((d) => `<div><span>${d.count || ""}</span><i class="${d.count ? "" : "zero"}" style="height:${Math.round((d.count / maxNew) * 60)}px"></i><span title="${esc(d.day)}">${Number(d.day.slice(8, 10))}</span></div>`).join("")}</div>
<p class="muted">${esc(shortDay(r.newDevices[0]?.day ?? r.day))} to ${esc(shortDay(r.day))}. A device is new the first day it reaches the server.</p></section>

<section><h2>Credit</h2>
${c ? `<div class="big${low ? " warn" : ""}">${c.daysLeft === null ? "–" : c.daysLeft} <span class="muted">days left at this pace</span></div>
<table><tbody>
<tr><td>Balance you entered <span class="nowrap">(${esc(c.setAt.slice(0, 10))})</span></td><td>${money(c.enteredUSD)}</td></tr>
<tr><td>Spent since then</td><td>${money(c.spentSinceUSD)}</td></tr>
<tr><td>Left</td><td>${money(c.remainingUSD)}</td></tr>
<tr><td>Pace, last 7 days</td><td>${money(c.dailyPaceUSD)} a day</td></tr></tbody></table>`
    : `<p>No balance entered yet. Enter what your Anthropic account shows and the count starts from there.</p>`}
<form method="post" action="/owner"><input type="hidden" name="token" value="${esc(token)}">
<input type="text" name="credit" inputmode="decimal" placeholder="New balance, e.g. 50.00" required><button type="submit">Save balance</button></form>
<p class="muted">Update this each time you top up. You are emailed when it drops below 10 days, and again below 3. Only spending that goes through this server is counted, so the benchmark and Anthropic's own console are not in it.</p></section>

<form method="post" action="/owner"><input type="hidden" name="token" value="${esc(token)}"><input type="hidden" name="signout" value="1"><button class="plain" type="submit">Sign out</button></form>`);
}

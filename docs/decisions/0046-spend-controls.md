# 0046 · Spend controls on the proxy

**Date:** November 15 · **Status:** built; needs the proxy's setup on Vercel and a device build to see live

## Why

TestFlight puts the app in other people's hands, and every check they run is paid for from one Anthropic account. Decision 0021 gave the proxy a hard daily ceiling. Kyle asked for the ceiling to protect paying users first, to tell him when a day runs hot, and to show him the numbers without opening Vercel.

## What was decided

- **A daily ceiling in dollars, from an environment variable.** `FORGE_DAILY_SPEND_USD`, starting at **3.00**. Counted from actual token usage: each call's real input, output and cache tokens and its web searches, priced by the proxy.
- **At 70% of the ceiling, free-tier users can no longer start a check.** They see the same polite line as always, "The panel is resting until tomorrow." Paid plans carry on.
- **At 100%, everything rests** until midnight.
- **What "start a check" means.** Only a new check is held back at 70%. A check already under way finishes, and follow-ups on a checked idea (a launch plan, a re-score) still run. Cutting a check in half would spend the research and deliver nothing.
- **Kyle is emailed** at kyle@stringhamwebdesign.com the first time a day reaches 70%, and again at 100%. One email per mark per day. A call that jumps both marks sends only the 100% one.
- **Settings → Spend**, for Kyle only: today against the ceiling, then this week and this month.

## How the proxy knows who is paying

The app sends the plan it is on (free, plus or pro) with every request, inside the body that App Attest signs. A genuine copy of the app reports its real plan, and only a genuine copy gets through the door (decision 0021). The proxy does **not** yet check the App Store receipt itself; that arrives with the server-side ledger. Two honest limits follow:

- Someone who could defeat App Attest could also claim to be paid. That would let them start checks between 70% and 100%; the ceiling itself still holds.
- **In TestFlight nobody pays.** A tester who "subscribes" is charged nothing, but counts as paid here. Until launch, "paid" means "chose a plan in TestFlight".

A free trial counts as the plan being tried. Kyle's own developer builds are never held back at 70%.

## A day is a day in Texas

The proxy's day used to roll over at midnight UTC, which is 6 or 7 in the evening in Texas: "resting until tomorrow" would lift at dinner time, and "today" on the Spend screen would not match the calendar. The day now rolls over at midnight in `FORGE_DAY_TIMEZONE`, default `America/Chicago`. Testers elsewhere get the same midnight.

## The owner's key

`FORGE_OWNER_SECRET` on Vercel (16 characters or more) opens the spend numbers and, in the next PR, the dashboard. No build of the app carries it. Kyle types it into his own phone once: Settings, long-press **Version**, paste, Save. It is kept in that phone's keychain, and a **Spend** row appears under About. Without the key there is no row and nothing to find.

## Email

The proxy sends through Resend's HTTP API with plain `fetch`: no new dependency. It needs `RESEND_API_KEY`. With Resend's test sender (`onboarding@resend.dev`) mail is delivered only to the address the Resend account was opened with, which is all this needs. Without a key the alert is written to the log and nothing fails.

## Where it lives

- `proxy/lib/limits.ts`: the 70% and 100% rules and the alerts. `proxy/lib/ledger.ts`: one small record per day (dollars, checks, what the checks themselves cost), kept for over a year. `proxy/lib/email.ts`, `proxy/lib/owner.ts`, `proxy/api/spend.ts`.
- App: `PlanSignal` and `OwnerSpend` in ForgeCore (tested); `SpendView.swift`; the plan field on both request bodies.

## The owner's dashboard

`https://<the proxy's address>/owner`. One plain page, no scripts, readable on a phone, in light or dark to match the device.

- **Signing in.** Paste `FORGE_OWNER_SECRET`. The browser then holds a cookie for 30 days that proves the secret was shown without containing it. Changing the secret on Vercel signs every browser out. More than ten wrong tries in a minute are refused.
- **Today against the ceiling,** with the 70% mark on the bar.
- **Active devices:** today, the last 7 days and the last 30, split free and paid. A device that was on Plus or Pro at any point in the period counts as paid. Kyle's own developer builds are not counted as devices; what they spend is.
- **Checks:** today, this week and this month, with the spend and the average cost of a check from actual token usage. "Per check" is research plus the panel's take; follow-ups such as launch plans are in the spend but not in that average.
- **Spend this month and the projection:** this month so far, plus the last seven days' daily average for each day left in the month. Early on, the average is over the days since spending began, not a seventh of them.
- **New devices per day,** the last 14 days. A device is new the first day it reaches the server.
- **Credit.** Anthropic doesn't tell the proxy what is left on the account, so Kyle types in the balance when he tops up. The page subtracts what the proxy has spent since and divides by the daily pace: days of credit left.
- **Kyle is emailed** when days left drops below 10, and again below 3. Each once, until a new balance is entered. It is looked at no more than once every half hour.

What the proxy keeps for this: one record per day (kept over a year), who was active each day by tier (kept 45 days), the set of devices ever seen, and a running total of everything spent. Device ids are App Attest key ids: random per install, not tied to a person.

## Not in the numbers

Anything that calls the AI without going through the proxy: the benchmark on Kyle's Mac, and anything typed into Anthropic's own console.

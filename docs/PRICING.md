# Hunch pricing (v1)

Status: decided, not built. Build after TestFlight items 1–2 (proxy protection, beta allowance). Design: the "Membership · Free / Plus / Pro" artboard. It supersedes the Credits and Credit-moments boards wherever they disagree.

## Principle

Pay for the panel's thinking, never for your own work. Capture, the Vault, steps, logging, rulings, the Journal and Your patterns' data are free on every plan and never locked. Price on the value of the answer, not the cost of the call; stay well under competitors (IdeaProof ≈ $19 per idea, IdeaValidator Pro $14.99/mo).

## Plans

| Plan | Monthly | Yearly | Checks / month | Includes |
|---|---|---|---|---|
| Free | $0 | $0 | 1 (plus the one free first check per device) | Everything that isn't the panel |
| Plus | $9.99 | $59.99 | 15 | Argue it out (fair use 30/mo), Your patterns, the Library |
| Pro | $24.99 | $179.99 | 60 | Everything in Plus, faster answers (priority), deep research |
| Top-up | $2.99 one-time | — | +5 extra | Consumable, never expires, available on any plan |

- Founding members (TestFlight testers): Plus yearly at $39.99, kept for as long as they stay subscribed.
- Plus has a 7-day free trial (introductory offer), capped at 5 checks during the trial.
- "Within the hour" checks (Batch API, if built) count as half a check.
- A failed or stopped check never counts.
- **Unused monthly checks roll over** (decision 0042), up to one month's allowance, and expire at the end of the cycle they rolled into. Spending order: the free first check, carried-over, this month's, then extra (bought, never expire).

**What costs a check** (decision 0042). Researching an idea is the only thing that costs: the panel's first look is 1 check, and a fresh re-check (new web research on an idea already checked) is 1. Everything done on a checked idea is **included on every plan**: a launch plan, bringing it up to date, re-scoring after a logged conversation, and the Tank. Included follow-ups sit under a quiet daily limit per idea (3 plans, 10 re-scores, 3 Tank runs); reaching it shows a friendly line, never the paywall. Every number here lives in `proxy/config/hunch.ts` (`rules`), which the app loads at launch.

**Launch plans** (decisions 0041, 0042). A short plan built from what Hunch knows about one idea: what's proven and what isn't, the first 90 days in three blocks that each end in a decision rule, the money as price × customers × share, when to stop; exported as a PDF. **Included on every plan** once the idea has been checked (it was 3 checks on Free and Plus before decision 0042). It reads the idea's saved research packet, so it never searches; one plan is one Sonnet call, about $0.03–0.06.

**Sparks are free on every plan** (decision 0040). Every check comes back with two or three "What if…" ideas, strong idea or weak. They ride in the same call as the rest of the panel's take, roughly half a cent each check, paid from margin. Running the panel on an idea made from a Spark costs a check, like any idea.

## Checks, not credits

The user-facing unit is a **check** (one idea looked at properly). Retire "credits" in the UI. Monthly checks reset on the renewal date; top-up checks never expire and are used only after monthly checks run out. Show "N of 15 checks left · resets Dec 1" on Home's pill, the confirm sheet and Settings.

## Products (App Store Connect)

One subscription group "Hunch Membership", ranked Pro > Plus:
- `hunch.plus.monthly` $9.99 · `hunch.plus.yearly` $59.99 (7-day trial) · `hunch.plus.founding.yearly` $39.99 (only shown to accounts flagged as beta testers)
- `hunch.pro.monthly` $24.99 · `hunch.pro.yearly` $179.99

Consumable: `hunch.topup.5` $2.99.

## Build notes

- StoreKit 2 in the app; entitlements verified on the proxy from signed transactions (App Store Server API / JWS) and stored in the per-user ledger next to usage. The proxy, not the app, decides whether a check is allowed.
- Requires Sign in with Apple so plans and top-ups follow the person across devices; Restore purchases on the Membership screen.
- Required subscription disclosures on the Membership screen: price and period for each plan, trial terms, auto-renewal and cancel-24-hours-before wording, how to manage the subscription, and Terms and Privacy links.
- Paywall moments: only when a user taps a check with none left, from the Home pill, and from Settings. Never a pop-up on launch, never during capture, never after a failed run.
- Out of checks: Brief and pivots pause; everything else keeps working, and the screen lists what's still free (as in Credit moments, state 4).
- Reviews: system prompt only after a win, never next to a paywall.

## What to measure in the beta

- Checks per active tester per month (median and top 10%). If the median is under 5, lower Plus to 10 checks; if many hit 15 in a week, Pro is validated.
- Real cost per check by speed (Settings → Spend). Plus must keep ≥70% margin after Apple's 15%.
- How many testers would take the founding offer (ask at the end of the beta; real purchases only start at App Store launch).

## Economics (estimates)

Plus at $9.99 → ≈ $8.49 after Apple (Small Business Program, 15%). Typical use ≈ 8 checks × ≈ $0.20 = $1.60 → ≈ $6.90/month margin. 500 subscribers ≈ $3,400/month; 1,000 ≈ $6,900/month. Prices can change in App Store Connect without an app update.

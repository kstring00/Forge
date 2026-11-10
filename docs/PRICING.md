# Hunch pricing (v1)

Status: decided, not built. Build after TestFlight items 1–2 (proxy protection, beta allowance). Design: the "Membership · Free / Plus / Pro" artboard. It supersedes the Credits and Credit-moments boards wherever they disagree.

## Principle

Pay for the panel's thinking, never for your own work. Capture, the Vault, steps, logging, rulings, the Journal and Your patterns' data are free on every plan and never locked. Price on the value of the answer, not the cost of the call; stay well under competitors (IdeaProof ≈ $19 per idea, IdeaValidator Pro $14.99/mo).

## Plans

| Plan | Monthly | Yearly | Checks / month | Includes |
|---|---|---|---|---|
| Free | $0 | $0 | 1 (plus the one free first check per device) | Everything that isn't the panel, including the Library |
| Plus | $9.99 | $59.99 | 15 | Your patterns |
| Pro | $24.99 | $179.99 | 50 (set Nov 10; easier to raise after the beta than to lower) | Everything in Plus, faster answers (priority), deep research |
| Top-up | $2.99 one-time | — | +5 extra | Consumable, never expires, available on any plan |

- Founding members (TestFlight testers): **first year at the founding price.** An App Store offer code on Plus yearly: $39.99 for the first year, then $59.99 (decision 0043 §4). There is no founding product.
- Plus has a 7-day free trial (introductory offer), capped at 5 checks during the trial.
- "Within the hour" checks (Batch API, if built) count as half a check.
- A failed or stopped check never counts.
- **Unused monthly checks roll over** (decision 0042), up to one month's allowance, and expire at the end of the cycle they rolled into. Spending order: the free first check, carried-over, this month's, then extra (bought, never expire). On an upgrade (Plus → Pro), carried-over and unused checks move over together, capped at Plus's allowance (decision 0043).

**What costs a check** (decision 0042). Researching an idea is the only thing that costs: the panel's first look is 1 check, and a fresh re-check (new web research on an idea already checked) is 1. Everything done on a checked idea is **included on every plan**: a launch plan, bringing it up to date, re-scoring after a logged conversation, and the Tank. Included follow-ups sit under a quiet daily limit per idea (3 plans, 10 re-scores, 3 Tank runs); reaching it shows a friendly line, never the paywall. Every number here lives in `proxy/config/hunch.ts` (`rules`), which the app loads at launch.

**Launch plans** (decisions 0041, 0042). A short plan built from what Hunch knows about one idea: what's proven and what isn't, the first 90 days in three blocks that each end in a decision rule, the money as price × customers × share, when to stop; exported as a PDF. **Included on every plan** once the idea has been checked (it was 3 checks on Free and Plus before decision 0042). It reads the idea's saved research packet, so it never searches; one plan is one Sonnet call, about $0.03–0.06.

**Sparks are free on every plan** (decision 0040). Every check comes back with two or three "What if…" ideas, strong idea or weak. They ride in the same call as the rest of the panel's take, roughly half a cent each check, paid from margin. Running the panel on an idea made from a Spark costs a check, like any idea.

## Checks, not credits

The user-facing unit is a **check** (one idea looked at properly). Retire "credits" in the UI. Monthly checks renew on the renewal date (unused ones roll over, above); top-up checks never expire and are used only after monthly checks run out. Show "N of 15 checks left · resets Dec 1" on Home's pill, the confirm sheet and Settings.

## Products (App Store Connect)

One subscription group "Hunch Membership", ranked Pro > Plus:
- `hunch.plus.monthly` $9.99 · `hunch.plus.yearly` $59.99 (7-day trial; founders: an offer code, $39.99 the first year)
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
- How many testers would take the founding offer, first year at $39.99 (ask at the end of the beta; real purchases only start at App Store launch).

## Economics (measured Nov 9, decision 0042)

A check costs about **$0.168** on the bench (five sample ideas, real API): research about $0.10 (five web searches and reading the results), scoring about $0.005, the Brief about $0.06 to $0.07. Research is most of the cost and the next thing to cut. Included follow-ups (a launch plan, a re-score) cost about $0.013 to $0.023 each and are not in the figures below.

| Plan | After Apple's 15% | Use in a month | AI cost | Left |
|---|---|---|---|---|
| Plus, $9.99 | $8.49 | Typical, 8 checks | $1.34 | **$7.15** |
| Plus, $9.99 | $8.49 | Heavy, all 15 | $2.52 | **$5.97** (70%) |
| Pro, $24.99 | $21.24 | Heavy, all 50 | $8.40 | **$12.84** (60%) |

- A month with a full carry-over can reach 30 checks on Plus or 100 on Pro, but only after a month with none used, so the average stays at or under the allowance.
- At typical use, 500 Plus subscribers leave about $3,600 a month and 1,000 about $7,150.
- Prices can change in App Store Connect without an app update; allowances change in `proxy/config/hunch.ts`.

## Open product questions

- **What Plus sells.** With "Argue it out" gone, Plus is 15 checks a month (carried over) and Your patterns. Is that enough reason to pay? Rule for the beta: if the median tester uses under 5 checks a month, Plus drops to 10.
- **Who Pro is for.** Likeliest: people who evaluate other people's ideas (coaches, consultants, accelerators).
- **The name.** Hunch is a working name; it collides with dating apps.

# 0031 — Pricing decided: memberships, checks not credits

Recorded 2026-11-08, from `docs/PRICING.md` and the "Membership · Free / Plus / Pro" artboard
(`docs/design/membership-free-plus-pro.png`). Decided, not built. Build after TestFlight
items 1 and 2 (proxy protection, beta allowance).

- **Pay for the panel's thinking, never for your own work.** Capture, the Vault, steps,
  logging, rulings, the Journal and Your patterns' data are free on every plan and never locked.
- **Plans.** Free: 1 check a month plus the one free first check per device (decision 0027).
  Plus: $9.99 / $59.99 a year, 15 checks, Argue it out (fair use 30), What-if pivots, Your
  patterns, the Library. Pro: $24.99 / $179.99, 60 checks, priority, deep research,
  exportable reports. Top-up: $2.99 for 5 checks that never expire, on any plan. Founding
  members (TestFlight testers): Plus yearly at $39.99 for as long as they stay. Plus has a
  7-day trial capped at 5 checks. A failed or stopped check never counts.
- **Checks, not credits.** The unit in every screen is a check. Monthly checks reset on the
  renewal date; top-ups are used only after. "N of 15 checks left · resets Dec 1" on Home's
  pill, the confirm sheet and Settings.
- **Where it lives when built.** StoreKit 2 in the app; the proxy verifies signed
  transactions and decides whether a check is allowed, from the per-user ledger next to
  usage (#16's store). Sign in with Apple so plans follow the person. The Membership screen
  carries the required disclosures and Restore. Paywall only on a check with none left, from
  the Home pill, and from Settings; never on launch, during capture or after a failed run.
- **Open question for the beta allowance (TestFlight item 2).** That item was specified as
  5 free checks a week shown as "3 checks left this week"; this doc gives testers Plus
  (15 a month) as founding members. One of the two wins before item 2 is built.

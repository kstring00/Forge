# 0041 — Launch plans: a Plans tab, built from what Hunch knows

Recorded 2026-11-09.

- **What it is.** A short launch plan for any idea the panel has looked at, built only from
  what Hunch knows: the Library (desk research and the person's own logged conversations), the
  panel's take, the estimate and the Steward charter. Not a 30-page business plan. Sections:
  the idea in one line; who it's for; what's proven (each line points at a source) and what
  isn't (beliefs, with the riskiest named); the first 90 days in three 30-day blocks, each
  ending in a decision rule with a number; the money as price × customers × share who pay, from
  the middle of the estimate's inputs, assumptions dotted; when to stop; the charter note.
- **Honesty rule, on the server.** `enforceLaunchPlan` moves any "proven" line without a source
  the app sent into "unproven". The prompt puts the person's own conversations before desk
  research and always says when no one has paid yet.
- **Where it lives.** A **Plans** tab (Home · Ideas · Sparks · Plans · Journal) with "Your
  plans" (newest first, with what moved since) and "Ready for a plan". The idea's page has a
  Launch plan card under the panel's take. The plan page follows the mockup: sky header, the two
  meters, the cards, and **Export as PDF** as the one orange button (US Letter, paginated).
- **It doesn't rewrite itself.** Each plan keeps what it was built on (conversations logged,
  proof step, when the panel last looked). When those move, the plan page and the list say
  what changed ("2 more conversations, proof moved up a step") and offer **Bring the plan up to
  date**. Refreshing is a paid call, so it is one tap, never automatic.
- **Price.** Included in Pro (the "exportable reports" Pro already promised). Free and Plus: a
  new plan is 3 checks, bringing one up to date is 1. The free first check never pays for a
  plan. Spent only when the plan arrives; a failed plan costs nothing. `PlanCost`,
  `CheckLedger.canSpend/spend` (ForgeCore, tested).
- **The Proof tile names the next step** (follow-up to 0038, shipped on the card branch): the
  dots say where proof is; "Next: …" says what moves it.

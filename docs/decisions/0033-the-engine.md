# 0033 — The Hunch Engine is the product

Recorded 2026-11-08, from `docs/ENGINE.md` and the "The Tank" / "The Deal" canvas
(`docs/design/engine-tank-and-deal.pdf`). Decided. Supersedes the brief's §6B (pivots), §6C
(Spheres) and §6D (Reality Check) wherever they disagree; §0A and §6A still bind it.

- **Pipeline:** capture → guard → research → source verification → blind verdicts → the
  Tank (pitch, in or out, ≤ 3 counteroffers, one step-in per stage) → the Deal (attributed
  blend) → the Test (a built artifact) → the Loop (partial re-verdicts, scoreboard).
- **Build order, one PR each, bench numbers in every description:** Bench v0 → source
  verification gate → blind verdicts with commitment + the Advocate → the Deal → the Tank →
  launch kit (test pages) → Loop v2 → second provider → share card. No engine code ships
  before the bench exists; engine v2 ships only if it beats a plain chat model and
  IdeaProof's free check on competitor recall, source truth and riskiest-assumption match.

How it lands on what is already built:

- **What-if pivots (decision 0024)** are the Tank's counteroffers. Same shape
  (`whatIf, pivotType, fixes, why, firstTest, sourceIDs`); they move from one prefill call to
  voices that are out or in-if, at most three, seconded by others.
- **Fillable interviews (decision 0030)** are the Test's artifact for "nobody has this
  problem". Test pages, reservations and the outreach tracker are new.
- **The Steward's seat goes to the Advocate.** The Steward's question becomes the person's
  own check on the Deal screen, with the charter, answered by no AI.
- **Evidence rank** (lived, published, reviewed, discussed, opinion) refines today's source
  classes (userVerified, aiFound, assumption); lived is today's user-verified.
- **Pricing (decision 0032):** Free gets research, blind verdicts and the Deal; the Tank,
  step-ins, counteroffers and test pages are Plus; model choice is Pro. The What-if gate in
  #28 already matches.
- **Settled 2026-11-08: a basic check costs 1 check, a full Tank costs 2** (recorded in
  `docs/PRICING.md` and `docs/ENGINE.md` §5). When the Tank is built, the ledger's commit
  takes the run's cost (`CheckLedger.commit` in #28 counts 1 today) and the confirm sheet
  reads "Uses 2 checks · N left after".

# 0037 — Potential is the panel's view; proof is a stage; desk research is graded; estimates are bottom-up

Recorded 2026-11-09, after two different ideas both showed Confidence 23: with desk levels
fixed at 2 (or 1 without a source), a desk-only idea could land on just seven numbers.

- **Cards stop showing "Confidence".** They lead with Potential, marked "the panel's view"
  (or "your score" once the person has scored it; the verdict label when there is no score),
  then proof as a stage (`ProofStage`): *Desk research only*, *Talked to people · N*,
  *Signups · N* (with test pages), *Someone paid*. The proof number appears on a card only
  after the first logged conversation. The same on the panel's take card and the next-move
  card's stakes panel.
- **Desk research is graded** (`DeskGrade`, `EvidenceRank`): a criterion's desk level is 1.0
  plus what its independent sources add, at most 2.0. Published 0.4, reviewed 0.35,
  discussed 0.2, opinion (the model's own notes) 0; one site counts once. One forum post ≈
  1.2; three independent reviewed sources = 2.0. Stored as `CriterionScore.deskLevel` and
  `deskSourceCount`; `effectiveLevel` uses lived evidence (3+) first, the desk grade while the
  panel's proposal stands, the person's own pick once they touch it. Confidence is the mean of
  effective levels, so it is finer. `LegacyCleanup` v4 grades existing checks from the sources
  already attached.
- **The Brief keeps the finer number** with its breakdown ("+0.4 Demand: 2 sources") and a
  permanent proof history.
- **Movement shows.** Every logged conversation, step outcome or payment that changes proof
  adds a `ProofMove` to the idea ("+6 from Dale"); cards show it for 24 hours, the Brief for good.
- **The estimate is bottom-up.** The prefill returns `estimate` (price a month × reachable
  customers × share who pay), each input with what it rests on or null as an assumption,
  shown with stripes or dots on the estimate sheet. `ReturnInputs.outcome`: with no price
  sourced for this idea, "Too early to estimate: no price found"; otherwise a range, narrowed
  to 10× around its middle when the inputs span more. The prompt forbids using competitors'
  report prices as this idea's price. Older top-down ranges wider than 10× also read "Too
  early".
- Tests: ForgeCore `ProofTests` (ranks, graded desk scores differ by source quality, 10× rule,
  moves); app `ProofTests` (two ideas, different sources, different scores; a logged
  conversation raises proof on the step's criterion and records the move); proxy schemas test
  (estimate enforcement).

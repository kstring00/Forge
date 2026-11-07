# 0007 — Brief v3: Reality Check, Decision Journal, bounded evidence, new build order

Recorded 2026-11-07, during Phase 1.

- `docs/FORGE_BRIEF.md` replaced with v3 after an outside review.
- **Schema now, UI later.** `RealityCheck`, `Competitor` and the Journal shape of
  `Decision` (kind, beliefs, expected result and date, actual result) were added
  to the V1 schema as lightweight-compatible changes before any real data
  existed. `Decision` keeps its original storage names (`text`, `date`,
  `reason`) with `decision`, `decidedAt`, `reasoning` exposed on top.
- **Bounded evidence.** Reviewing a source never raises Confidence by itself;
  only attaching it to a criterion as Evidence with a rung does, and desk
  research is capped at rung 2 (`Scoring.deskResearchRungCeiling`;
  `DemandSignal` clamps to it). Enforced in the model layer in Phase 4.
- **AI action list** gains `realityCheck` with a typed `RealityCheckResult`.
- **Build order.** After Phase 1: Phase 1b export and re-import; then Phase 2 is
  the core loop (Explore, convert to project, one next step, record what
  happened, Journal entries, AI-sharing consent before the first AI call);
  the Lab and Spheres move to Phase 3; Reality Check joins the Library in Phase 4.

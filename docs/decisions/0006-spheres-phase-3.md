# 0006 — Spheres (§6C) land in Phase 3; models created in Phase 0

Decided 2026-11-06. The Round, Verdict, Crossfire, Ruling and StewardCharter
models exist from the first build so the schema never migrates mid-project.
Round UI, the five Phase 3 Spheres (Investor, Customer, Builder, Strategist,
Skeptic) and the `runRound` AI action ship with the Evaluation Lab in Phase 3.
The Steward and its charter ship in Phase 5. "Challenge" is gone from the AI
action list. A verdict with no sources is forced to `cantTell` at the model
layer, not just in the prompt.

# 0034 — Bench v0: the engine's test suite comes first

Recorded 2026-11-08. Engine build step 1 (`docs/ENGINE.md` §6, §9). No engine changes.

- **`bench/`** is a small TypeScript package beside the proxy. It runs the engine exactly as
  the app does (research one turn per call, then the prefill, through the proxy with a
  developer token), a plain chat baseline (`claude-opus-5-5`, optionally with web search,
  its prose extracted by a second model that adds nothing), and IdeaProof's free check
  captured by hand. A separate model grades the riskiest assumption and the step against the
  key without being told which system it is grading.
- **Scoring is pure and tested** (`src/score.ts`, `npm test`): competitor recall on the key's
  true top 3 (name, alias, containment or website), prices within 15%, source truth, the
  step rubric, cost and latency, and the gate (beat both baselines on recall, source truth
  and riskiest assumption, with source truth at 100%).
- **Source truth in v0** is a stand-in until the verification gate: a claim counts when the
  page it cites contains the competitor's name and every dollar figure stated for it. A
  claim with no cited page never counts, so baselines without sources score 0%.
- **Keys are the truth, so a person owns them.** Shipped: three classics (Dropbox, Juicero,
  Quibi) and Hunch itself, all marked unverified until someone checks the prices; the RV
  park example without a key. Target 15. `npm run import-vault` brings the person's own
  ideas in from the app's export, in their own words.
- **Refusals are results**, recorded and not retried on another model, so a run measures the
  model it names.
- Nothing runs without `--yes`; the plan and an estimate print first.

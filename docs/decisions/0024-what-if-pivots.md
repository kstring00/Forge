# 0024 — "What if…" pivots on the Brief

Recorded 2026-11-08.

- **Same call, no extra AI.** The prefill returns `pivots`: two or three when the verdict is
  Go ask people or Worth a fight, or the evidence is thin enough that Confidence should sit
  under 40; otherwise an empty list. Each has `whatIf` (one sentence starting "What if"),
  `pivotType`, `fixes` (a criterion key), `why` (one sentence, grounded in the Library),
  `firstTest` (one sentence) and `sourceIDs`. The proxy keeps at most three, only ones that
  raise a real criterion of the lens, phrased as a what-if, citing known sources.
- **Shown under the riskiest assumption** as "What if…" cards labelled with the weakness
  they fix ("Raises Distribution"), when `WhatIfPolicy.shows(confidence:verdict:)`:
  Confidence under 40, or the verdict is cantTell or compete. Saved on the check (`pivots`),
  so a re-check brings its own.
- **"Make this its own idea"** saves a sibling idea: the what-if as its own words,
  `pivotOf` the parent, origin pivoted, the parent's lens, stage capture, the reasoning and
  first test in its notes. Never checked on its own: it goes through the confirm sheet like
  any idea. A second tap opens the idea it already made.
- Tests: proxy `schemas.test.ts` (cap, lens keys, phrasing, known sources),
  `WhatIfPolicyTests`, `PivotActionsTests`.

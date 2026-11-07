# Phase 3 — Evaluation Lab + Spheres (Business lens)

Split into two PRs. **3a** (this one) is the Lab and the idea-detail composition
from the design canvas; **3b** is the Vercel proxy, the live AI client, Spheres
with Rounds and rulings, and the AI side of the Reality Check button.

## 3a — Built

- **Idea detail composition, in the canvas's order.** Full-bleed sky header with
  the three stage dots and the mono status line, serif title, italic original
  with the ember rule, AI summary line, then the Lab: two ring cards (Potential
  ink, Confidence ember with "Mostly enthusiasm so far." below 40), the pattern
  legend with live percentages, the Projection card, criteria rows with pattern
  chip, 5×32 gauge and serif score, the ladder card with the current rung lit
  (A2 for Business), the riskiest assumption with its "if wrong" line, the ember
  Next move button, the Run a Round / Reality Check pair, and the Library line.
  Explore and Make it real follow, then tags, notes and dates.
- **Opportunity Filter** as a sheet of ten segmented questions, with the
  three-or-more-no guard and its suggestion; answers stored on the idea.
- **Criterion screen.** Definition with frameworks, the rubric as tappable
  anchors, the ladder as the evidence picker (A2's score is set by the ladder and
  the independent-people counter, never by hand), what does not count, the
  playbook with the rung each step reaches, a note shown on the row, attached
  evidence, and the AI boundary.
- **Manual evidence.** A note or link as verified or assumption at a rung the
  user picks; a link alone is capped at rung 2 unless the user lived it. Each
  attachment becomes a Source in the idea's Library and a bounded Evidence item.
- **Versioning.** Finalize when complete; New version either copies forward
  (scores, evidence links, narrative, projection) or starts blank. History
  screen lists every version. Earlier versions stay frozen.
- **Next move.** The suggestion follows Confidence before Potential; the user
  picks the move and writes the step; "Test it" opens the Experiment card
  fields. The button shows the chosen move and step, or the suggestion and the
  cheapest playbook step.
- **Projection / Impact (§4.0).** Business: price, units, derived recurring, a
  bar solid only for units backed by a rung-4+ verified payment. Growth and
  Creative: who, what changes, how you'd know; the bar goes solid once a rung-3+
  verified signal exists. Never feeds Potential or Confidence.
- **Fonts.** Fraunces shipped as static instances (decision 0009).
- **Tests.** `LabModelTests` (copy-forward, blank version, breakdown, pattern,
  projection verification, ladder key, suggested move, triage), ForgeCore
  `NextMoveAndProjectionTests`.

## 3a — Deliberately skipped

- Voice evidence attachment (recording an interview into a criterion). Phase 4
  brings voice memos with transcripts as Library sources; attaching one then
  reuses the Add evidence sheet.
- Lenses B and C in the Lab UI. The screens are lens-agnostic and the content
  exists, but the entry card offers Business only until Phase 5.
- Compare (Phase 5).

## 3a — Needs the developer

1. Regenerate and build. New folders: `Features/Lab`, `Resources/Fonts`. Run the scheme tests.
2. Check the fonts load: the title and ring numbers should be Fraunces, not New York. If a font fails to register, Xcode's console says which file.
3. Walk the Lab on the RV-park idea: screen it, score A1 by anchor, set A2's rung and people counter, attach a verified note at rung 4 on A2 and watch the legend and projection bar move, name the riskiest assumption, pick the next move, finalize, start a new version from v1's scores.
4. Compare the screen against `docs/design/` for spacing and type; tell me what is off.

## 3b — Proxy, Reality Check, Sphere pre-fill, the Brief (brief v4)

Split across PRs #6, #7, #8 and #9, all merged.

**3b.1 (#6): the proxy and the live client.**
- `proxy/`: Vercel project. `GET /api/health`, `POST /api/action` (all twelve typed actions, structured outputs, server-side honesty rules), `POST /api/research` (one web search + fetch turn per call, resumable). Deploy guide in `proxy/README.md`.
- `ProxyAIClient` in the app, chosen automatically when `Local.xcconfig` carries `PROXY_URL` and `PROXY_TOKEN`. Expand and Summarize go live end to end.
- `prefill` action and `PrefillResult` contract declared in Swift, mirrored from `proxy/lib/schemas.ts`.
- `proxy/lib/content.json` generated from ForgeCore (`swift run forge-lens-export`).

**3b.2 (#7): the Reality Check flow and the Brief screen.** Built:
- `CaptureStateSection`: before a check, the idea shows the sky, the original text and one ember Reality Check button with the cost estimate from the proxy's health endpoint; everything else (Explore, Make it real, tags, notes) sits under a collapsed "More". The first run shows the consent sheet.
- `RealityCheckRunner`: research turns through `/api/research` until done (at most four), pages saved as chunked `ai-found` web Sources plus a "Research notes" source, then `prefill`, then `PrefillApplier`. Orbs light one at a time while the panel works. Offline, failure and over-ceiling are calm states; nothing is written on failure.
- `PrefillApplier`: a RealityCheck with competitors, demand signals and the drafted asset as a Source; proposed Explore answers as unconfirmed AI text (never over the user's own); a new evaluation version with every score flagged `aiProposed`, rungs capped at 2, evidence pointing at unreviewed sources so Confidence stays honest; riskiest assumption, next move, Experiment card; the projection range as an estimate string, never as figures; the panel as a Round.
- `BriefSection`: verdict row, six orbs (Steward dim) with speaking state and disagreement hairlines, what we found with source chips, striped rings while everything is still proposed, the one human task with the drafted asset, and the three buttons. Looks right confirms the proposed Explore answers, writes a Journal ruling, converts to a project with the step and the drafted asset, and opens it: three taps to a task. Not quite expands to the 3a Lab; proposed scores read in the AI colour and the panel's number shows struck through once overridden. I know something you don't saves a user-verified Source and re-scores only the criteria the panel says it touches, in a new version.
- Orbs per §8: layered radial gradients with blur and highlight, idle drift (still under Reduce Motion), working, speaking, dim.
- Settings: spent this month, monthly ceiling, last Reality Check cost. The runner refuses to start past the ceiling.
- Tests: `PrefillApplierTests` (honest records, no overwrite of user answers, rung caps, flag clearing, chunked sources, spend, JSON passthrough).

Known limits: "I know something you don't" is text only (voice reuses Phase 1's capture in Phase 4); its re-score keeps the desk rung cap even for user-verified facts, so a rung above 2 is set by hand in the Lab for now; the research loop runs while the screen is open and resumes from the Library if the app is backgrounded mid-run only in the sense that saved pages persist.

**3b.3 (#8): Home as the panel's desk (brief v4.1 §7) and the Vault cards.**
- `RealityCheckCenter` on the app environment: runs survive navigation; Home narrates; the Home tab badges unseen Briefs; opening the idea clears it.
- Home: `EmptyPanel` (orbs at 64pt, loose row, one serif line, tap an orb for its one-line job, capture field focused); `PanelHeader` (orbs at 48pt; working lines per Sphere; verdict word and title when holding a verdict); `HomeCard.choose` picks the one card (after capture, Brief waiting, next step owed, newest unchecked); `QuickCaptureField` with the mic; recent ideas as compact cards.
- After capture: Home turns toward the new idea with "Want us to look into this?", the ember button, the estimate, Later. Capturing from the Vault switches to Home.
- `RealityCheckButton` shared by Home cards and idea detail: consent on first use, monthly ceiling, hands the run to the center.
- Vault cards: sky band, serif title, lens in mono caps, six dim dots and "Not yet checked" or verdict word with a Confidence ring, "Checking" while live; the capture button hides on downward scroll.
- Tests: `HomeLogicTests` (status, card priority, narration, centre), ForgeCore Sphere lines.
- Known limits: the tab badge is the system red badge, not an ember dot; voice from the Home mic opens the capture sheet rather than recording inline.

**3b fixes (#8, #9): found on the first real runs.**
- The proxy trims `FORGE_PROXY_TOKEN` and `ANTHROPIC_API_KEY` when read; a trailing newline on the stored token made a correct token fail.
- The first prefill got a 400 from the Claude API with nothing logged. The proxy now logs every non-200 from the API with Anthropic's error body and request ID, and returns the message to the app. Output schemas carry source IDs as plain strings (no `format: uuid`). If the API still rejects a structured-output schema, the proxy logs why and retries once with the schema in the prompt, validating with zod itself; such a response carries `X-Forge-Mode: json-fallback`. `/api/action` may run 300 s and the app waits 290 s. Guard tests keep every action's schema within the documented limits.
- `PrefillApplier.saveResearch` deduplicates URLs within one batch, not only against the Library.

## 3b — Verified and unverified

Status as of the end of the 3b session. Everything was checked on the iPhone 18 Pro simulator (iOS 27.2); nothing in 3b has run on a physical iPhone.

**Verified by the developer**
- The proxy deploys from `main` on Vercel; `/api/health` returns `ok` and `authorized` true with the production token.
- `Cmd+U` after #8: ForgeCore 40/40. The app target had 3 failures, all in `PrefillApplierTests.testResearchPagesBecomeChunkedSources`, caused by the in-batch dedupe bug; #9 fixed the code.
- One Reality Check ran end to end on the simulator from Home: research (`/api/research` 200), prefill, and the Brief appeared.

**Not yet verified**
- `Cmd+U` after #9. The dedupe fix is untested on the Mac; `HomeLogicTests` and the rest of `PrefillApplierTests` have passed only as part of the run that had the 3 failures.
- Whether the successful prefill used structured outputs or the JSON fallback. The Vercel log for `/api/action` shows `json-fallback` in that case; this was not reported, so the cause of the original 400 is still unconfirmed.
- The Brief's three buttons: Looks right converting to a Workshop task with the drafted asset (the 3b done-check), Not quite with the struck-through override, I know something you don't with its partial re-score.
- Actual cost of a Reality Check against the $0.15 to $0.60 estimate, the Settings spend line, and the monthly ceiling refusing a run.
- The consent sheet on first run, the offline state with the proxy unreachable, and a run surviving navigation away from the idea.
- Home in all three panel states (idle, working with narration, holding a verdict), the after-capture card, the tab badge, the empty first-launch panel.
- The Vault card treatment and the capture button hiding on scroll.
- Orb motion, including Reduce Motion holding them still.
- Expand and Summarize through the live proxy (3b.1's own check).
- Export after a Reality Check: the new records (RealityCheck, Round, `aiProposed` scores) round-tripping through import.

## Polish pass before 3c

One PR, decision 0012. Screen titles in Fraunces; the Workshop empty state points to the
panel; the Reality Check only on Business ideas (and ideas with no lens yet), the Impact
card for Growth and Creative; one shared button with "Runs on AI · about X¢ · your idea
text is sent to the model.", using the average of real runs once one exists; research on
Haiku with 5 searches and 4 capped fetches, Spheres on Sonnet; a Spend section in
Settings; the Vault capture button inside the list and hidden while it moves; a failed
run keeps its error on the card until dismissed. Tests: ForgeCore
`RealityCheckPolicyTests`; app `HomeLogicTests` (lens rule, failed-check priority,
failure persistence, failure messages); proxy cost and research-tool tests.

**3c: Rounds and rulings** on top of the pre-fill. See `docs/HANDOFF.md`.

## Original scope note (brief v3.1 §11)

- Opportunity Filter (Business lens only) with the shiny-object guard.
- Lens A, all six criteria: definition, rubric, evidence ladder rendered as a
  vertical ladder with the current rung lit, playbook, manual evidence attachment
  (links, notes, voice).
- Potential and Confidence rings (Confidence in ember, "mostly enthusiasm" below 40),
  shortfalls, riskiest assumption, recommendation, Experiment card, versioning UI.
- **Projection / Impact card (§4.0)** under the rings. Business lens: price per unit,
  units in year one, derived recurring per month, each user-entered and editable,
  with a verified (solid) vs assumed (striped) bar; a slice goes solid only when a
  real payment is attached as Evidence at rung 4 or above. Growth or Creative lens:
  who this helps, what changes, how the user would know, same observed vs hoped-for
  bar, no dollar figures. Fields already exist on `Evaluation`; the AI may suggest a
  range labeled as an estimate, which the user accepts or edits.
- Evidence pattern chips on every criterion row (`EvidenceChip`).
- Proxy deployed to Vercel; AI-sharing consent (from Phase 2) gates every call.
- Spheres: Investor, Customer, Builder, Strategist, Skeptic as orbs; Rounds with
  verdict cards, crossfire, rulings; rulings land in the Decision Journal.

Done when: an idea can be evaluated, a Round run, and the user's rulings land in the Journal.

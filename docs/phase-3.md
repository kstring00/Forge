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

Split across PRs.

**3b.1 (this PR): the proxy and the live client.**
- `proxy/`: Vercel project. `GET /api/health`, `POST /api/action` (all twelve typed actions, structured outputs, server-side honesty rules), `POST /api/research` (one web search + fetch turn per call, resumable). Deploy guide in `proxy/README.md`.
- `ProxyAIClient` in the app, chosen automatically when `Local.xcconfig` carries `PROXY_URL` and `PROXY_TOKEN`. Expand and Summarize go live end to end.
- `prefill` action and `PrefillResult` contract declared in Swift, mirrored from `proxy/lib/schemas.ts`.
- `proxy/lib/content.json` generated from ForgeCore (`swift run forge-lens-export`).

**3b.2 (this PR): the Reality Check flow and the Brief screen.** Built:
- `CaptureStateSection`: before a check, the idea shows the sky, the original text and one ember Reality Check button with the cost estimate from the proxy's health endpoint; everything else (Explore, Make it real, tags, notes) sits under a collapsed "More". The first run shows the consent sheet.
- `RealityCheckRunner`: research turns through `/api/research` until done (at most four), pages saved as chunked `ai-found` web Sources plus a "Research notes" source, then `prefill`, then `PrefillApplier`. Orbs light one at a time while the panel works. Offline, failure and over-ceiling are calm states; nothing is written on failure.
- `PrefillApplier`: a RealityCheck with competitors, demand signals and the drafted asset as a Source; proposed Explore answers as unconfirmed AI text (never over the user's own); a new evaluation version with every score flagged `aiProposed`, rungs capped at 2, evidence pointing at unreviewed sources so Confidence stays honest; riskiest assumption, next move, Experiment card; the projection range as an estimate string, never as figures; the panel as a Round.
- `BriefSection`: verdict row, six orbs (Steward dim) with speaking state and disagreement hairlines, what we found with source chips, striped rings while everything is still proposed, the one human task with the drafted asset, and the three buttons. Looks right confirms the proposed Explore answers, writes a Journal ruling, converts to a project with the step and the drafted asset, and opens it: three taps to a task. Not quite expands to the 3a Lab; proposed scores read in the AI colour and the panel's number shows struck through once overridden. I know something you don't saves a user-verified Source and re-scores only the criteria the panel says it touches, in a new version.
- Orbs per §8: layered radial gradients with blur and highlight, idle drift (still under Reduce Motion), working, speaking, dim.
- Settings: spent this month, monthly ceiling, last Reality Check cost. The runner refuses to start past the ceiling.
- Tests: `PrefillApplierTests` (honest records, no overwrite of user answers, rung caps, flag clearing, chunked sources, spend, JSON passthrough).

Known limits: "I know something you don't" is text only (voice reuses Phase 1's capture in Phase 4); its re-score keeps the desk rung cap even for user-verified facts, so a rung above 2 is set by hand in the Lab for now; the research loop runs while the screen is open and resumes from the Library if the app is backgrounded mid-run only in the sense that saved pages persist.

**Original 3b.2 plan, for reference.**
- Capture state: sky, original text, one Reality Check button, nothing else (§0A).
- Cost estimate and the one-time consent note, then research calls looping on `paused`, saving fetched pages as `ai-found` Sources with chunks; then `prefill`; orbs light in sequence.
- Applying the prefill: explorations as confirmed AI notes, a new evaluation version with striped scores and rungs, projection range as an estimate, riskiest assumption, next move, drafted assets as a Source.
- The Brief screen: verdict row, six orbs (Steward dim), what we found with source chips, striped rings, the one human task with drafted assets, Looks right / Not quite / I know something you don't.
- Review by exception: Not quite opens the 3a Lab; I know something you don't records a user-verified Source and re-scores only the affected criteria.
- Monthly ceiling and actual cost in Settings. Orb states per §8.

**3c: Rounds and rulings** on top of the pre-fill.

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

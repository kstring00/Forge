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

## 3b — Scope (next PR)

- Vercel proxy: Anthropic Messages API with JSON contract validation, rate limits, bearer auth, web search and fetch for Phase 4.
- Live `AIClient` reading the proxy URL and token from `Info.plist`.
- Spheres: Investor, Customer, Builder, Strategist, Skeptic as orbs; Rounds with verdict cards, crossfire, rulings landing in the Journal and as bounded Evidence.
- Reality Check button wired to the action, with the cost estimate shown first (Phase 4 completes the Library side).

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

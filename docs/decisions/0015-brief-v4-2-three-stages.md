# 0015 — Brief v4.2: three stages, Home as the overview, Hear the panel

Recorded 2026-11-08, from the design canvas (`docs/design/FORGE_Idea_Detail_canvas.pdf`).

- **Three stages replace the pipeline on screen: Idea · Formation · Reality.** Tabs are
  Home · Idea · Formation · Reality. The stored `Stage` is unchanged, so nothing
  migrates; `Stage.track` maps capture/explore → Idea, evaluate → Formation,
  build/launch → Reality, archived → none (`Track` in ForgeCore). Moving an idea by hand
  sets the track's entry stage. The Idea tab is the Vault filtered to its track, with an
  "Every track" toggle; Formation is a new list led by the orbs in their verdict states;
  Reality is the Workshop with its Journal.
- **Home is the overview.** Mono date and settings button, no bar title; "From idea to
  reality"; the pipeline strip with counts; one next-move card (same priority as before:
  just captured, Brief to hear, step owed, unchecked); capture ("Got an idea?"); three
  sections with "All" to each tab. The next-move card's idea is left out of the sections,
  so no idea appears twice. The after-capture state and the empty first launch stay.
- **One next-step card** (`NextStepCard`): step in 17 pt sans, one 13 pt caveat, progress
  segments, due date, Questions (the drafted asset) and Log a conversation. `Project`
  gains `nextStepCaveat`, `nextStepTarget`, `nextStepCount`, `nextStepDueAt` and
  `nextStepMoves` (lightweight schema change; export carries them as optionals).
  `WorkshopActions.logConversation` writes an outcome entry and advances the count;
  it never closes the step. Looks right fills the fields from the panel's experiment
  (target from the drafted asset: five questions, twenty messages, one page).
- **The council arc** (`CouncilArc`) tops the Formation idea page: six orbs on a 150 pt
  half-circle with names, dashed ember lines between conflicting pairs, the verdict
  inside, "Hear the panel →". `OrbRow` and `PanelHeader` are gone.
- **Hear the panel** (`HearThePanelView`) replaces the Round screen: cards in panel order
  with each split pair pulled adjacent under an ember Split bracket; Agree · Disagree ·
  Find out as pills, Find out outlined in ember; the Steward as a dashed placeholder;
  the summary once all are ruled. "Argue it out" is left out until credits.
- **Phase 8, Monetization & launch, is recorded in the brief and not built:** credits
  (Reality Check 3, Argue it out 1, rulings and logging free, refunds on failure, packs
  that never expire), the four credit moments, Sign in with Apple with a server-side
  ledger, App Attest, and reviews (system prompt only after a win, a Rate row, a
  "Tell us what's broken" link, no gating, no rewards).

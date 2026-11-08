# 0019 — Agree by default, closing the loop, your patterns, and the rest of the second look

Recorded 2026-11-08, after the second look at the v4.2 restructure.

- **Agree is the default.** When the user moves on from Hear the panel (leaving the
  screen, or Looks right), every verdict they did not touch gets an implicit Agree
  ruling (`Ruling.implicit`): it counts as agreement for the tally and the record,
  attaches nothing and writes no Journal entry. Tallies read "2 disagreements · 1 to
  find out", or "Agreed with every voice".
- **Closing the loop.** After the user records what happened on an idea (step done,
  pause, launch, or an outcome in the Journal), `SettleRulingsSheet` lists the rulings
  with no outcome yet, disagreements and find-outs first, with three answers per ruling.
  The outcome lives on the Ruling (`outcomeRaw`, `outcomeNote`, `outcomeRecordedAt`; the
  first outcome stands) and reads back as one line in the Journal: "You disagreed with
  the Strategist. It was right." The user judges; the app never infers a result.
- **Your patterns** (`PatternsView`, from Home and the Journal) computes from settled
  rulings (`Patterns` in ForgeCore): the record against each Sphere, criteria scored high
  or low against outcomes, a plain summary. Nothing is shown under three outcomes.
- **The about-you note** (`PanelMemory`): under 80 words, written from the record, sent
  as `aboutUser` with every call; the prompt tells the Spheres it is the user's own
  record, kept by FORGE, and never to quote it back. Read, edit and reset in Settings
  under "FORGE remembers your track record and shares it with the panel. The AI itself
  doesn't change." An edited note is left alone until reset.
- **Rings open the Lab.** The Potential and Confidence rings on the next-move card open
  the criteria with their evidence (`LabRoute.criteria`); the Est. return figure opens
  the Projection card with its sources.
- **Old data is cleaned once at launch** (`LegacyCleanup`): ids written into prose by
  earlier prefills become titles or go, in every stored text field; a project's step
  target is read from the step text when it was stored as the default
  (`Project.effectiveTarget` does the same at display time).
- **Verdicts renamed on screen**, stored values unchanged: Go build it · Worth a fight ·
  Already solved · Go ask people, each with a one-line explanation under it on the arc
  and the Brief; the prompt names them the same way.
- **Cards:** only stage and trail on the top line; the verdict word moves into the Est.
  return line; placeholders are 13 pt muted sans; an idea in Reality that never saw the
  panel reads "started without the panel" with a Check it link. The sky's top row is
  indigo so white text passes, with shadows under the title and subline.
- **One line a day** on the Idea tab from `Quotes.swift` (text, author, source note; nine
  verifiable quotes to start), rotating daily, dismissible for the day, with a Settings
  toggle: All / Scripture only / Secular only / Off.
- **Dark theme:** the light screenshots came from Settings → Appearance, not from code.
  The window style is now also set at launch from the stored setting.

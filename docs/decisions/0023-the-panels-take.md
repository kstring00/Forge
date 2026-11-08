# 0023 — The panel's take is always findable

Recorded 2026-11-08, after the Brief lived only inline on the idea page and vanished
behind "Not quite".

- **One card on every checked idea.** "The panel's take" sits at the top of the idea
  page in every track: the verdict word and its one-liner, the six orbs in their verdict
  states (the Steward dormant), Confidence, "Open the Brief ›" and "Check again". A Reality
  project page shows the one-row form of the same card under its header.
- **The Brief is its own screen** (`BriefView`, route `LabRoute.brief`). The idea page
  shows the Lab, Explore, the Workshop card, tags and notes by default; "Not quite" on the
  Brief goes back to it.
- **A re-check replaces the take; nothing is lost.** The card reads the newest check;
  History lists every take, newest first, with the current one marked. "Check again" goes
  through the same confirm sheet as the first check.
- Tests: `PanelsTakeTests` (newest wins, History keeps both; orb states read like the arc).

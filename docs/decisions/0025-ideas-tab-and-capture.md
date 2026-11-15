# 0025 — Home · Ideas · Journal, and capture from anywhere

Recorded 2026-11-08, after the stage tabs confused the first real use: ideas vanished from
one tab and reappeared in another, Looks right skipped Formation, and the Reality node
counted projects while the tab listed two.

- **Bottom bar: Home · Ideas · Journal.** Your patterns lives inside Journal (a row at the
  top) and in Settings. The Idea, Formation and Reality tabs are gone.
- **Ideas tab: one list, three sections.** Every live idea under Idea / Formation /
  Reality, each with its one-liner ("Caught. The panel hasn't looked yet." / "The panel
  has spoken. You're deciding." / "You're out testing it."). Search, lens, tag and
  archived filters stay. An empty section says how ideas get there. Reality rows open the
  step; the others open the idea.
- **One count function.** `TrackCounts` groups live ideas by `Idea.track`; the pipeline
  nodes, Home's subline, the Ideas sections and Settings all read it, so a count always
  matches the list behind it. Tapping a pipeline node opens Ideas scrolled to that section.
- **Idea page: a journey bar.** Idea → Formation → Reality with "You are here" and the one
  action that moves it forward (send to the panel; open the Brief; open your step; make it
  real).
- **Cards.** The verdict word on its own line, the Est. return figure under it, never more
  than two lines. "Started without the panel" is "No panel yet".
- **One project per idea.** `convert` returns the existing project. Archiving an idea
  archives its active or paused project. `ProjectCleanup` runs once at launch: a project
  with no idea merges into the idea's newest project of the same name, re-links to an idea
  of the same title that has none, or is archived; a project whose idea is archived is
  archived. The report sits under Settings → Ideas.
- **Capture is one tap from anywhere.** A 64 pt ember mic-plus button docked above the tab
  bar on every top-level screen opens the one capture sheet (keyboard up, "What's your
  hunch?", a 72 pt mic, Save). Home's capture field sits directly under the sky. The
  Home Screen quick action "New idea" opens the same sheet. The old floating Capture
  button is gone.
- **Home: "Your ideas"** with "Biggest opportunity first" under it and a sort menu:
  Biggest opportunity · Newest · Needs the panel · In progress.
- Tests: `HomeLogicTests` (counts, sort), `ProjectCleanupTests`.

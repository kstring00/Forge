# 0013 — 3c, first PR: rulings on the prefill's Round, crossfire only on conflict

Recorded 2026-11-07.

- **Disagreement means on track against off track.** Two Spheres conflict only when
  one says `onTrack` and the other `offTrack`. `cantTell` is an absence of evidence, not
  a position, so it argues with nobody. `Panel.conflicts` in ForgeCore decides this once;
  the Brief's hairlines, the Round screen's crossfire and the proxy's `enforceRound` all
  follow it. Crossfire the model writes between non-conflicting Spheres is dropped on the
  server.
- **The hairline is the way into the crossfire** (§0A step 3). It arcs under the two orbs,
  rising with their distance so lines never overlap, with a 24 pt hit band. Tapping it
  opens the crossfire sheet: both verdicts, the one exchange, a ruling on each. Orbs are
  now 56 pt idle and 96 pt speaking (§8).
- **Rulings never move a score.** Agree writes a Decision of kind `ruling`; if the Sphere
  cited a source, that source is attached to the verdict's criterion as Evidence at the
  criterion's current rung, capped by what the source can prove (desk finds at rung 2,
  assumptions at 0). The score, rung and `aiProposed` flag are untouched, so Potential
  and Confidence do not change: "agreeing with a Sphere never creates Evidence" beyond
  the source it already named (§6A). Disagree writes a Decision and an `assumption`
  Source holding the user's belief (a default sentence until they say why). Find out
  writes a Decision dated by the timebox and an Experiment card built from the
  criterion's playbook step that reaches the next rung; a project, if there is one, gets
  the test as a note. Ruling again replaces the first ruling and removes what it made.
- **The Round screen** follows `docs/design/source/round.template.html`: tally, one card
  per verdict led by its 40 pt orb, the three buttons, crossfire where the panel split,
  and the summary once every verdict is ruled. The Brief carries the three buttons under
  the speaking orb as well, and a line to the Round with how many are ruled.
- **Not in this PR:** re-run diffs, voice on "I know something you don't", rungs above 2
  from user reports. Each is its own PR.

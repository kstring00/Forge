# 0029 — The legibility pass

Recorded 2026-11-08, after the first day of real use: "things are getting hard to see."

- **Floors.** Supporting text 13pt (`.footnote`), secondary 15pt (`.subheadline`), body
  17pt (`.body`), labels 12pt. Every hard-coded `.system(size:)` under 18 became the
  matching text style, so the whole app follows Settings → Display → Text Size.
  `.caption` and `.caption2` are gone from the app; `.footnote` is the smallest.
- **Uppercase mono is for labels of three words or fewer.** Anything longer is a
  `forgeSubhead` (17pt serif, sentence case, ink). Labels are 12pt mono, tracked 1.1.
- **Muted ink lifted.** InkSecondary is `#B8B0A4` on dark and `#5E574F` on light, well past
  the 4.5:1 floor on both grounds.
- **Plain words first** (`Plain` in ForgeCore): "How sure we are" beside Confidence, "How
  big it could be" beside Potential, "The panel (five perspectives)", "Your step", "How
  strong the proof is" for the ladder, "proof level N of 5" for a rung, "Kind of idea" for
  the lens, "voice" for a Sphere. Nothing says rung, lens, Formation or Sphere on its own
  where a new user meets it; the track one-liners already carry Formation's meaning.
- Tests: `PlainTests`.

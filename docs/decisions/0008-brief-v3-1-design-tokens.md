# 0008 — Brief v3.1: specific design direction, Projection/Impact card

Recorded 2026-11-07, on the Phase 1b branch at the developer's request.

- `docs/FORGE_BRIEF.md` replaced with v3.1. The design canvas screenshot is in
  `docs/design/` as the visual reference.
- **Dark is the default theme.** Tokens rebuilt to the brief's hex values
  (ground #1C1916, cards #272320, hairlines #3A342E, text #F1EBE2, muted
  #A39B8F, ember #C4441C on fills and #E58A62 as text). Light inverts them.
  An Appearance setting (Dark / Light / Match system) lives in Settings, default Dark.
- **Ember is reserved** for capture, "next step" and the Confidence ring. The
  business lens tint moved from ember to copper; the Potential ring and the
  recording play button are ink.
- **Type.** Serif for titles, the user's words and numbers; monospaced small
  caps with wide tracking for labels; sans for body. The brief names Fraunces,
  IBM Plex Mono and Inter; the system equivalents are used so no font files
  ship. Each is one token to swap. Supersedes the font choice in 0003.
- **Original text** is italic serif with a 2pt ember rule (`OriginalText`).
  AI text is small muted sans with the spark glyph.
- **Evidence as pattern.** `EvidenceFill` and `EvidenceChip` render solid,
  diagonal stripes and dot grid for verified, AI-found and assumption. Used from Phase 3.
- **Spheres are orbs.** `SphereOrb` renders each Sphere as a blurred radial
  gradient in its palette (Customer blue, Investor ember, Strategist violet,
  Builder green, Skeptic stone, Steward gold).
- **The idea's sky** is now driven by stage, not lens: lavender into a base
  that is slate at Capture and ember by Build (`ForgeColor.sky(for:)`), grain
  multiplied over it.
- **§4.0 Projection/Impact card** is Phase 3 scope. Its six optional fields were
  added to `Evaluation` now (price per unit, units in year one, recurring per
  month; who, what changes, signal) as a lightweight schema change, and are
  carried by export. The card never feeds Potential or Confidence.

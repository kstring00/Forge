# Design references

- `idea-detail-and-round-canvas.webp` — screenshot of the "FORGE Idea Detail" Claude Design
  artifact (two artboards: Idea detail, Round · verdicts) at 40% zoom. Replace with the
  full-size PNG exports from the canvas Share menu when available.

Tokens in `Forge/Design/Tokens/` and colours in `Forge/Design/Assets.xcassets` follow
brief v3.1 §8 and this canvas. Fonts: the brief names Fraunces, IBM Plex Mono and Inter;
the app currently uses the system equivalents (New York, SF Mono, SF) so no font files
ship. Swapping to the named faces is a one-line change per token in `ForgeType.swift`.

- `source/` holds the original "FORGE Idea Detail" artifact and the two unpacked page
  templates (idea detail, Round) with their CSS and sample data. The fonts it bundled
  (Fraunces, Inter; OFL) are described in `docs/decisions/0009-fonts-from-the-design-bundle.md`.

- `source/FORGE_Idea_Detail_v2.html` is the second version of the artifact, with six
  artboards: Idea detail, Round · verdicts, Home A · the stage, Hear the panel, The panel,
  up close, and Home B · today (set aside). `source/panel-up-close.template.html` is that
  artboard unpacked (fonts stripped): the orb CSS and the four states, which
  `Forge/Design/Components/OrbView.swift` follows (decision 0014). Home A, Hear the
  panel and Home B are design input not yet built.

- `FORGE_Idea_Detail_canvas.pdf` — the full canvas as of brief v4.2 (eight boards: Idea
  detail, Round · verdicts, Home A · the stage, Hear the panel, Home B · today, Home
  overview, Credits screen, Credit moments). The app follows Home overview, Home A's
  arc and Hear the panel (decision 0015); the credits boards are Phase 8.

- `home-leveled-up.pdf` — the "Home · leveled up" artboard the current Home follows
  (decision 0016).

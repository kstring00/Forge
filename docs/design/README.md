# Design references

- `idea-detail-and-round-canvas.webp` — screenshot of the "FORGE Idea Detail" Claude Design
  artifact (two artboards: Idea detail, Round · verdicts) at 40% zoom. Replace with the
  full-size PNG exports from the canvas Share menu when available.

Tokens in `Forge/Design/Tokens/` and colours in `Forge/Design/Assets.xcassets` follow
brief v3.1 §8 and this canvas. Fonts: the brief names Fraunces, IBM Plex Mono and Inter;
the app currently uses the system equivalents (New York, SF Mono, SF) so no font files
ship. Swapping to the named faces is a one-line change per token in `ForgeType.swift`.

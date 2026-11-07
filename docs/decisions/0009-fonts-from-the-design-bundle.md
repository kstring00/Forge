# 0009 — Ship Fraunces from the design bundle; keep system mono and sans

Recorded 2026-11-07, Phase 3a.

The "FORGE Idea Detail" design artifact bundles Google Fonts' latin subsets of
Fraunces (variable: opsz 9–144, wght 100–900, default instance 900) and Inter.
Both are SIL Open Font License 1.1.

- **Fraunces ships.** The variable font's default instance is Black, and relying
  on SwiftUI to drive the weight axis of a custom font is a risk we do not need,
  so the variable files were instanced to static faces at optical size 36:
  `Fraunces-Regular.ttf` (wght 400), `Fraunces-SemiBold.ttf` (wght 600) and
  `Fraunces-Italic.ttf`. Registered in `Info.plist` under `UIAppFonts`; used by
  PostScript name in `ForgeType`.
- **Inter does not ship.** Only the regular weight was in the bundle; the body
  needs medium and semibold too. The system sans keeps every weight and Dynamic
  Type behaviour for free.
- **IBM Plex Mono does not ship** (it was not in the bundle). The system
  monospaced face stands in at 11pt, uppercase, 0.14em tracking.
- Sizes follow the canvas exactly (34 title, 17 italic original, 28 ring values,
  24 projection figures, 22 criterion scores, 19 riskiest assumption, 12 ladder
  numbers) and are declared relative to text styles so they still scale.
- The unpacked canvas templates are kept in `docs/design/source/` next to the
  original artifact for future reference.

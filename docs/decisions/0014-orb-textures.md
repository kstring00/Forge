# 0014 — Orb textures: each Sphere's identity is inside the orb

Recorded 2026-11-07, from the "The panel, up close" artboard in
`docs/design/source/FORGE_Idea_Detail_v2.html`.

- **One view, `OrbView(sphere:state:size:)`**, replaces `SphereOrb` everywhere an orb
  appears, down to the 12 pt chips. Layered gradients clipped to a circle, never images.
- **Three layers per orb:** the base radial gradient (light at 35%/30%, base at 47%, deep at
  the rim), a specular highlight at 32%/26%, and one signature texture: Customer concentric
  ripples expanding; Investor a warm conic sweep turning; Strategist one bright diagonal
  seam drifting; Builder fine strata sliding; Skeptic a dark eclipse bite at the upper
  right waxing and waning; Steward a thin inner halo breathing. Each orb also glows softly
  in its own colour.
- **States** (`OrbState`): `idle` glows; `working` is brighter and three times faster;
  `verdict(.onTrack)` glows; `verdict(.cantTell)` fogs over (35% saturation, 55% opacity,
  no glow); `verdict(.offTrack)` wears a 1.5 pt ember ring with a 2 pt gap and keeps its
  glow; `speaking` is 96 pt with a stronger halo and the others `dim` to 40%;
  `dormant` is the Steward before Phase 5 at 22%.
- **Motion** loops on 8 to 14 seconds per Sphere, each starting at its own point in the
  cycle so no two move together, driven by one `TimelineView` at 30 fps. Chips under
  24 pt do not animate. Reduce Motion holds every texture still.
- The artifact's other new artboards (Home A · the stage, Hear the panel, Home B) are
  recorded in `docs/design/README.md` as input not yet built.

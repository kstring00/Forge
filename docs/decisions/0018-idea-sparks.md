# 0018 — Idea sparks: one living mark per idea; orbs only where the panel speaks

Recorded 2026-11-08, from the "Idea sparks" artboard (`docs/design/idea-sparks.pdf`).

- **`IdeaSpark(idea:size:)`** replaces every stacked-orb decoration on cards. Three stages
  from `Idea.track`: the **seed** (Idea) is a lavender point of light in a dashed halo,
  pulsing on a six-second breath, with no Sphere colour; the **swirl** (Formation) is an
  angular gradient of the five Sphere colours weighted by verdict (on track full, can't
  tell faint, off track tinted toward ember), an inner shadow, a soft violet glow and a
  bright diagonal seam when any pair splits, turning once in 24 seconds; the **flame**
  (Reality) is an ember core with a glow and one ring per logged conversation or
  attached payment, up to five, rippling outward over six seconds. Gradients only.
  44 pt on cards, 128 pt in the idea page header. Still under Reduce Motion and under
  24 pt.
- **A three-segment stage trail** (lavender · violet · ember) sits on every card, lit up
  to the idea's stage.
- **`OrbView` stays where the panel itself appears:** the council arc, Hear the panel and
  its crossfire, the first-launch panel, and the working row while a check runs. The
  mini orbs on the Reality Check button, the Explore prompt markers and the old Round
  row are gone (a colour dot marks which Sphere asks an Explore prompt). `MiniPanel`
  and `SphereDots` are removed.

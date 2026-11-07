# 0011 — Brief v4.1: Home is the panel's desk; Vault cards imply the path

Recorded 2026-11-07, Phase 3b.3.

- `docs/FORGE_BRIEF.md` replaced with v4.1. §7 rewrites Home around the six
  orbs: first launch shows the orbs large with one serif line and the capture
  field; with content, the panel reflects the most recent idea (idle, working
  with a nine-word line per Sphere, or holding a verdict), then one card, the
  capture field, and recent ideas with the path on every card.
- **Reality Checks moved to app level.** `RealityCheckCenter` on
  `AppEnvironment` owns one runner per idea, so a check keeps running when the
  user leaves the idea, Home narrates it, and the Home tab badges when a Brief
  is ready. The idea screen and every card read the same runner.
- **The nine-word lines and one-line jobs** are static content in ForgeCore
  (`SphereProfile.workingLine`, `.oneLine`) with tests for length and tone.
  The app speaks as "we" in exactly the three moments §7 names.
- **After capture** is a Home state, not a screen: saving from the field or the
  sheet sets `justCapturedIdeaID`, the tab switches to Home, and the orbs turn
  toward the idea with the ember button, the estimate and a quiet Later.
- **Vault cards** (developer's addition, same treatment as Home): a 6pt sky
  band keyed to stage, serif title, lens in mono caps, six dim Sphere dots with
  "Not yet checked" or the verdict word with a 22pt Confidence ring, "Checking"
  while a run is live. The capture button hides while the list scrolls down.
- **Tab badge** is the system badge, which is red, not ember. SwiftUI's TabView
  does not allow recolouring it; a custom tab bar is not worth it for one dot.
  Noted for the Phase 7 polish pass.
- **The reflective prompt** is gone from Home; §7 v4.1 does not list it. The
  prompt pool stays in ForgeCore for a later home.

# 0012 — Polish pass before 3c: research on Haiku, the check is for Business ideas

Recorded 2026-11-07, at the developer's request.

- **Research runs on Haiku 5.5, Spheres stay on Sonnet 5.5.** The proxy splits
  `researchModel` (Haiku) from a new `sphereModel` (Sonnet). Haiku uses the basic web
  tools; the `_20260209` dynamic-filtering versions are documented for Opus and Sonnet.
  Searches drop from 8 to 5 per check and fetches from 8 to 4, each page cut to 4,000
  tokens. Searches are billed per use ($0.01), so they set the research floor. The
  target is 10 to 20 cents per check; the static estimate is now 10 to 25 cents and is
  replaced on the card by the average of the last five finished checks.
- **Cost copy.** Every Reality Check button reads "Runs on AI · about X¢ · your idea
  text is sent to the model." in one shared view. Settings has a Spend section: checks
  finished this month, what they cost, the average, the last check, and all AI spend
  (which also counts runs that failed partway). If FORGE ever ships with a paid panel,
  these are the numbers to price from.
- **The Reality Check is offered only on Business ideas**, and on ideas with no lens yet,
  so a fresh capture still gets one tap to working (`RealityCheckPolicy`). Growth and
  Creative ideas get the §4.0 Impact card; saving its three answers starts their first
  evaluation in their own lens. Home never offers them a check and their cards read
  "Judged by impact". The Lab's placeholder Reality Check button ("arrives with the
  next build") is gone; a Business idea scored by hand shows the real button above the Lab.
- **A failed run never resets to idle silently.** The app-level center keeps the last
  failure per idea, in UserDefaults so it survives a relaunch, until the user dismisses
  it or runs again. The button shows it with Dismiss; cards read "Check failed"; Home
  puts a failed idea's card ahead of the Workshop's next step. Messages say which step
  stopped, what was saved, and what the attempt cost. A 504 from Vercel is named as a timeout.
- **Screen titles are Fraunces** through the UIKit navigation-bar appearance, set once at
  launch; SwiftUI has no font hook for navigation titles. Settings now uses a large title.
- **The Vault's capture button** lives inside the Vault list's root screen, so it never
  follows the user into an idea, and hides while the list moves.

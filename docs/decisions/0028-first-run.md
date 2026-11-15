# 0028 — The first run: welcome, a free first check, a one-time guide

Recorded 2026-11-08, with the revised "First run" artboard.

- **Welcome** (`WelcomeView`, full screen, once while the vault is empty): the sky, the six
  orbs, one line, "Capture your first hunch", and the bundled example only behind "No idea
  right now? See an example" (`ExampleIdea`; it becomes an ordinary idea).
- **The free-check screen** (`FirstCheckSheet`) after the first capture, while no check has
  ever come back on this phone: "Want the panel to look into this?", **Look into it · free**,
  the AI-sharing line with the pointer to Settings → AI, and **Not yet, just save it**.
  Look into it records consent (`AIConsent.grant`) and starts the check; the proxy makes a
  device's first check free and counts it against nothing (decision 0027). The eight-word
  guard runs first; a blocked idea keeps its free check and says so.
- **The first Brief's guide**: three dismissible callouts (`FirstRunCallout`) on the orbs
  ("Tap any one to hear it"), the verdict, and the next step. Each X is for good.
- **After the first Brief**, one calm line under the buttons on a check the proxy marked
  free: "That was your free check. Want to keep going? Your next ones come from your weekly
  allowance." No pop-up. `RealityCheck.wasFree` comes from `freeCheck` on the opening
  research turn.
- **Settings → Developer → Replay first run** (Debug builds only): the welcome, the
  free-check screen and the guide run again on top of real state; nothing is deleted, the
  persisted flags are untouched, and the proxy still decides what is free (a developer
  token is never free, so nothing real is spent).
- Tests: `FirstRunTests`.

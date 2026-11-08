# 0026 — "New hunch" from Siri, Shortcuts and the Action button

Recorded 2026-11-08.

- `NewHunchIntent` (AppIntents) opens the app (`openAppWhenRun`) and asks for voice capture
  through the same `QuickActions` the Home Screen quick action uses; the root opens the
  capture sheet already listening. `HunchShortcuts` registers the phrases ("New hunch in
  Hunch", "Hunch new hunch", "Catch a hunch in Hunch", "Capture an idea in Hunch"); the app
  name in each comes from the bundle display name, so it follows the rename.
- App Shortcuts appear in the Shortcuts app and in the Action button picker without setup.
- Nothing is recorded until the sheet is up and the mic is live; nothing is sent anywhere.

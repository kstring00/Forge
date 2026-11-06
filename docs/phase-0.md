# Phase 0 — Scaffold

Done when: the app launches with empty states on all three tabs, dark mode works,
and the tests pass. Built from a Linux container; the ForgeCore package was
compiled and its 33 tests run here. The app target was not compiled here and
needs its first build on the Mac.

## Built

- **ForgeCore package.** Shared enums (lens, stage, source class, Sphere, verdict, ruling, and so on), the lens content types, all three lenses fully authored (A1 to A6, B1 to B5, C1 to C5), the six Sphere profiles with the common prompt rules, the ten Opportunity Filter questions, the reflective prompt pool, and pure scoring, triage and shortfall logic.
- **Tests on ForgeCore.** Scoring bounds and rounding, Potential and Confidence independence, the A2 three-people rule, Confidence breakdown, every criterion complete, A2 the only ladder-scored criterion, no gamification language, Spheres cover every business criterion, the Steward is Phase 5, triage thresholds, shortfall selection.
- **SwiftData models.** All 22 models from the brief including the §6C additions, under a versioned schema with an empty migration plan and CloudKit explicitly off. Original text has a private setter. Evaluations are append-only through `Idea.beginEvaluation` and `Evaluation.finalize`. A verdict with no sources is forced to `cantTell` in the model initialiser.
- **App shell.** Home, Vault, Workshop tabs with empty states; floating Capture button; a text-only capture sheet that saves an Idea; a minimal idea detail that shows the original text with a lock glyph.
- **Design tokens.** Warm neutral palette with dark variants in the asset catalog, ember accent, lens tints, serif display face for titles, monospaced uppercase labels, spacing, motion that respects Reduce Motion. Components: EmptyState, EmberButton, SparkGlyph and AIText, GrainGradient, Ring (shell), IdeaCard.
- **AI contract.** `AIClient` protocol, ten typed actions with `runRound` in place of "challenge", one Codable result type per action, and an offline client so every screen can show its offline state.
- **Project plumbing.** XcodeGen spec, xcconfigs with a git-ignored local file, Info.plist with microphone and speech usage strings, privacy manifest, app icon.

## Deliberately skipped

- Voice capture, paste, search, filter, sort, archive UI (Phase 1).
- Any network code, the proxy, and the real AI client (Phase 2).
- Evaluation UI, the evidence ladder, rings with data, Spheres UI (Phase 3).
- The blob Vault view and the spectrum Compare view from the reference images (later, optional).
- A `Settings` screen; Advantages, Constraints and the Steward charter have models but no UI (Phase 5b).

## Needs the developer

1. **First build on the Mac.** Run `xcodegen generate` and build. The two things most likely to need a touch are the `private(set)` properties on `@Model` classes (if the macro rejects them, switch to a plain `var` and keep the runtime test) and any relationship inverse SwiftData wants declared differently. `ModelContainerTests` will say which.
2. **Confirm the look.** Launch in light and dark, capture one idea, open it. The grain header, the serif title and the mono labels are the three choices worth reacting to now, before Phase 1 builds on them.
3. **Run the full scheme tests** on a simulator so the SwiftData tests (immutability, append-only, schema) run for the first time.

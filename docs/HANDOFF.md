# Handoff — end of Phase 3b

Public name: **Hunch**. The repo, the brief and the code keep FORGE.

Read with `docs/FORGE_BRIEF.md` (v4.1, the source of truth), `docs/decisions/`
and `docs/phase-*.md`. This file holds only what those do not.

## Current phase

3b is merged to `main` (PRs #6–#9) and one Reality Check has run end to end on
the simulator. 3b is not fully verified; see "3b — Verified and unverified" in
`docs/phase-3.md`. 3c is under way: 3c.1 (rulings and crossfire, decision 0013, with the orb textures, 0014) is PR #12; the v4.2 restructure (decisions 0015 to 0019: three stages, Home · leveled up, Hear the panel, confirm-first AI, Est. return, Idea sparks, closing the loop, your patterns) is PR #13 on its own branch. Still to come: re-run diffs, voice on "I know something you don't", rungs above 2 from user reports.

The brief's rule: do not start a phase until the previous one runs on device.
The developer reports results and screenshots; wait for them.

Before 3c, these still need the developer:
- `Cmd+U` after #9.
- The 3b done-check: Reality Check → Looks right → a Workshop task with the drafted questions.
- Since decisions 0027/0028 the first check on a device is free (proxy `startCheck`, Apple's DeviceCheck bits) and the app has a first run: `WelcomeView`, `FirstCheckSheet`, `FirstRunCallout`, Settings → Developer → Replay first run (Debug).
- Since decision 0026 `NewHunchIntent` ("Hey Siri, new hunch", Shortcuts, the Action button) opens voice capture through `QuickActions`.
- Since decision 0025 the bottom bar is Home · Ideas · Journal; `IdeasView` lists every idea by track, `TrackCounts` is the one count, `ProjectCleanup` runs once at launch (report in Settings → Ideas), and capture is the docked ember button plus the Home Screen quick action.
- Since decision 0024 the prefill carries `pivots`; the Brief shows them as "What if…" cards when Confidence is under 40 or the verdict is cantTell or compete, and "Make this its own idea" spawns an unchecked sibling.
- Since decision 0023 the Brief is its own screen (`BriefView`) behind "The panel's take" card on every checked idea page and on Reality project pages; History lists every take.
- Whether the Vercel log for `/api/action` shows `json-fallback` or `json-retry`. If it does, structured outputs are being rejected and the prefill schema should be split or shrunk so the fallback stops being the normal path. Since decision 0022 a list item that fails the contract is dropped and counted rather than failing the run.

## Open bugs and known gaps

- **"I know something you don't" caps user-verified facts at rung 2.** It reuses `prefill`, whose server-side clamp is the desk ceiling. A user-verified source should be allowed above rung 2. It also re-runs the whole prefill, which is slow and costly, to re-score a few criteria.
- **§0A step 6, "the return": the source and the rung are built (decision 0020); the partial re-run of the touched Spheres, with its diff, is not yet.**
- **Every Reality Check scores under the Business lens.** `PrefillApplier` calls `beginEvaluation(lens: .business)`. Fine until Phase 5; wrong after.
- **A run survives navigation, not app suspension.** If iOS suspends the app mid-check, the run stops. Saved pages persist; the prefill does not resume.
- **Re-running a Reality Check does not diff** the competitor set and verdict (§6D).
- **Rate limiting is per serverless instance**, so it bounds bursts, not totals. The monthly ceiling in the app is the real control.
- **The cost estimate before the first real run is static** (10–25¢ in `proxy/lib/pricing.ts`). After one finished check, the button quotes the average of the last five (decision 0012).

## Polish not done

From the brief and the developer's requests:
- The Home tab shows the system red badge, not the ember dot §7 asks for. SwiftUI's TabView can't recolour it.
- Disagreement hairlines between orbs are not tappable. Crossfire is reached by tapping an orb (§0A step 3 says tap the line).
- Orb sizes on the Brief are 44 pt idle and 72 pt speaking; §8 says 56 and 96.
- The Home mic opens the capture sheet rather than recording inline.
- IBM Plex Mono and Inter are not bundled; system faces stand in (decision 0009).
- Full-size PNG exports of the design canvas, to replace the 40% screenshot in `docs/design/`.

Developer checks deferred from earlier phases and never reported:
- Voice capture on a physical iPhone. It was parked "until before Phase 3" and is still pending.
- The 3a Lab walkthrough and the Fraunces font check.
- The Phase 2 loop walkthrough (tests passed; the manual walk was not reported).

## What a fresh session needs to know

**Where things build.** The app target compiles only on the developer's Mac.
This container builds and tests the rest:
- `cd ForgeCore && swift test` (40 tests). The Swift 6.0.3 toolchain is in `/opt/swift`, installed by the "Forge" cloud environment's setup script.
- `cd proxy && npm install && npm run typecheck && npm test` (20 tests).
- `npm run schema -- prefill` reports a schema against the structured-output limits.

**After adding Swift files**, the developer runs `xcodegen generate`. `Forge.xcodeproj` is not committed.

**Lens content is single-sourced.** After any change to lenses, Spheres or Explore prompts in ForgeCore, regenerate the proxy's copy:

```bash
cd ForgeCore && swift run forge-lens-export > ../proxy/lib/content.json
```

**The proxy.** Vercel production builds from `main` with Root Directory `proxy`. Env vars `ANTHROPIC_API_KEY` and `FORGE_PROXY_TOKEN`. `/api/action` needs Fluid Compute for its 300 s limit. Every Claude API error is logged with Anthropic's body; check Vercel → Logs first. The app reads the URL and token from `Forge/Config/Local.xcconfig`, which is not committed; a URL there needs the `https:/$()/` trick.

**There is real data on the developer's device now.** Everything so far was added to `ForgeSchemaV1` as lightweight changes: new models, new attributes with defaults, new optional relationships. Anything else, such as a rename, a type change or a new non-optional attribute without a default, needs a `ForgeSchemaV2` and a migration stage in `ForgeMigrationPlan`. Add new fields to the export document as optionals so old exports still import.

**Tests that touch SwiftData** must hold the container for the life of the test. Use `TestStore` (`ForgeTests/TestStore.swift`). A `ModelContext` does not retain its container, and a temporary container crashes on the first insert.

**3c starts from data that already exists.** Every Reality Check writes a `Round` with the panel's `Verdict`s and `Crossfire` (`PrefillApplier`). `Ruling` is in the schema. The proxy's `runRound` action and `enforceRound` are written and unit-tested but have never run live. "Looks right" writes a `Decision` of kind `.ruling`, and Home uses it to decide when a Brief has been reviewed. The Round screen's exact CSS and sample data are in `docs/design/source/round.template.html`.

**Workflow.** Work on the branch the session names. Open draft PRs. Merge only when the developer asks, then reset the branch to `origin/main`. New brief versions arrive as uploads; copy them verbatim over `docs/FORGE_BRIEF.md` and record what changed in `docs/decisions/`.

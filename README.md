# FORGE

Capture the idea. Test its potential. Make it real.

A native iOS app (SwiftUI, SwiftData, iOS 17+) for one person to capture ideas,
pressure-test them against named frameworks and a panel of framework-bound
Spheres, and turn the worthwhile ones into projects.

## Documents

- `docs/FORGE_BRIEF.md` is the source of truth for product and architecture.
- `docs/00-first-deliverable.md` is the §13 pre-code deliverable: decisions, file tree, A2 content.
- `docs/decisions/` records each decision the developer made.
- `docs/phase-0.md` and `docs/phase-1.md` list what each phase built, skipped, and needs checked on device.

## Layout

- `ForgeCore/` is a Swift package with no UI and no database: lens content, Sphere
  profiles, scoring, triage, shortfalls, shared enums. It builds and tests on Linux and macOS.
- `Forge/` is the iOS app: SwiftData models, services, design tokens, views.
- `ForgeTests/` are the app-target tests (SwiftData immutability, append-only evaluations, schema).
- `proxy/` is reserved for the Phase 2 Vercel proxy.

## Run

```bash
brew install xcodegen
xcodegen generate
open Forge.xcodeproj
```

Copy `Forge/Config/Local.xcconfig.example` to `Forge/Config/Local.xcconfig` and set
`DEVELOPMENT_TEAM` for device builds. The proxy values stay empty until Phase 2.

## Test

Everything in the Forge scheme (app tests plus ForgeCore tests):

```bash
xcodebuild test -scheme Forge -destination 'platform=iOS Simulator,name=iPhone 15'
```

ForgeCore alone, anywhere Swift runs:

```bash
cd ForgeCore && swift test
```

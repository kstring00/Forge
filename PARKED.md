# Parked

**Date parked:** November 15, 2026.

**Why:** a general chatbot does the same job for free. Kyle tried it against his own app and chose the chatbot.

Nothing here is being worked on. This file says where things stand, so the repo can be picked up, or picked apart for a different app, without reading its history.

## The proxy is shut down

The app's server lived at `forge-proxy-three.vercel.app` (the `proxy/` folder, deployed by Vercel from `main`).

- **Kill switch.** When the environment variable `PROXY_DISABLED` is `true`, every route answers `503 {"error":"Service paused"}` as its first act: before the method check, before any auth, before the request is read, before anything is sent to the AI.
- **The bearer token is gone.** The proxy used to accept one shared token (`FORGE_PROXY_TOKEN` on Vercel, `PROXY_TOKEN` in the app's build settings). That token was exposed. It has been removed from the code on both sides and not replaced. Nothing reads it, and no `Authorization` header opens anything. Even with the switch off, every request is refused (401) and nothing is sent upstream.
- **Vercel's settings are not in the repo.** Shutting it down there means setting `PROXY_DISABLED=true`, deleting the token and the Anthropic key, and redeploying, all by hand in the Vercel dashboard. This file cannot say whether that has been done; a request to the address above answering `503 {"error":"Service paused"}` is the proof.
- **Older deployments keep the settings they were built with.** Deleting a variable only affects new deployments. Revoking the Anthropic key at Anthropic is what makes every old copy harmless.
- **The bench and the local test server** (`npm run bench:*`, `npm run serve`) can no longer get through either, for the same reason.

To bring a proxy back for a future app, it needs a new way in. The App Attest work in PR #16 is the starting point: no shared secret ships in the app at all.

## Current state of the app

**What it is.** Hunch (called FORGE in older files) is an iPhone app, SwiftUI and SwiftData, iOS 17 and later. You capture an idea, an AI panel researches it on the web and scores it, and the app walks you through testing it with real people.

**What's in `main`:**

- Capture by typing or voice; Home, Ideas, Sparks, Plans and Journal tabs.
- The check: web research with cited sources, five panelists, the Brief, What-ifs, launch plans, re-scores after real conversations.
- Memberships with StoreKit 2: Free, Plus and Pro, monthly and yearly, a top-up, rollover, upgrades, downgrades at renewal, refunds, billing problems, Restore.
- The Home usability pass (decision 0044) and the app icon.
- 40 decision records in `docs/decisions/`. `docs/RELEASE.md` has the in-app purchase setup; `docs/PRICING.md` has the prices and measured costs.

**How far it was verified:**

- Last built and run on Kyle's Mac on November 10 (iPhone 18 Pro simulator, iOS 27.2). The app built, every test passed (the rule tests and 16 StoreKit tests), and the membership and Home flows were used by hand.
- Two later changes have **not** been built on a Mac: the new icon (one image file) and the removal of the token from the app's build settings and network client (November 15). Both passed a syntax check only.
- Tests that run without a Mac: 148 rule tests in `ForgeCore`, 43 server tests in `proxy`. Both pass on `main` as parked.

**What was never done:**

- No TestFlight build, no App Store listing, no products created in App Store Connect.
- The app has never run on a real phone, so App Attest has never run at all.
- The Apple Developer enrollment (Stringham Web Design LLC) was approved on November 15. Signing was not set up: the bundle ID is still `app.forge.ios` and the display name is still "FORGE".
- No privacy policy. The consent screen says "an AI model" and does not name the provider.
- Sign in with Apple is not built, so a plan does not follow a person to a new phone.
- Potential scores were unreliable (the same idea could land 15 to 25 points apart, and scores sat near the bottom). The measuring tool is in PR #44; the fix was never started.

**With the proxy off,** the app still opens and captures ideas. Anything that needs the panel fails with "couldn't reach the panel".

## Open pull requests

All left open and unmerged, with their branches. None is needed for anything in `main` to work.

| PR | What it is |
|---|---|
| #16 | Proxy protection: App Attest with a DeviceCheck fallback, no shared token in release builds, per-device limits, a daily spend ceiling. Brought up to date with `main` on November 15. Never run on a device. |
| #22 | The first check on a device is free, remembered across reinstalls with DeviceCheck. Built on #16. |
| #45 | Spend controls: a $3 daily ceiling from actual token usage, free-tier checks stop at 70% of it, alert emails to the owner, an owner-only Spend screen in Settings. Built on #22. |
| #46 | An owner-only dashboard at `/owner`: active devices, checks, cost per check, month projection, a hand-entered credit balance with days left. Built on #45. |
| #44 | A benchmark that measures how far Potential moves when the same idea is scored repeatedly. The first real run was started on Kyle's Mac; its results were never brought back. |
| #30 | An older quality benchmark: answer keys, a comparison against a plain chatbot and a competitor, a ship gate. Far behind `main` and conflicting. |

#16, #22, #45 and #46 are a chain and merge in that order. They were written before the token was removed from `main`, so they would need that reconciled first: #16 still accepts developer tokens for the simulator.

## What's reusable for a future app

**The SwiftUI shell.**

- `project.yml` (XcodeGen) with `Forge/Config/*.xcconfig`: a project that is generated, never committed, with personal settings kept out of git.
- `ForgeCore/`: a plain Swift package holding every rule, with tests that run on Linux. The pattern (decide in the package, draw in the app) is what let most of this be tested without a Mac.
- `Forge/Design/`: colour and type tokens, cards, buttons, the capture button and sheet (typing and voice).
- `Forge/Features/Home/`: compact rows that open in place, one next-move card, and the edge handling for the status bar, tab bar and a floating button (decision 0044).
- SwiftData models with export and import (`Forge/Services/Export/`), and a first-run flow.

**StoreKit subscriptions.** The most finished part, and independent of what the app is about.

- `ForgeCore/Sources/ForgeCore/Membership.swift`, `Subscription.swift`, `PlanRules.swift`: plan state from Apple's entitlement and renewal info, an allowance ledger with rollover, upgrade and downgrade handling, the wording for every state.
- `Forge/Services/Membership/`: the StoreKit 2 store (current entitlements, renewal info, transaction updates, refunds, Restore) and an optional iCloud copy of the ledger.
- `Forge/Features/Membership/MembershipView.swift`: a plan screen that says what a tap will do before it does it.
- `Hunch.storekit` and `ForgeTests/MembershipStoreKitTests.swift`: 16 tests against Apple's test store, including renewals, a downgrade landing, refunds and billing retry.
- Decision 0043 explains Apple's rules that the code depends on. `docs/RELEASE.md` has the App Store Connect steps.

**The proxy pattern.** A small serverless project that keeps the AI key off the phone.

- `proxy/api/*.ts` and `proxy/lib/`: typed requests and answers (`schemas.ts`), answers checked against a schema with a retry and a salvage path (`structured.ts`, `salvage.ts`), prompt caching (`prompts.ts`), cost counted from real token usage (`pricing.ts`), one config file for models and plan numbers (`config/hunch.ts`).
- `proxy/lib/packet.ts`: one shared research pass that every later call reads, with each finding tied to its source page.
- `proxy/bench/`: running the real pipeline on sample ideas and comparing two versions for cost and quality.
- The kill switch in `proxy/lib/http.ts`.

**The App Attest work** (PR #16, not in `main`).

- `proxy/lib/attest.ts`: checking Apple's attestation and each request's signature, with a counter that only moves forward.
- `Forge/Services/AI/AppAttest.swift`: the phone's side, including what to do after a reinstall.
- `proxy/lib/auth.ts`: reading a request's exact bytes on Vercel, which a signature check needs. The first version got this wrong; the note in decision 0021 says how.
- `proxy/lib/store.ts`, `limits.ts`: per-device limits and a daily ceiling on Upstash Redis.
- Untested on a real device. Treat it as a careful draft.

## Secrets

The repo and its full history (every branch, 193 commits) were searched on November 15 for the bearer token and for Anthropic API keys.

- No Anthropic key (`sk-ant-…`) appears anywhere.
- No real token appears anywhere. Every match is a placeholder (`replace-with-a-long-random-string`, `YOUR_TOKEN`) or a made-up value in a test (`dev-token-0123456789abcdef`, `sk-test`, `mock`).
- The files that held the real values (`Forge/Config/Local.xcconfig`, `proxy/.env`) are in `.gitignore` and were never committed. No `.env`, key or certificate file is in the history.
- The search could not look for the exact token, because its value was never in the repo or shared with the tool doing the search. It looked for the places a token would sit and for anything shaped like a secret.

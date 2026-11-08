# 0021 — Protect the proxy: App Attest, per-device limits, a daily ceiling

Recorded 2026-11-08, first of the TestFlight PRs.

- **No shared token in the binary.** `Base.xcconfig` blanks `PROXY_TOKEN` for every Release
  configuration after the Local include, so a TestFlight build has nothing to leak.
  Debug builds keep the developer token for simulators; the proxy accepts those from
  `FORGE_DEV_TOKENS` (and `FORGE_PROXY_TOKEN`) and logs them as `dev:n`, unlimited.
- **App Attest is the door.** Once per install the app makes a Secure Enclave key, fetches a
  one-time challenge, has Apple attest the key and registers it at `POST /api/attest`. Every
  later request signs SHA-256 of its exact body; the proxy checks the chain to Apple's App
  Attest root, the nonce, the App ID (`APPLE_TEAM_ID.APP_BUNDLE_ID`), the credential id, the
  environment (development attestations only when `APP_ATTEST_ENVIRONMENT=development`),
  and a counter that only moves forward. Routes that take assertions read the raw body.
  Apple's root is fetched once per instance (or pinned with `APPLE_APP_ATTEST_ROOT_PEM`),
  since this container could not reach apple.com to embed it.
- **DeviceCheck is the fallback** where App Attest is unavailable: the token is validated
  with Apple once a day (a DeviceCheck key from the account), and a random per-install id
  from the keychain carries the per-device limits.
- **Limits fail politely.** Five Reality Checks per device per UTC day
  (`FORGE_CHECKS_PER_DEVICE_PER_DAY`, counted on a research opening turn) and a daily spend
  ceiling for the whole proxy (`FORGE_DAILY_SPEND_USD`). Both answer 429 with "The panel is
  resting until tomorrow."; the app shows the line as is (`AIError.resting`).
- **Usage per device.** Every served call logs a JSON line and adds to a per-device daily
  hash; `GET /api/usage?day=` with `FORGE_ADMIN_TOKEN` lists devices, checks, calls, spend
  and the ceiling.
- **State lives in Upstash Redis** through Vercel's integration; without it the proxy
  falls back to per-instance memory and says so in `/api/health` (`store: "memory"`).
- If the proxy forgets a key (store reset), it answers `attest_unknown_key`; the client
  attests again once and retries.

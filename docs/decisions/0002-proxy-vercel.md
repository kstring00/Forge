# 0002 — AI proxy: Vercel Edge Function, bearer token

Decided 2026-11-06. The proxy lives in this repo under `proxy/` as a Vercel
Edge Function in TypeScript. The app sends a long random bearer token stored in
the git-ignored `Local.xcconfig`. Adequate for a single-user tool; App Attest
can replace it later without touching the app's AI contracts.

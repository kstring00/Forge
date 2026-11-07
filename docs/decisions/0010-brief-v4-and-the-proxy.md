# 0010 — Brief v4: the user talks, the Spheres work; the proxy ships first

Recorded 2026-11-07.

- `docs/FORGE_BRIEF.md` replaced with v4. §0A is the operating rule: no empty
  form is ever the first thing the user sees. Capture → one Reality Check →
  the Spheres pre-fill the Lab → a single Brief screen → Looks right / Not
  quite / I know something you don't. The 3a Lab stays as the layer behind
  "Not quite". Explore's six prompts are optional edit fields; the "0 of 6"
  counter is gone.
- **Phases.** 3b is the proxy, Reality Check, `prefill` and the Brief; 3c is
  Rounds and rulings; the Library surface moves to Phase 4.
- **Proxy.** Vercel, TypeScript, Node runtime, under `proxy/`. Two required
  environment variables: `ANTHROPIC_API_KEY` and `FORGE_PROXY_TOKEN`. Sonnet 5.5
  for Spheres, synthesis and research; Haiku 5.5 for expand, summarize, next
  step and criterion explanations. Structured outputs through the SDK's zod
  helper, so every answer is schema-valid before the app sees it. The lens
  content and house rules form one cached system block per lens.
- **Honesty rules live in code, not prompts.** `proxy/lib/enforce.ts` caps
  desk-research rungs at 2 (rung 1 with no source), turns source-less verdicts
  into cantTell, drops unknown source IDs, and allows one crossfire exchange per pair.
- **Research is stateless and resumable.** One model turn per HTTP call with
  web search and web fetch; the app loops while `status` is `paused`. Fetched
  pages return as sources. This keeps each call inside Vercel's 60-second limit.
- **Content stays single-sourced.** `proxy/lib/content.json` is generated from
  ForgeCore by `swift run forge-lens-export`; prompts and the Lab cannot drift.
- **Cost.** Every envelope carries `costUSD` from a price table in the proxy;
  the app will sum it against a monthly ceiling in Settings (next PR). The
  health endpoint returns the Reality Check estimate shown before running.
- **App side in this PR.** `ProxyAIClient` replaces the offline client whenever
  `PROXY_URL` and `PROXY_TOKEN` are set in `Local.xcconfig`, so Expand and
  Summarize become live end to end. The `prefill` action and `PrefillResult`
  contract are declared; the Reality Check flow and the Brief screen follow.

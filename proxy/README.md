# FORGE proxy

A small Vercel project that holds the Anthropic API key so none ships in the
app, validates every model answer against the typed contracts, enforces the
evidence rules server-side, and runs desk research for Reality Checks.

## Deploy (once)

1. Create a Vercel project from this repository with **Root Directory = `proxy`**
   (Framework Preset: Other). Or from a terminal:

   ```bash
   cd proxy && npm install && npx vercel
   ```

2. In the Vercel project, Settings → Environment Variables, add for Production
   (and Preview if you use it):

   | Name | Value |
   |---|---|
   | `ANTHROPIC_API_KEY` | your key from console.anthropic.com |
   | `FORGE_PROXY_TOKEN` | a long random string; generate with `openssl rand -hex 32` |

   Optional: `FORGE_RESEARCH_MODEL` (default `claude-haiku-5-5`),
   `FORGE_SPHERE_MODEL` (default `claude-sonnet-5-5`), `FORGE_FAST_MODEL`
   (default `claude-haiku-5-5`), `FORGE_MAX_SEARCHES` (5), `FORGE_MAX_FETCHES` (4),
   `FORGE_MAX_FETCH_TOKENS` (4000), `FORGE_REQUESTS_PER_MINUTE` (30).

3. Deploy to production:

   ```bash
   npx vercel --prod
   ```

4. Check it:

   ```bash
   curl -s https://YOUR-PROJECT.vercel.app/api/health -H "Authorization: Bearer YOUR_TOKEN"
   ```

   You want `"ok": true` and `"authorized": true`.

5. In the app, copy `Forge/Config/Local.xcconfig.example` to `Local.xcconfig`
   and set `PROXY_URL` and `PROXY_TOKEN`. The URL needs the `$()` trick because
   `//` starts a comment in xcconfig:

   ```
   PROXY_URL = https:/$()/YOUR-PROJECT.vercel.app
   PROXY_TOKEN = YOUR_TOKEN
   ```

   Rebuild. Settings → AI shows the proxy as configured.

## Endpoints

- `GET /api/health` — configuration and token check, plus the Reality Check cost estimate.
- `POST /api/action` — `{ action, context, options? }` → `{ payload, rationale, model, usage, costUSD }`.
  Actions: expand, summarize, explainCriterion, designExperiment, nextStep, plan, compare,
  pivot, pitch, runRound, realityCheck, prefill. Payload shapes are in `lib/schemas.ts`
  and mirrored in `Forge/Services/AI/AIContracts.swift`.
- `POST /api/research` — `{ idea, advantages?, constraints?, messages? }` → one research
  turn with web search and fetch; `status` is `done` or `paused`. When paused, call again
  with the returned `messages`. Fetched pages come back as `sources` for the Library.

## Rules enforced here, not just in prompts

- Desk research never exceeds evidence rung 2; a criterion with no source is capped at rung 1.
- A verdict that cites no known source becomes `cantTell`.
- Source IDs the app did not send are dropped.
- One crossfire exchange per pair of Spheres, never to oneself.

## Models and cost

Haiku 5.5 does the desk research (`/api/research`): reading pages is most of the
tokens and needs little judgment. It uses the basic web tools (`web_search_20250305`,
`web_fetch_20250910`); dynamic filtering is documented for Opus and Sonnet, and Sonnet
gets it if `FORGE_RESEARCH_MODEL` points there. Sonnet 5.5 runs the Spheres: the
prefill and every action with a verdict. Haiku 5.5 also runs expand, summarize, next
step and criterion explanations.

A Reality Check targets 10 to 20 cents:

- Web searches are $0.01 each and capped at 5 per check (`FORGE_MAX_SEARCHES`; a paused
  turn's continuations count against the same cap). This is the main research cost.
- Web fetches cost only the tokens they add: at most 4 pages, each cut to about 4,000
  tokens before the model reads it.
- The prefill on Sonnet is the rest, mostly its output.

The lens content and house rules are one cached system block per lens, so repeated
calls pay the cache-read rate. Every response carries `costUSD` from `lib/pricing.ts`
(Haiku's over-100K-token rate card included); the app sums it against the monthly
ceiling and shows the average of real runs once one exists. `/api/health` reports the
models and caps in use.

## Time limits

`vercel.json` gives `/api/action` 300 seconds, `/api/research` 120 and `/api/health` 10.
A prefill writes the whole Lab in one answer and can take a couple of minutes. Limits
above 60 seconds need Fluid Compute, which is on by default for Vercel projects created
since April 2025; if a deploy is rejected for `maxDuration`, turn it on under Settings →
Functions, or lower the values.

## When something fails

Every non-200 from the Claude API is logged with Anthropic's full error body and request
ID, under Vercel → the project → Logs, filtered to the function. The same message is
returned to the app in the error body. If the API rejects a structured-output schema
(400), the proxy logs why, then retries once with the schema in the prompt and validates
the answer itself; a successful retry carries the header `X-Forge-Mode: json-fallback`.

Check a schema against the documented limits without calling the API:

```bash
npm run schema -- prefill
```

## Content

`lib/content.json` is generated from the app's ForgeCore package, so prompts and the
Lab always agree:

```bash
cd ForgeCore && swift run forge-lens-export > ../proxy/lib/content.json
```

## Local development

```bash
npm install
npm run typecheck
npm test
```

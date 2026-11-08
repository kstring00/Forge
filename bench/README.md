# The bench

The engine's test suite (`docs/ENGINE.md` §6). Real ideas, a hand-written answer key for
each, the engine against two baselines, one report. No engine change ships without a run.

## What it measures

| # | Metric | How |
|---|---|---|
| 1 | Competitor recall | Of the key's true top 3, how many the system named (name, alias, or website) |
| 2 | Source truth | Share of claims backed by the page they cite. Must be 100% to ship. Bench v0 checks the cited page contains the competitor's name and every dollar figure; the verification gate replaces this with quoted passages. No page, not backed. |
| 3 | Price accuracy | A stated price within 15% of the key's real range |
| 4 | Riskiest-assumption match | Same / related / different, graded by a separate model with the key visible (1 / 0.5 / 0) |
| 5 | Step usefulness | One person, within a week, under $50, concrete; all four to pass |
| 6 | Cost and latency | Per run, from the proxy's and the API's own usage |

**The gate:** engine v2 ships only if it beats both baselines on 1, 2 and 4, and source
truth is 100%. The report says SHIP, HOLD or INCOMPLETE.

## The systems

- `engine`: the app's own path through your proxy. Research one turn per call, then the
  prefill, with a developer token.
- `baseline`: the idea pasted into a plain chat model with the question a person would ask.
  `baseline-web` lets it search. A second model only extracts what the answer said.
- `ideaproof`: IdeaProof's free check, run by hand. See `baselines/ideaproof/README.md`.

A refusal is recorded as a failed run, not retried on another model: the bench measures
the model it names.

## The ideas

`ideas/*.json`, one per idea, validated against `src/types.ts`. Target: **15** (nine of
yours, three from friends, three classics with known outcomes). Shipped now:

| Idea | Key |
|---|---|
| `classic-dropbox`, `classic-juicero`, `classic-quibi` | Drafted from public history; **prices unverified** |
| `person-hunch` | From `docs/PRICING.md` and the panel's first Brief; unverified |
| `person-rv-park-sites` | None yet |

A key is the truth the engine is graded against, so a person writes or checks every one:
open each competitor's pricing page, fix `priceLow` / `priceHigh`, then set
`"verified": true`. Copy `ideas/_template.json` for a new one, or pull your own ideas from
the app:

```bash
npm run import-vault -- ~/Downloads/Hunch-Export/vault.json
```

Unkeyed ideas are skipped unless you pass `--include-unkeyed` (useful to look at the
engine's output while you write the key).

## Running it

From this folder, once:

```bash
npm install
```

Then, with your proxy URL, a developer token from `FORGE_DEV_TOKENS` (or
`FORGE_PROXY_TOKEN`), and an Anthropic API key for the baseline and the judge:

```bash
PROXY_URL=https://your-proxy.vercel.app PROXY_TOKEN=... ANTHROPIC_API_KEY=... npm run bench -- --label v1-baseline --yes
```

Without `--yes` it prints the plan and spends nothing. Options: `--systems engine,baseline,baseline-web,ideaproof`,
`--ideas classic-dropbox,person-hunch`, `--rerun`. A label's saved outputs are reused, so
a stopped run picks up where it left off.

Models: the baseline and the judge default to `claude-opus-5-5`, the extractor to
`claude-sonnet-5-5`; override with `BENCH_BASELINE_MODEL`, `BENCH_JUDGE_MODEL`,
`BENCH_EXTRACT_MODEL`. The engine uses whatever the proxy is configured with.

Rough cost of a full run of 15 ideas: about $3 to $8 (engine, baseline and judge).

## Results

`results/<label>/report.md` and `summary.json` are committed with the PR they belong to.
`results/<label>/outputs` and `judge` are small and committed too; `raw/` (fetched pages)
stays local. Re-render a report without the network:

```bash
npm run report -- v1-baseline
```

Tests for the scoring (no network):

```bash
npm test
```

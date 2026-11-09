# 0042 — Cheaper checks, more generous plans

Recorded 2026-11-09. Branch `claude/modest-brahmagupta-stx4vb-cost`, one commit per part.

Goal: people get more checks and more for what they pay, without a check getting worse. Sources still trump everything: every claim in a Brief points at a real page.

## How a check ran before
1. **Research** (`/api/research`, Haiku, basic web search and fetch): up to 4 turns, up to 5 searches and 4 fetches, pages cut to 4,000 tokens. Notes plus sources. About $0.05–0.07, mostly searches at $0.01 each.
2. **Prefill** (`/api/action` "prefill", Sonnet): one structured call that wrote everything (the five panelists' verdicts and scores, the estimate, the Brief, the next step, the drafted asset, the What-ifs), reading every Library page (up to 6,000 characters each). About $0.10–0.14, mostly output.
3. **After a check:** a re-score after a logged conversation re-ran the whole prefill (about $0.12); a launch plan was a Sonnet call reading the whole Library (about $0.05).

## What changed
- **A. One shared research pass.** The research notes come back in fixed sections (competitors, prices, complaints, demand, other), one finding per line ending with its URL. The proxy turns them into a **research packet** with no extra model call: every finding carries its page; a line without a page is kept apart and never shown as a fact; what the research could not find is listed. The panel reads the packet; Library pages go by title only (still citable); the person's own evidence goes in full. Panelists never search; a panelist who needs something the packet lacks says so (`cantTell` with `evidenceNeeded`).
- **B. Model tiering.** `proxy/config/hunch.ts` names a model and effort per role: research and scoring on Haiku, the Brief on Opus 5.5, plans and the Tank on Sonnet. A check is now two calls: SCORE (the five panelists) on the scoring model, then BRIEF on the brief model, reading the packet and the scores. The proxy merges them into the `PrefillResult` the app already reads, so older apps keep working. Re-score is its own action: the panelists only. The app has no model picker.
- **C. Prompt caching.** Every panel call puts the stable parts first with cache breakpoints (house rules, lens, panel, Explore prompts; then the action's instruction and output format) and the idea last. Research continuation turns cache the earlier turns. Every call logs read, written and fresh tokens and whether it hit.
- **D. The packet is saved with the idea**, with its date. Launch plans, plan updates, re-scores and the Tank read it and never search; only a fresh re-check replaces it. Kept on the device, not the server: it is part of the idea like its sources (backed up, exported, offline), the app already sends it with each call, and the server needs no database. When checks move to the server (#22) the server counts checks; a forged packet could only buy a follow-up, which never searches and sits under fair use.
- **E. Check rules.** Only researching costs a check: the first look (1) and a fresh re-check (1). A launch plan (new or updated), a re-score and the Tank are included on every plan, under a quiet daily limit per idea (3 plans, 10 re-scores, 3 Tank runs) that shows a friendly line, never the paywall. Free users can make a launch plan on the idea they checked. Buttons say "1 check" or "Included". Paywall moments are unchanged.
- **F. Rollover.** Unused monthly checks carry into the next cycle, up to one month's allowance, and expire when that cycle ends. Spent in order: the free first check, carried-over, this month's, extra. Plan changes: an upgrade carries up to the old plan's allowance; a downgrade or a cancel to Free carries up to the new, smaller one; trial checks never carry; bought checks are never touched; a cycle nobody opened counts as unused. Counted in `CheckLedger` (ForgeCore), pure and Codable, so #22's server ledger can keep the same fields and rules.
- **G. Every number in one config.** `rules` in `proxy/config/hunch.ts`: checks per plan (1, 15, 60, unchanged), trial cap, top-up size, rollover, costs, fair use. Served by `/api/health`, loaded at launch, saved; `PlanRules` defaults are the same numbers, and a shared fixture keeps them equal. App Store Connect untouched.
- **H. Cost meter** in Settings → Developer (test builds): average per check by research, scoring and Brief; cache hit rate; average included follow-up.

## Expected cost (estimates until the bench runs)
| | Before | After, Brief on Opus 5.5 | After, Brief on Sonnet 5.5 |
|---|---|---|---|
| Research | ~$0.06 | ~$0.06 | ~$0.06 |
| Scoring | (in prefill) | ~$0.003 | ~$0.003 |
| Brief | ~$0.12 | ~$0.17 | ~$0.09 |
| **Per check** | **~$0.18** | **~$0.23** | **~$0.15** |
| Re-score | ~$0.12 | ~$0.003 | ~$0.003 |
| Launch plan | ~$0.05 | ~$0.04 | ~$0.04 |

With the Brief on the strongest model a check costs about the same or more; the savings are in everything after a check, which is what makes "included" affordable. Moving the Brief to Sonnet (one line in the config) makes the check itself cheaper too. The bench decides: `proxy/bench/` runs the five sample ideas on both.

Caching saves most when checks run within five minutes of each other (many users). At a handful of checks a day the stable prefix is mostly written, not read, which costs 25% more on those tokens; the log shows which.

# 0042 — Cheaper checks, more generous plans

Recorded 2026-11-09. Branch `claude/modest-brahmagupta-stx4vb-cost`, one commit per part.

Goal: people get more checks and more for what they pay, without a check getting worse. Sources still trump everything: every claim in a Brief points at a real page.

## How a check ran before
1. **Research** (`/api/research`, Haiku, basic web search and fetch): up to 4 turns, up to 5 searches and 4 fetches, pages cut to 4,000 tokens. Notes plus sources. About $0.05–0.07, mostly searches at $0.01 each.
2. **Prefill** (`/api/action` "prefill", Sonnet): one structured call that wrote everything (the five panelists' verdicts and scores, the estimate, the Brief, the next step, the drafted asset, the What-ifs), reading every Library page (up to 6,000 characters each). About $0.10–0.14, mostly output.
3. **After a check:** a re-score after a logged conversation re-ran the whole prefill (about $0.12); a launch plan was a Sonnet call reading the whole Library (about $0.05).

## What changed
- **A. One shared research pass.** The research notes come back in fixed sections (competitors, prices, complaints, demand, other), one finding per line ending with its URL. The proxy turns them into a **research packet** with no extra model call: every finding carries its page; a line without a page is kept apart and never shown as a fact; what the research could not find is listed. The panel reads the packet; Library pages go by title only (still citable); the person's own evidence goes in full. Panelists never search; a panelist who needs something the packet lacks says so (`cantTell` with `evidenceNeeded`).
- **B. Model tiering.** `proxy/config/hunch.ts` names a model and effort per role: research and scoring on Haiku 5.5; the Brief (with the next step and What-ifs), launch plans and the Tank on Sonnet 5.5, on every plan and every check, the first one included. A check is now two calls: SCORE (the five panelists) on the scoring model, then BRIEF on the brief model, reading the packet and the scores. The proxy merges them into the `PrefillResult` the app already reads, so older apps keep working. Re-score is its own action: the panelists only. The app has no model picker.
- **C. Prompt caching.** Every panel call puts the stable parts first with cache breakpoints (house rules, lens, panel, Explore prompts; then the action's instruction and output format) and the idea last. Research continuation turns cache the earlier turns. Every call logs read, written and fresh tokens and whether it hit.
- **D. The packet is saved with the idea**, with its date. Launch plans, plan updates, re-scores and the Tank read it and never search; only a fresh re-check replaces it. Kept on the device, not the server: it is part of the idea like its sources (backed up, exported, offline), the app already sends it with each call, and the server needs no database. When checks move to the server (#22) the server counts checks; a forged packet could only buy a follow-up, which never searches and sits under fair use.
- **E. Check rules.** Only researching costs a check: the first look (1) and a fresh re-check (1). A launch plan (new or updated), a re-score and the Tank are included on every plan, under a quiet daily limit per idea (3 plans, 10 re-scores, 3 Tank runs) that shows a friendly line, never the paywall. Free users can make a launch plan on the idea they checked. Buttons say "1 check" or "Included". Paywall moments are unchanged.
- **F. Rollover.** Unused monthly checks carry into the next cycle, up to one month's allowance, and expire when that cycle ends. Spent in order: the free first check, carried-over, this month's, extra. Plan changes: an upgrade carries up to the old plan's allowance; a downgrade or a cancel to Free carries up to the new, smaller one; trial checks never carry; bought checks are never touched; a cycle nobody opened counts as unused. Counted in `CheckLedger` (ForgeCore), pure and Codable, so #22's server ledger can keep the same fields and rules.
- **G. Every number in one config.** `rules` in `proxy/config/hunch.ts`: checks per plan (1, 15, 60, unchanged), trial cap, top-up size, rollover, costs, fair use. Served by `/api/health`, loaded at launch, saved; `PlanRules` defaults are the same numbers, and a shared fixture keeps them equal. App Store Connect untouched.
- **H. Cost meter** in Settings → Developer (test builds): average per check by research, scoring and Brief; cache hit rate; average included follow-up.

## Expected cost (estimates until the bench runs)
| | Before | After |
|---|---|---|
| Research (Haiku, web search) | ~$0.06 | ~$0.06 |
| Scoring (Haiku) | in the prefill | ~$0.003 |
| Brief, next step, What-ifs (Sonnet) | ~$0.12 (all in one call) | ~$0.09 |
| **Per check** | **~$0.18** | **~$0.15** (about 15% less) |
| Re-score | ~$0.12 | ~$0.003 |
| Launch plan, new or updated | ~$0.05 | ~$0.04 |

The check itself gets a little cheaper; everything after it gets much cheaper, which is what makes "included" affordable. `proxy/bench/` measures the real numbers on five sample ideas.

**Decided by the developer (Nov 9):** the Brief runs on Sonnet everywhere (no Opus); scoring stays on Haiku; research is unchanged. Rollover on plan changes, the fair-use limits (3 plans, 10 re-scores, 3 Tank runs per idea per day) and keeping the packet on the phone are approved as built. Check allowances per plan stay as they are until the bench gives real numbers.

Caching saves most when checks run within five minutes of each other (many users). At a handful of checks a day the stable prefix is mostly written, not read, which costs 25% more on those tokens; the log shows which.

## Follow-up decisions (Nov 9, evening)
- **The Library is on every plan**, with pinned facts when they are built: adding your own sources is your own work. `Plan.includes(.library)` is true on Free.
- **"Argue it out" is gone from Plus.** It was never built, and arguing with the panel is the Tank, which is included on every plan. Plus is now more checks (15, carried over) and Your patterns. The App Store descriptions in RELEASE.md are updated to match.
- **The Advocate comes with the Tank**, not the current check. Today's panel stays five (investor, customer, builder, strategist, skeptic); adding a sixth voice to every check would add a call while this decision is cutting costs. ENGINE.md §2 already places the Advocate in the Tank, in the Steward's seat.
- **Pro is leaning to 50 checks** (60 until the bench gives real cost per check). Open question: who Pro is for. The likeliest buyers are people who evaluate other people's ideas: coaches, consultants, accelerators.
- **Working name: Hunch.** Not committed yet; the name collides with dating apps.
- **Under the Hood** (See the Work, the Library, pinned facts, panelist weights, build-your-own panel, export) is the next feature after this PR merges.

## Decided ahead for Under the Hood (Nov 9, late)
Built on its own branch after this PR merges and then #30 merges, in that order.
- **No dollar figures in the App Store app, ever.** The cost meter and the AI cost cap stay in Settings → Developer, test builds only.
- **Pro may run panelists on Sonnet** with no extra checks; fair-use limits cap it. The Developer cost meter shows the extra cost per check so it can be watched in the beta.
- **Reddit is paste-only**, never fetched by the server. The Library offers a one-tap Paste button and a friendly line: "Reddit doesn't let apps read posts directly. Copy the post and paste it here." Other sites are fetched through the proxy, with paste as the fallback when a site blocks it.

## Bench results (Nov 9, five sample ideas, real API)
Measured with `proxy/bench/` on the developer's Mac; replaces the estimates above.

| Per check, average | Before | After |
|---|---|---|
| Research (Haiku, 5 web searches) | $0.103 | $0.108 |
| Scoring (Haiku) | in the prefill | $0.005 |
| Brief, next step, What-ifs (Sonnet) | $0.087 (whole prefill) | $0.070 |
| **Total** | **$0.191** | **$0.183** (4% less) |
| Follow-ups (launch plan, re-score) | $0.053–0.062 | $0.012–0.024 (about 70% less) |

- **Research is most of a check** (about $0.10: half the five searches, half reading their results). This decision did not touch it; it is the next cost lever (fewer searches, cheaper results to read), each change with its own bench run.
- **Sources held:** criteria citing a real page 25 → 26 of 30, pages cited 63 → 64, claims resting on the model's own notes 0 → 0, every competitor sourced in both.
- **Verdicts shifted:** before, 5 of 5 "Worth a fight"; after, 2 "Worth a fight" and 3 "Go ask people", some contradicting their own summary ("crowded" yet "Go ask people"). The split Brief had never been given the four verdicts' definitions. Fixed: BRIEF now carries them and the rule that the verdict judges the market the research can see, not whether customers have been interviewed (that goes in the riskiest assumption and the next step). To be confirmed by a rerun of "after".
- **Two failures fixed along the way:** re-scores cut off when Haiku's thinking used up 8,000 tokens (now 16,000, and a cut-off answer is retried as plain JSON instead of failing); the Brief's schema is refused by the structured-output compiler on every call, so it goes straight to plain JSON.

**Rerun after the verdict fix (Nov 9):** a check $0.191 → $0.168 (12% less; research varied $0.06–0.12 between runs), the panel stage $0.08–0.10 → $0.06–0.08, follow-ups $0.053–0.062 → $0.013–0.023 (about 75% less). Verdicts: 4 "Worth a fight", each naming its opening, and 1 "Go ask people" (night-shift meals: no one found selling into hospital break rooms). Sources: criteria citing a real page 25 → 27 of 30, pages cited 63 → 63, notes-only citations 0, every competitor sourced. **Open, not blocking:** Potential swings 15–25 points between runs on the same idea, before and after this change (charter 0 → 25, RV parks 21 → 8); to be steadied separately.

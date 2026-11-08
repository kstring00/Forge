# The Hunch Engine

## Engine spec v1: research, the Tank, the Deal, the test, the learning loop

Status: decided. Supersedes §6C (Spheres), §6D (Reality Check) and the pivots half of §6B in FORGE_BRIEF.md wherever they disagree. Everything the brief says about honesty (§0A, §6A) still binds this document.

The engine is the product. Capture, the Vault, the Workshop and the design are packaging around it. If the engine is not visibly better than pasting the same idea into a chatbot, nothing else matters.

---

## 0. What the engine must be, in one paragraph

A person says an idea out loud. Within minutes, independent voices with different jobs have each researched it against real sources, judged it alone, then argued it out in front of the person, who can step in. An Advocate pitches the strongest version; the others go in or out and bid counteroffers. The fight ends in one card, the Deal: the best version of the idea, every line traced to the voice and the source it came from. The Deal comes with a built experiment the person can run that week. Reality grades the result, and both the person and the voices carry a public record of how often they were right.

---

## 1. Principles the code enforces

1. **No source, no seat.** A claim with no verified source cannot enter the debate, the Deal, or the UI. The proxy drops it before any voice sees it.
2. **Judge alone, then argue.** Every voice forms its verdict blind. Nothing it says later can erase its first verdict; the record keeps both.
3. **Commit or stay quiet.** Every voice ends each stage with a stance, a confidence (0–100) and "what would change my mind." Hedges fail validation.
4. **Reality is the referee.** Only a real-world outcome (a logged interaction, a signup, a payment) moves evidence above rung 2. Agreeing with a voice never does. The engine's own scoreboard is graded by outcomes only.
5. **Capped, never endless.** One pitch, one in/out round, at most three counteroffers, one blend. More rounds make debates worse, not better.
6. **The person decides.** The engine never auto-advances an idea, never spends without a confirm, never picks between disagreeing sources on the person's behalf.
7. **Everything is replayable and exportable.** A Tank is a saved transcript with sources, not a vanishing animation.

---

## 2. The voices

Six seats. Five judge; one pitches. Each has a job, named frameworks, and a line it will not cross. Each has an orb (see §8 of the brief; the Advocate takes the sixth seat's gold palette with a rising-flame texture).

| Voice | Job | Frameworks | Will not do |
|---|---|---|---|
| **Advocate** (new; replaces the Steward's seat) | Pitch the strongest version of the person's idea. Reframe, find the sharpest customer, the best wedge. | Blue Ocean (Create/Raise), $100M Offers value equation, 12 Months to $1M | Invent evidence. Its pitch must cite the same Library as everyone else. Can say "the strongest version I can defend is narrower than what you wrote." |
| **Customer** | What real people said or did. | The Mom Test | Speak for people who are not in the Library. Must say "nobody has talked to me" when true. |
| **Investor** | Price, channel, repeatability, enterprise value. | $100M Leads, Built to Sell, Profit First | Back a product with no channel. |
| **Builder** | The smallest version, skills, weekend-shippable? | The Lean Startup, The E-Myth | Approve anything that depends on the person doing custom labor forever. |
| **Strategist** | Why anyone would switch; where the opening is. | Blue Ocean (Eliminate/Reduce), Good Strategy/Bad Strategy | Accept "I'd do it better" as differentiation. |
| **Skeptic** | The one belief that sinks it; vanity metrics; fake urgency. | Anti-delusion rules; riskiest-assumption | Say an idea is good because the person had it. |

The Steward's question survives as the person's own check on the Deal screen: *"Is this the right use of my life right now?"* with the user-written charter beneath it. No AI answers it.

**Voice rules (in every system prompt, and checked in code where possible):**
- Argue from your framework and only from Library sources. Cite source IDs. If none, say `cantTell` and name what would change your mind.
- Two sentences per verdict, one per reply. Plain words first, framework names second.
- Disagree when your framework disagrees. Never converge for politeness. Never echo a point another voice already made; add or stay quiet.
- No catchphrases, no persona. You are a perspective.
- Never the words "great idea."

---

## 3. The pipeline

```
capture → guard → RESEARCH → BLIND VERDICTS → THE TANK → THE DEAL → THE TEST → THE LOOP
                    (1)          (2)            (3)        (4)        (5)       (6)
```

### 3.1 Research (desk)

Input: idea text (≥ 8 words, names a problem or a person; otherwise blocked for free on device).

Output: a Library of `ai-found` Sources, each with URL, title, fetched date, full text (chunked for citations), and a `claims[]` list, every claim quoting the exact passage it rests on.

Collect, in order of value:
1. Current alternatives (3–8): name, URL, pricing with numbers, positioning, praise, complaints (one-star reviews, support forums), traction signals (review counts, hiring, price changes, funding), age.
2. Demand signals: complaint threads, "I wish" posts, job postings for the problem, search-interest proxies.
3. The gap map: what everyone offers, what everyone ignores, what customers complain about that nobody fixes, what everyone charges for that nobody values.
4. Fit: the person's Advantages and Constraints (from Settings), applied by the Advocate.

Budget: default 5 searches, 4 fetches, each page ≤ 4k tokens, research on the fast model. Re-checks reuse sources under 14 days old unless the person asks for fresh research.

### 3.2 Source verification (the gate)

Runs on the proxy before any voice sees anything. This is the layer that makes the engine trustworthy and most competitors do not have.

- **Reachability:** the URL must respond. Dead links are dropped.
- **Quote check:** every claim's quoted passage must appear in the fetched text (normalized, fuzzy ≥ 0.9). Claims that fail are dropped and counted in `dropped.unverifiedQuotes`.
- **Freshness:** sources carry `fetchedAt`; the UI shows the date next to any number.
- **Evidence rank** (stored on every Source, used everywhere evidence is weighed):
  1. `lived`: the person's own logged interactions, signups, payments (rungs 3–5)
  2. `published`: official pricing pages, docs, filings, first-party announcements
  3. `reviewed`: app store and marketplace reviews, support forums
  4. `discussed`: Reddit, forums, social posts
  5. `opinion`: any model's own reasoning. Never counts as evidence; may only be shown as labeled opinion.
- **Conflicts:** when two sources disagree on a fact (two prices for the same product), both are kept and shown side by side with dates. The engine never silently picks one.
- **Dedup:** same URL or same claim text → one source.

Output: a verified Library, plus a `dropped` report the Brief shows in one line ("3 findings left out because their sources could not be verified").

### 3.3 Blind verdicts

Five judging voices run **in parallel, independently**, with the same verified Library and the person's about-you note (§7). None sees another's output. Each returns:

```
{ sphere, stance: onTrack | offTrack | cantTell, confidence: 0–100,
  criterionKey, reason (≤ 2 sentences), sourceIDs[≥1 unless cantTell],
  wouldChangeMyMind (1 sentence) }
```

Validation drops a verdict that cites unknown sources; a stance with no sources is forced to `cantTell`. Also produced here, by the Advocate alone: **the Pitch** (§3.4 step 1), so it is ready the moment the Tank opens.

Implementation note: these are separate model calls sharing one cached research prefix. Do not collapse the five judges into one call; a single call cannot be blind to itself, and independence is the point.

### 3.4 The Tank

The fight, in a fixed shape. Three stages, each one model turn per voice, all grounded in the Library. The person watches it stream and can step in.

**1. The Pitch.** The Advocate pitches the strongest defensible version of the idea in ≤ 120 words: who exactly, what exactly, why now, the one number from the Library that makes it credible, and what it deliberately leaves out. If the strongest version is narrower than what the person wrote, it says so.

**2. In or out.** Each judge, having seen the Pitch and (now) the other blind verdicts, declares:

```
{ sphere, decision: in | out | inIf,
  terms (if in/inIf: the one thing it needs to see; ≤ 1 sentence),
  reason (≤ 2 sentences, may reference another voice by name),
  sourceIDs[], confidence }
```

`in` lights the orb; `out` darkens it; `inIf` pulses. A voice may change from its blind stance, but the UI shows the change ("Investor moved from off track to in, after the Pitch narrowed the buyer").

**3. Counteroffers.** Any voice that is `out` or `inIf` may table one counteroffer, a concrete variant that fixes its objection (these are the pivots): zoom in, zoom out, change customer, change channel, change model, change delivery. ≤ 3 total; the proxy keeps the three with the most support (other voices may second a counteroffer in one line). Each: `{ whatIf, pivotType, fixes: criterionKey, why, firstTest, sourceIDs[] }`.

**The person can step in** at any stage: a typed or spoken point enters the transcript as a `lived`-rank statement if it describes something they did or saw, or as `opinion` if it is a belief. Every voice must address it in its next turn (≤ 1 sentence each). One interjection per stage keeps cost bounded.

**Crossfire** happens only where two voices conflict (`in` vs `out`), one exchange per pair, as today.

Transcript, every turn, every source ID, every interjection, is saved as a `Round`.

### 3.5 The Deal

The blend. One structured call (strong model) over the whole transcript produces **the best version of the idea** the panel can defend:

```
Deal {
  verdict: goBuildIt | worthAFight | alreadySolved | goAskPeople,
  oneLiner,                        // the idea, sharpest form, ≤ 20 words
  who, what, why, wedge,           // each ≤ 1 sentence, each with { fromSphere, sourceIDs[] }
  whatWeDropped[],                 // parts of the original the Deal leaves out, and why
  riskiestAssumption,
  confidence: { potential 0–100, confidence 0–100 },   // confidence capped at rung-2 math until lived evidence exists
  theTest: Experiment,             // hypothesis, test, metric, cost, timebox, decision rule
  dissent[]                        // voices still out, in their words
}
```

Every line of the Deal carries attribution chips: the voice's orb and a source chip. Tapping a chip opens the passage.

The Deal screen ends with the person's own two checks, with no AI involved:
- **The Steward's question:** "Is this the right use of your life right now?" with the charter under it. Yes / Not now.
- **Take the deal:** choose the Deal, the original, or one counteroffer. The choice becomes the project and the Decision Journal entry: what you believed, what you expect, by when.

### 3.6 The Test (launch kit)

The Deal does not end in advice. It ends in an experiment the app has already built, chosen by the riskiest assumption:

| Riskiest assumption | Built artifact |
|---|---|
| Nobody has this problem | Five past-behavior interview questions, fillable (already built) |
| They won't give time | A one-tap **test page** at `hunch.page/<slug>`: headline from the Deal's one-liner, three bullets, a waitlist form. Signups post back to the proxy and land in the idea as `lived` evidence, rung 3, automatically. |
| They won't pay | The same page with a price and a "reserve" button (no charge taken; a reservation is rung 4 intent, labeled as such) |
| Can't reach them | A 20-message outreach script plus a tracker (sent / replied / met) |
| Can't build it | A clickable mockup brief for the smallest version |

Test pages are static, generated once, hosted on the proxy's domain, carry a clear "built with Hunch" footer, and are deleted when the idea is archived. The person reviews and edits copy before anything is published; nothing goes live from a tap in the Tank.

### 3.7 The Loop

Reality reports back. Three sources of truth, all free, all `lived`:
- Logged conversations and interviews (built).
- Test-page events (signups, reservations) via the proxy.
- "What happened?" when a step is done, paused or launched.

On every new `lived` source, the engine re-runs **only** the voices whose criteria it touches (partial re-verdict), diffs the result ("Customer moved from can't tell to in after three interviews"), and updates the Deal's confidence. A full Tank re-runs only on request.

**The scoreboard.** Each outcome is matched against every voice's recorded stances and the person's rulings:
- Voice record per person: "The Skeptic has been right about your ideas 4 of 5 times."
- Person record: "You've overruled the Strategist 3 times; it was right twice."
- Criteria the person habitually over- or under-scores.
After 5 graded outcomes, voice weights adjust ±10% in the Deal blend, shown openly. Never before, and never silently.

---

## 4. Models

**Why mix.** Debates among different models beat debates among copies of one model (diversity of thought: three distinct mid-size models reached 91% on a reasoning benchmark vs. 82% for three copies of one strong model). Different models err differently, so their disagreements carry information.

**The rule:** every voice has a `provider` + `model` field resolved on the proxy. The app never holds provider keys.

- **Default "Best panel":** Claude for the Advocate, the Deal and research synthesis; a second provider (start with one: OpenAI or Google) for at least two judges. Expand only once the benchmark (§6) shows a gain.
- **Pro:** per-voice model picker, with cost shown per voice before running.
- **Disclosure:** the consent screen and Settings name every provider in use (Apple guideline 5.1.2(i)); a run that would use a new provider asks again once.
- **Budget:** Max-plan API credits cover Claude only; other providers bill the business directly. The proxy tracks cost per provider per run.
- **Fallbacks:** if a provider fails, the voice falls back to Claude and the transcript says so.

---

## 5. Cost and caps

Target per full Tank (research + 5 blind verdicts + Advocate + in/out + ≤ 3 counteroffers + Deal), with caching and the fast model on research: **$0.35–0.60**. Basic check (research + blind verdicts + Deal, no Tank) stays at **≤ $0.20**.

- Free and basic: research, blind verdicts, Deal. Plus and Pro: the Tank, step-ins, counteroffers, test pages, model choice (Pro).
- **In checks** (`docs/PRICING.md`): a basic check costs **1 check**; a full Tank costs **2**. Both come off the person's allowance, the confirm sheet says which before anything runs, and a failed or stopped run counts nothing.
- Hard caps on the proxy: per-user checks per period (from the ledger), a global daily ceiling that pauses politely, stop button honored at every stage boundary, failed or stopped runs never count.
- Every stage logs tokens and dollars per provider; Settings → Spend shows cost by stage so the expensive layer is always visible.

---

## 6. The benchmark (build this first)

Before any new engine code ships, build `bench/`: 15 real ideas (the person's, friends', three classic examples with known outcomes), each with a hand-written answer key: the true top 3 competitors, real price ranges, the real riskiest assumption.

Score every engine version on:
1. **Competitor recall:** of the true top 3, how many found (0–3).
2. **Source truth:** % of claims whose quoted passage really appears on the page (must be 100%; anything less is a release blocker).
3. **Price accuracy:** within 15% of real.
4. **Riskiest-assumption match:** does the Deal name the same one as the key (judged by a separate model with the key visible)?
5. **Step usefulness:** is theTest runnable by one person in a week with under $50? (rubric)
6. **Cost and latency** per run.

Compare against two baselines: the same idea pasted into a plain chat model, and IdeaProof's free check. **Ship engine v2 only if it beats both baselines on 1, 2 and 4.** Re-run the bench on every engine PR; it is the engine's test suite.

---

## 7. Data the engine carries about the person

- **Advantages** (skills, audiences, relationships, assets) and **Constraints** ("no service businesses"), user-written, fed to the Advocate and the Deal.
- **Charter** (the Steward's question), user-written, shown only to the person.
- **About-you note** (≤ 80 words, generated from the scoreboard and Your patterns), included in every voice prompt, readable, editable and resettable in Settings, labeled: "Hunch remembers your track record and shares it with the panel. The AI itself doesn't change."

---

## 8. Screens (design canvas: "The Tank", "The Deal"; existing: Hear the panel, Credit moments)

**The Tank (live).**
- Top: the six orbs in the council arc; the Advocate at center-top, gold.
- Stage ribbon: Pitch → In or out → Counteroffers → Deal, with the current stage lit.
- Center: the transcript streaming one turn at a time. Each turn is a card: orb, name, stance word, two sentences, source chips. In/out turns animate the orb (lit / dark / pulsing). Conflicting pairs get the ember hairline.
- Bottom: **"Step in"** (mic + text). One interjection per stage; the field closes while voices respond.
- Always: Stop (saves what ran; nothing half-finished is shown), and a small cost meter for Plus/Pro ("stage 2 of 4 · $0.21 so far").
- Reduce Motion: no streaming animation; cards appear complete.

**The Deal.**
- Hero: the verdict word and its one-liner, then the Deal's one-liner in display serif.
- Four attributed lines (who, what, why, wedge), each with an orb chip and a source chip.
- "What we dropped" as a muted list.
- Potential / Confidence rings and the Est. return range with its basis.
- The Test card with its built artifact ("Your test page is drafted · Review and publish").
- Dissent, in the voices' own words, never hidden.
- The Steward's question with the charter. Then **Take the deal** with three options (Deal / original / a counteroffer).

**Share card.** One tap renders a 1080×1920 image: the orbs in their final states, the verdict, the one-liner, "Tested in Hunch." No personal data beyond the idea's one-liner; the person previews before sharing.

---

## 9. Build order (engine track; each its own PR with bench results in the description)

1. **Bench v0** (§6): ideas, answer keys, scoring script, two baselines, a report. No engine changes.
2. **Source verification gate** (§3.2): reachability, quote check, rank, conflicts, dropped report. Bench metric 2 must hit 100%.
3. **Blind verdicts with commitment** (§3.3): confidence + wouldChangeMyMind, parallel calls on a cached prefix; Advocate seat replaces Steward; the Pitch.
4. **The Deal** (§3.5): structured blend with attribution chips; Take the deal → project + Journal; the Steward's question.
5. **The Tank** (§3.4): in/out, counteroffers, step-in, streaming UI, Stop at stage boundaries. Plus-gated.
6. **Launch kit v1** (§3.6): test pages with signup webhook → `lived` evidence.
7. **The Loop v2** (§3.7): partial re-verdicts on new evidence, diffs, scoreboard, weight adjustment after 5 outcomes.
8. **Second provider** (§4) behind the bench: ship only on a measured gain.
9. **Share card.**

Each PR: bench numbers before/after, cost per run, and a one-paragraph decision record.

---

## 10. What would make this fail, and the guard for each

| Failure | Guard |
|---|---|
| Research no better than a chatbot | The bench, with baselines, as a release gate |
| Fabricated sources | Quote check on the proxy; 100% source truth or no ship |
| Voices caving to consensus | Blind verdicts recorded first; changes shown as moves |
| Echoing | "Add or stay quiet" rule; dedup of repeated points in validation |
| Debate degrading with rounds | Hard caps: one pitch, one in/out, ≤ 3 counteroffers, one blend |
| Persuasion rewarded over truth | Scoreboard graded by outcomes only; weights move only after 5 graded outcomes |
| Theater without a decision | Every Tank ends in Take the deal and a built Test |
| Novelty wears off | The Loop, the scoreboard, Your patterns: value that compounds |
| Cost creep | Per-stage cost logging, caps, Plus-gating of the Tank |
| Solo founder overreach | This build order, one PR at a time, bench on every step |

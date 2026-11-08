# FORGE — Idea-to-Execution App
## Build Brief for Claude Code

You are a senior iOS architect, product designer, and full-stack engineer. Build **FORGE**, a premium iPhone app that helps one person capture ideas, pressure-test them against established business and personal frameworks, understand *why* an idea falls short, and turn the worthwhile ones into projects.

> **"Capture the idea. Test its potential. Make it real."**

This brief is the source of truth. Read all of it before writing code. Where it is silent, make the choice that keeps the app small, calm, and honest.

---

## 0. The one-paragraph version

The user has no shortage of ideas. The problem is that ideas pile up in notes and chats, get worked on in bursts, and never get evaluated with any rigor. FORGE fixes this with a five-stage pipeline (**Capture → Explore → Evaluate → Build → Launch**), a Vault that holds every idea, an Evaluation Lab that scores ideas through *named, established frameworks* with a built-in teaching layer, and a Workshop that turns a chosen idea into milestones and a single next step. AI is a skeptical collaborator inside each idea, never a generic chatbot tab.

---

## 0A. The operating rule (v4): the user talks, the Spheres work

**Everything below is subordinate to this section.** Earlier drafts made the user fill in Explore prompts, score six criteria by hand, and attach evidence row by row before anything useful happened. That is homework. The frameworks, ladders, and rubrics stay exactly as rigorous; what changes is *who does the first pass*. The Spheres do. The user reviews, corrects, and decides.

### The path, end to end

1. **Capture.** One sentence or a voice memo. Nothing else is asked. The idea lands in the Vault with a sky header and a single button: **Reality Check**.
2. **Reality Check (one tap, one confirm).** Tapping the button sends nothing. First a free on-device guard: an idea under about eight words, or one that names neither a problem nor a person, is blocked with one line ("Add a sentence about the problem and who has it, so the panel has something to look into") and no proxy call. Then a confirm sheet, the same for every action that calls the proxy (Reality Check, Expand, Summarize, re-score): what will happen, how long it takes, that the idea text goes to an AI model through the user's proxy, *Send* and *Cancel*. Only Send runs it. While it runs, the working card has *Stop*: remaining proxy calls are cancelled and nothing half-finished is kept. Then it runs. In the background, through the proxy: desk research (§6D) — competitors, pricing, complaints, demand signals, job postings — saved as `ai-found` Sources. Then the five Spheres each read the Library and **pre-fill the whole Lab**: a proposed answer to every Explore prompt, a proposed score and evidence rung for every criterion with the Source it leans on, a proposed Projection range, a proposed riskiest assumption, and a proposed next move. Progress is visible as the orbs light up one at a time. Typical wall time: one to three minutes. The user can leave and come back.
3. **The Brief (one screen).** When the check finishes, the idea opens on a single screen, led by the orbs:
   - **The verdict row** — *Go build it* / *Worth a fight* / *Already solved* / *Go ask people*, each with its one-line explanation and one sentence from the panel.
   - **The panel** — six orbs in a row (the sixth, Steward, dim until Phase 5). Tap an orb to read only that voice. Where two Spheres disagree, a thin line connects them; tap it for the crossfire.
   - **What we found** — three to five lines, each a claim with its Source chip (stripes = AI-found).
   - **Rings** — Potential and Confidence as proposed, drawn in the AI-found stripe until the user touches them.
   - **The one thing nobody can tell from a desk** — the riskiest assumption, and the single human action that tests it, already drafted (five Mom-Test questions, or a 20-message outreach script, or a landing page's copy).
   - **Three buttons:** *Looks right* · *Not quite* · *I know something you don't*.
4. **Review by exception.** *Looks right* accepts the panel's pass as-is; everything stays visibly AI-found and Confidence stays low, honestly. *Not quite* opens the criteria list; the user taps the row that is wrong and picks a different rubric anchor — one tap per correction, the AI's version shown struck through beside it. *I know something you don't* opens voice or text; what the user says is saved as a `user-verified` Source, and the affected Spheres re-score that criterion only. On the panel's verdicts, **Agree is the default**: a voice the user leaves untouched counts as agreed when they move on; only Disagree and Find out need a tap, and the tally reads "2 disagreements · 1 to find out". The full Lab — definitions, rubrics, ladder, playbook, history — is all still there, one tap deeper, for whoever wants it. It is never required.
5. **The task.** The next move becomes the Workshop's one next step with the drafted assets attached. The user goes and does it in the world.
6. **The return.** "What happened?" — one line, or a voice memo, when a conversation is logged or a step is done. The user's answer is a `user-verified` Source attached to the criterion the step was testing, at the rung what the person did earns: 3 gave time, 4 gave money, 5 came back (inferred from the words, confirmed by the user; a logged conversation is never below 3). User-verified evidence is not bound by the desk cap, so the ladder moves, Confidence moves (and can pass 2 here alone), the Journal records expected vs. actual, and the Spheres re-run on the changed criteria only. If the next move is now "build," the Workshop takes over.

### Rules this adds

- **Explore is no longer a stage the user fills in.** The six prompts become the structure of the Spheres' pre-fill and remain available as optional edit fields. "0 of 6" never appears anywhere.
- **No empty form is ever the first thing the user sees.** If the Reality Check hasn't run, the idea shows the sky, the original text, and the Reality Check button. Nothing else.
- **Pre-filled is not verified.** Everything the Spheres write is `ai-found` and drawn in stripes. Confidence cannot exceed what desk research supports (rung 2) until the user brings something back from the world. The honesty rules in §6A are unchanged; this section changes effort, not evidence.
- **Three taps to a task.** Reality Check → Looks right → Start. If the user does nothing else, that still yields a real next action in the world with drafted assets.
- **Correction is one tap.** Any proposed score, rung, or answer can be overridden by choosing a different anchor; the user never types to disagree.
- **Re-runs are partial.** New information re-scores only the criteria it touches; the user is never asked to re-review the whole idea.
- **Cost is tracked, not shown.** No price appears anywhere in the UI until credits (§11, Phase 8). Settings → Spend holds the numbers: checks this month, what they cost, the average, and all AI spend against the monthly ceiling. The confirm sheet is the moment of consent; the ceiling is the guard.

### What this changes in the build

- The Reality Check and the Library research actions move from Phase 4 into **Phase 3b**, ahead of the hand-scoring UI's polish. The Lab screens built in 3a stay as the "one tap deeper" layer.
- The Brief screen (§0A step 3) replaces the idea detail's default state once a check has run. The 3a idea detail becomes the expanded view behind "Not quite."
- Sphere pre-fill is a new AI action, `prefill`, that returns one typed JSON object covering explorations, criteria, projection, riskiest assumption, and next move, each field carrying `sourceIDs`.

---

## 1. Non-negotiable principles

1. **Capture in seconds.** Text, voice, speech-to-text, paste. No required fields beyond the raw thought.
2. **Explore before judging — but the Spheres do the exploring.** The app never scores an idea the moment it is captured, and it never hands the user an empty form. Research first, then a proposal, then the user's review (§0A).
3. **Different ideas, different lenses.** A business idea, a personal-growth goal, and a creative experiment are evaluated with different frameworks and are never ranked against each other on one scale.
4. **Teach, don't just score.** Every criterion carries a plain-English definition, a "what counts as evidence" ladder, and a "how to go find it" playbook. The user should finish an evaluation understanding the framework, not just holding a number.
5. **Honest about evidence.** Two separate indicators on every evaluation: **Potential** (the user's structured self-assessment) and **Confidence** (how much of that assessment is backed by real evidence vs. enthusiasm). Enthusiasm is never silently counted as evidence.
6. **Action, not analysis theater.** Every evaluation ends with a recommendation and a concrete next experiment or step.
7. **Progress without pressure.** No streaks, no guilt, no gamification, no artificial urgency. Paused and abandoned projects are history, not failure.
8. **The user owns the data.** AI never silently edits user content. Original idea text is immutable. AI-generated changes require explicit confirmation.

---

## 2. Three stages (v4.2)

Every idea is on one of three stages, and the app is laid out as **Home · Idea · Formation · Reality**, one tab per stage after Home. Stages are flexible, not gated; an idea can move back, or sit.

| Stage | What it holds | What happens there |
|---|---|---|
| **Idea** | Captured, not yet checked. The Vault. | Capture (text, voice, paste); the original text is kept forever. One button: send it to the panel. |
| **Formation** | Checked. | The panel weighs in and the user rules: the Brief, Hear the panel, the Lab one tap deeper, pivots. |
| **Reality** | Out in the world, being tested. | Today's Workshop: the one next step, logging what happened, launch, and the Journal. |

The finer stored stages from earlier briefs map onto these and are not migrated: `capture` and `explore` → Idea; `evaluate` → Formation; `build` and `launch` → Reality. Archived ideas sit on no stage. Moving an idea by hand sets the entry stage of the new track (`capture`, `evaluate`, `build`).

**The next-step card** is the same wherever it appears (Home, the Formation idea page, the Reality project page): the step in 17 pt sans, never display serif; one 13 pt muted caveat line; progress segments ("1 of 5"); the due date; *Questions*, which opens the drafted asset; and *Log a conversation*, which records one and advances the count. Logging never closes the step; the user marks it done.

---

## 3. The Vault

Central collection of all ideas. Card-based, visual, searchable. Not a spreadsheet.

**Each idea stores:** title, original text (immutable), AI summary (optional, confirmed), lens/category, created/updated dates, pipeline stage, latest evaluation (Potential + Confidence), tags, notes, attachments, linked project, archived flag.

**Vault actions:** instant capture (floating button, always reachable), browse, search, filter by lens/stage/tag, sort by recent/updated/Potential/Confidence, open, compare two ideas (same lens only), archive (never hard-delete from the UI without confirmation), convert to project.

**Quick triage on every card:** a tiny "Opportunity Filter" chip the user can fill in 60 seconds (see §4.1) so the Vault can show what has been screened and what hasn't.

---

## 4. The Evaluation Lab (core differentiator)

The Lab is not a chatbot inventing scores. It is a set of **Lenses**. A Lens is a *mindset* — a way of looking at an idea — built from named, established frameworks. Each Lens has five or six criteria. Each criterion ships with four things:

1. **Definition** — what this criterion actually means, in plain English, with the framework it comes from named.
2. **Rubric** — what a 1, 3, and 5 look like, anchored to *evidence*, not feeling.
3. **Evidence ladder** — the ranked kinds of proof that count for this criterion.
4. **How to find it** — a short playbook of concrete places and methods to get that evidence this week.

Scoring: each criterion 1–5, equally weighted in MVP, normalized to 0–100 → **Potential**. Separately, each criterion records an evidence level (0–5 from its ladder); the average, normalized to 0–100 → **Confidence**. Previous evaluation versions are preserved. The user can re-evaluate at any time.

The Lab must also produce, for every evaluation:
- **Where it falls short** — the lowest-scoring criteria, in words, with what would have to be true to raise them.
- **Riskiest assumption** — the single belief that, if wrong, kills the idea (Lean Startup).
- **Recommended next move** — one of: *Explore further / Test the riskiest assumption / Build a small prototype / Start building / Revisit later / Archive*. Advisory, never automatic.
- **Experiment card** (when the move is "test"): Hypothesis · Test · Metric · Cost · Timebox · Decision rule.

### 4.0 Projection / Impact card

Every evaluated idea shows one card under the rings. Which card depends on the lens:

- **Business lens → Projection.** Three user-entered figures (price per unit, units in year one, derived recurring per month), each editable. Beneath them a bar splits *verified* (customers actually paying, solid fill) from *assumed* (striped). All figures are drawn as assumptions until a real payment is attached as Evidence at rung 4+; then that slice goes solid. The card never shows a projection the user did not type; the AI may suggest a range, labeled as an estimate, and the user accepts or edits it.
- **Personal Growth or Creative lens → Impact.** No dollar figures anywhere on the screen. The card holds: who this helps (a person, a group, or the user), what changes for them, and how the user would know (an observable signal, not a feeling). The same solid/striped bar shows what has been observed vs. hoped for.

The card is advisory. It feeds nothing into Potential or Confidence directly; it exists so the user sees the gap between the story and the receipts.

### 4.1 Opportunity Filter (60-second triage, any lens)

Ten yes/no/unsure questions shown before a full evaluation. Not scored to 100; just surfaces red flags.

- Does it use an advantage I already have?
- Can I actually reach the people it's for?
- Is the problem real, or did I invent it?
- Can I test demand in under two weeks?
- Could it produce income?
- Could that income recur?
- Does it create an asset that outlives the work?
- Does it teach me something I want to learn?
- Does it strengthen my reputation?
- Is this better than what I'd otherwise be working on?

Three or more "no" answers → the app suggests "Explore further" or "Revisit later" before investing in a full evaluation. This is the shiny-object guard.

### 4.2 Lens A — Business (frameworks: The Mom Test, The Lean Startup, $100M Offers, $100M Leads, Blue Ocean Strategy, Good Strategy/Bad Strategy, 12 Months to $1 Million)

**A1. Problem reality** *(Mom Test)*
Who has this problem, how often, and how painful or expensive is it? Measured by what people *do*, not what they say.
- Rubric: 1 = I assume people have it. 3 = People have described the problem to me unprompted, or already pay for a workaround. 5 = Multiple specific people have shown me their current workaround, what it costs them, and what they've already tried.
- Evidence ladder: assumption → anecdotes from me → one person described it unprompted → several people, with specifics → people currently spending money/time on a workaround.
- How to find it: have five conversations about their *past behavior* (never "would you use this?"); read complaint threads in communities where these people gather; look at what they currently pay for.

**A2. Demand evidence — "commercial traction"** *(Mom Test, Lean Startup)*
The single most misunderstood criterion, so the app explains it directly:

> Commercial traction is proof that people will give up something they value — time, attention, or money — to get this solved. Compliments are not traction. "That's a great idea" is worth zero.

- **Evidence ladder (show this as a visible ladder in the UI):**
  - 0 — I think it's good.
  - 1 — People said it's a good idea. (Worthless for scoring; the app says so.)
  - 2 — People described the problem without being led, or already pay for a workaround.
  - 3 — People gave *time*: an interview, a waitlist signup, a demo request, a reply to cold outreach.
  - 4 — People gave *money*: preorder, deposit, paid pilot, signed letter of intent.
  - 5 — People came *back*: renewed, reordered, referred someone, used it without being reminded.
- Rubric: score = the highest rung reached with at least three independent people.
- How to find it: competitors already charging money (their pricing pages and reviews are proof demand exists); search volume on the problem's keywords; complaint threads on Reddit, Facebook groups, and industry forums; job postings for roles that handle this problem (companies hiring = companies spending); a landing page with a waitlist and $50 of ads; a fake-door test (ethical, disclosed); a concierge/manual version sold to one customer.

**A3. Differentiation** *(Blue Ocean — Four Actions: Eliminate / Reduce / Raise / Create)*
Why would someone pick this over what they use now? The app prompts the user to list current alternatives (including "do nothing" and "spreadsheet") and fill a mini ERRC grid.
- Rubric: 1 = Same as alternatives but I'd do it better. 3 = One clear factor I'd raise or create that alternatives ignore. 5 = A different value curve — I eliminate things competitors assume are required and create something they don't offer, and target buyers have told me that factor matters.
- How to find it: map three competitors' pricing, features, and one-star reviews; identify what customers complain about that nobody fixes; identify what everyone offers that customers don't care about.

**A4. Offer strength** *($100M Offers — value equation)*
Value = (Dream outcome × Perceived likelihood) ÷ (Time delay × Effort). The app asks four questions and the user rates the result.
- Rubric: 1 = Vague outcome, slow, effortful. 3 = Clear outcome, moderate wait, some effort. 5 = Specific outcome the buyer already wants, fast, nearly effortless, with a believable reason it works.
- How to find it: ask prospects what outcome they'd pay for in their own words; measure how long alternatives take; count the steps a buyer has to take.

**A5. Distribution & economics** *($100M Leads, Lean Startup, Profit First)*
How do customers discover this, and does the money work? A product nobody finds is not a business.
- Rubric: 1 = "They'll find it." 3 = One channel I can access today (existing clients, a community, outreach) and plausible pricing above cost. 5 = A named channel with a tested conversion rate, pricing validated by a real payment, and a path to recurring revenue.
- How to find it: list where these buyers already are; run 20 cold outreaches and record replies; estimate CAC vs. first-year revenue per customer; check whether revenue can repeat (subscription, retainer, reorder).

**A6. Feasibility & founder fit** *(Good Strategy/Bad Strategy — diagnosis, guiding policy, coherent action; The E-Myth)*
Can I realistically build, launch, and maintain the first useful version with my skills, time, and money — and does this use an existing advantage?
- Rubric: 1 = Needs skills/capital I don't have and can't get soon. 3 = Buildable in weeks with current skills and tools. 5 = Uses an existing advantage (skill, audience, relationships), buildable in days, and doesn't depend on me doing custom labor forever.
- How to find it: write the smallest usable version in one paragraph; list what must be learned; estimate hours honestly; ask "what breaks if I stop working on it?"

### 4.3 Lens B — Personal Growth (frameworks: Atomic Habits, values alignment, Deep Work)

B1. **Identity & values alignment** — Does this match who I'm becoming, not just what sounds impressive?
B2. **Skill compounding** — Will the skill or habit built here keep paying off in other areas?
B3. **Sustainability** — Can I realistically keep this up alongside work, faith, family, rest? What's the smallest version I'd never skip?
B4. **Life & relationship impact** — Does it improve my life or the lives of people around me?
B5. **Intrinsic motivation** — Would I do this if nobody ever knew?

Each with rubric anchors and a "how to tell" note (e.g., for B3: "run it for two weeks at the smallest size before committing"). Evidence here is behavioral: did I actually do the small version?

### 4.4 Lens C — Creative Experiment

C1. Genuine excitement · C2. Originality / exploration · C3. Learning potential · C4. Feasibility of a small prototype · C5. Enjoyment of the process itself.

A creative idea can score 90 with zero commercial potential. That is intentional. Confidence here = "have I made the smallest prototype yet?"

### 4.5 Lens rules

- Comparisons only happen within one lens.
- An idea can be evaluated under more than one lens (a creative project might later be evaluated as a business).
- Lens content (definitions, rubrics, ladders, playbooks) lives in a single structured content file so it can be edited without touching UI code.
- The AI can *propose* scores with reasoning, but proposed scores are shown as suggestions in a separate color until the user accepts each one.

---

## 5. The Workshop

Where a chosen idea becomes a project. Not Jira, Linear, or Notion — a personal execution space.

**Project fields:** name, description, desired outcome (what "launched" means), stage, milestones, tasks, notes, decisions log, resources/links, activity history, **next step** (exactly one, always visible).

**Rules:**
- The Workshop always answers "what should I work on next?" with one concrete action.
- Milestones break into tasks; AI can suggest breakdowns; the user edits and confirms.
- Decisions, direction changes, obstacles, and lessons are logged with dates.
- Pausing or archiving a project is a normal state with no negative framing.
- A project keeps its link to the originating idea and evaluation so the user can see what they believed at the start.

### Decision Journal

Whenever the user commits to an idea (converts it to a project), sets it aside, or rules on a Reality Check or Round, the app records a **Decision**: what they decided, what they believed at the time, why, and what result they expected by when. When the project reaches a milestone, pauses, launches, or is archived, the app asks one question — "What actually happened?" — and stores the outcome next to the prediction.

**Closing the loop.** When the user records what happened on an idea, the app lists the rulings it might settle (disagreements and find-outs first) and asks, per ruling: the Sphere was right, you were right, or not settled. The outcome is stored on the Ruling and read back as one line: "You disagreed with the Strategist. It was right."

**Your patterns** (a screen reached from Home and the Journal): the user's record against each Sphere (overruled N times, Sphere right M, user right K), the criteria they habitually over- or under-score (their Potential score against what the outcome showed), and a plain-language summary. From it the app writes a short **about-you note** (under 80 words) and sends it with every Sphere call, so the panel can anticipate where the user over- or under-weighs evidence. The user reads, edits and resets the note in Settings, under the honest label: *FORGE remembers your track record and shares it with the panel. The AI itself doesn't change.* Nothing is shown or written until three outcomes are recorded; the app never guesses.

Over time the Journal becomes the most useful screen in the app: a record of the user's own calibration. Which beliefs held up, which didn't, which kinds of ideas they overrated. It is shown only when the user opens it; it never scores the user or sends a notification.

```
Decision   id, idea?, project?, kind (commit|setAside|ruling|pivot|outcome),
           decidedAt, decision, beliefs, reasoning, expectedResult, expectedBy?,
           actualResult?, recordedAt?
```

---

## 6. The AI Idea Partner

Contextual AI inside each idea and project. No global chat tab.

**Context passed to the model:** original idea, exploration notes, selected lens, scores and evidence so far, project milestones and decisions, open questions, and the user's about-you note (§5) when one exists.

**Capabilities (each is a distinct action, not a free-form chat prompt):**
- Expand — clarify a rough thought.
- Run a Round — the Sphere panel gives verdicts, argues, and the user rules on each point (§6C). This replaces a generic "Challenge" action.
- Compare — two ideas, same lens only.
- Design an experiment — cheapest test of the riskiest assumption, returned as an Experiment card.
- Plan — break into milestones and a first deliverable.
- Next step — given current state, one action.
- Summarize — turn a brainstorm into notes, decisions, and open questions.
- Explain this criterion — teach the framework behind any rubric item.
- Pivot — generate sibling variants that keep what scored well and change what didn't (see §6B).
- Pitch — propose new capture-ready ideas from what is working and the user's stated advantages (see §6B).

**Behavior rules (put these in the system prompt):**
- Constructive and skeptical. No empty praise. Never say an idea is good because the user had it.
- Distinguish facts, estimates, assumptions, and opinions explicitly.
- Never claim to have researched something. If evidence is missing, say what's missing and where to look.
- Preserve the user's original intent.
- Return structured JSON for anything that changes app data; the app shows a diff and the user confirms.

**Output contract:** every AI action returns a typed JSON object (defined per action) plus a short plain-text rationale. Never free text that the app has to parse.

---

## 6A. The Research Library (NotebookLM-style, per idea)

This is what separates FORGE from a scoring app. Every idea has its own **Library**: a grounded collection of sources the AI reasons over. Think NotebookLM, but each notebook is wired directly into the evidence ladder and the Workshop.

**Source types:** web pages (saved with a cached text snapshot), PDFs, pasted text, voice memos with transcripts (interviews, thinking-out-loud), photos/screenshots (OCR'd), competitor pages, pricing pages, review threads, and the user's own notes. Each source stores: title, origin URL or file, captured date, full text, an AI summary, and a **source class**: `user-verified` (the user read it or lived it), `ai-found` (the AI retrieved it), or `assumption` (the user's own belief, unverified).

**Grounded Q&A.** Inside an idea, the user can ask anything and the AI answers *only from the Library*, with inline citations that jump to the exact passage. If the answer isn't in the Library, the AI says so and offers to go find it. No ungrounded confident answers.

**Research actions (AI uses web search through the proxy):**
- **Map the market** — find 3–5 competitors or current alternatives; save their pricing pages, positioning, and one-star reviews as sources; produce a market map (cheap/simple · premium · general · specialized · DIY · service) with gaps.
- **Find demand signals** — search complaint threads, communities, job postings, and search-volume proxies for the problem; save hits as sources; tag each with the evidence-ladder rung it supports.
- **Pull the facts** — for any criterion, retrieve what public information exists and label it `ai-found`.
- **Draft the experiment assets** — landing-page copy, five Mom-Test interview questions, or a 20-message outreach script for the current Experiment card.

**Hard rules:**
- *Verifying a source is not the same as having evidence.* Marking an `ai-found` source as reviewed confirms it is real and says what it says; it does not by itself raise Confidence. Confidence rises only when the user attaches a source to a specific criterion as Evidence and assigns it a ladder rung — and the rung is bounded by what the source can prove. A competitor's pricing page proves the market exists (rung 2 at most); it never proves demand for *this* idea.
- Agreeing with a Sphere, an AI summary, or a Pitch never creates Evidence. Only the user attaching a source to a claim does.
- Compliments and assumptions never raise Confidence. The Confidence ring shows a breakdown: % user-verified / % ai-found / % assumption.

**Library outputs (NotebookLM-style artifacts, generated on demand, each saved as a source):**
- **Idea brief** — one page: problem, who, alternatives, differentiation, evidence so far, open questions, with citations.
- **Audio briefing** — a 3–6 minute spoken overview of the idea's current state and biggest open question, for listening on a walk. Generated server-side via TTS; stored locally.
- **Study guide for a framework** — when the user hits "explain this criterion," the Library can generate a short primer on that framework (e.g., Mom Test in 10 minutes) with the rules that apply to *this* idea.
- **Evidence table** — every claim the user has made about the idea, with the source that supports it or the word "unsupported."

**Everything the AI brings in is a source, never a conclusion.** The user decides what it means.

---

## 6B. Pivots and Pitches (the app proposes, the user disposes)

> **Superseded by `docs/ENGINE.md` (decision 0033) wherever they disagree.** The engine spec replaces this section's voices, pipeline and pivots with research → source verification → blind verdicts → the Tank → the Deal → the Test → the Loop. §0A and §6A's honesty rules still bind it. Screens: `docs/design/engine-tank-and-deal.pdf`.

FORGE is not only a filter. It should actively reshape weak ideas and pitch new ones, using what the Vault and Workshop reveal about what is working.

### Pivots — reshape an idea that isn't working

Triggered manually from any evaluation, and offered automatically when an evaluation's recommendation is *Revisit later* or *Archive*, or when a project is paused.

The AI reads the full evaluation, keeps the criteria that scored well, and generates **3–5 variants**, each using a named pivot type (Lean Startup):

- **Zoom-in** — one feature becomes the whole product.
- **Zoom-out** — the product becomes one feature of something larger.
- **Customer segment** — same solution, different buyer who feels the pain more.
- **Customer need** — same buyer, a more painful adjacent problem surfaced in research.
- **Channel** — same product, reached through partnerships, integrations, or existing clients instead of cold acquisition.
- **Business model** — one-time → subscription → productized service → done-for-you → marketplace → template/digital product.
- **Technology / delivery** — app → web tool → spreadsheet → manual concierge → course.

Each variant states: what is kept, what changes, which weak criterion it is meant to fix, and the new riskiest assumption. Variants are saved as **sibling ideas** linked to the parent (`pivotOf`), so each can be evaluated under its own lens and compared. The original is never modified.

### Pitches — propose new ideas from what's working

A dedicated "Pitches" surface (reachable from Home and the Vault, never a notification). The AI builds pitches from, in order of weight:

1. **What's working** — ideas with high Potential *and* high Confidence, projects that launched, experiments that passed, evidence rungs 3–5 reached anywhere in the Library.
2. **What the user is good at** — a short, user-maintained "Advantages" list (skills, audiences, relationships, assets). Editable in Settings; the AI never infers it.
3. **Problems already observed** — complaint threads, interview notes, and competitor gaps saved in any Library.
4. **Intersections** — skill × observed problem × business model × channel the user can already reach.

Each pitch is a **capture-ready idea**: title, one paragraph, who it's for, why now, the advantage it uses, and its riskiest assumption. Actions: *Save to Vault* / *Not for me* (with an optional reason the AI learns from) / *Pivot this*. Pitches the user rejects are not resurfaced.

Pitches cluster by: fastest cash · recurring revenue · product/asset · creative · personal growth. The user picks the cluster; the app never pushes commercial ideas on a creative mood.

**Rules:**
- No pitch may claim market evidence it hasn't saved as a source. "There is demand" must point at something in a Library or be labeled an assumption.
- Pitches never run on a schedule and never badge the app icon. They exist when the user goes looking.
- A rejected pitch's reason ("I don't want to run a service business") becomes a standing constraint shown in Settings and respected in future pitches.

---

## 6C. Spheres — the panel (replaces the single "Challenge" action)

> **Superseded by `docs/ENGINE.md` (decision 0033) wherever they disagree.** The engine spec replaces this section's voices, pipeline and pivots with research → source verification → blind verdicts → the Tank → the Deal → the Test → the Loop. §0A and §6A's honesty rules still bind it. Screens: `docs/design/engine-tank-and-deal.pdf`.

The AI partner is not one voice. It is a panel of **Spheres**: distinct perspectives, each bound to named frameworks, each *required* to argue from its own angle so they cannot all agree. Think Shark Tank, except the sharks must cite sources and are allowed to say "I can't tell yet."

### The panel

| Sphere | Judges | Frameworks | Will not do |
|---|---|---|---|
| **Investor** | Economics, pricing, distribution, recurring revenue, enterprise value | $100M Offers, $100M Leads, Built to Sell, Profit First | Praise a product with no channel |
| **Customer** | Problem reality and demand — only from what real people said or did in the Library | The Mom Test | Speak for customers who aren't in the Library; must say "nobody has talked to me yet" |
| **Builder** | Feasibility, smallest usable version, skills required, maintenance burden | The Lean Startup, The E-Myth | Approve a plan that depends on the user doing custom labor forever |
| **Strategist** | Differentiation, positioning, why anyone would switch | Blue Ocean (Four Actions), Good Strategy/Bad Strategy | Accept "I'd do it better" as differentiation |
| **Skeptic** | Unsupported assumptions, vanity metrics, fake urgency, overbuilding | Anti-delusion rules; Lean Startup riskiest-assumption | Agree that an idea is good because the user had it |
| **Steward** | Values alignment, sustainability, whether this is the right use of the user's life right now | Atomic Habits; user-written charter | Let the other five turn progress into identity |

The Steward's charter is written by the user in Settings (a few sentences on what matters to them and what they refuse to trade away). The app ships with a placeholder, never a default worldview.

### A Round

1. **Pitch.** The user pitches an idea (text or voice), or a §6B Pitch is put in front of the user.
2. **Verdicts.** Each Sphere returns a structured verdict: `onTrack | offTrack | cantTell`, the criterion key it is judging, a two-sentence reason, and the Source IDs it relies on. A verdict with no sources must be `cantTell` and must name what evidence would change it. On-screen (*Hear the panel*, §7), verdicts are one card per Sphere, each with Agree · Disagree · Find out.
3. **Crossfire.** Only between two Spheres whose verdicts conflict (one `onTrack`, the other `offTrack`; `cantTell` argues with nobody). Each may reply once to the other. One exchange per pair; this is not a chat. On screen the pair sits together under a *Split* bracket, and a dashed line joins their orbs on the arc; either opens the crossfire.
4. **Rulings.** The user goes through each point and marks *Agree* / *Disagree* / *Find out*. Agree → logged as a Decision or, if the Sphere cited a source, promoted to Evidence on that criterion. Disagree → logged as a user Assumption (the user's belief against the panel's). Find out → Experiment card.
5. **Summary.** One screen: where the panel agreed, where it split, the user's rulings, and what changed in the evaluation (criteria scores the user chose to update, never auto-updated).

Rounds are saved on the idea with full transcript and rulings. A Round can be re-run after new sources are added, and the app diffs the verdicts ("Customer moved from can't tell to on track after you added three interviews").

### Spheres elsewhere

- **Pitches (§6B)** are voiced by Spheres: the Customer pitches problems people complained about, the Investor pitches recurring-revenue plays, the Builder pitches things buildable in a weekend, the Steward pitches growth and creative work. The user can ask one Sphere for pitches or the whole panel.
- **Pivots (§6B)** can be requested from a specific Sphere ("Strategist, pivot this").
- **Explore** prompts can be asked by a Sphere, so the exploration stage already has the panel's angles in it.
- **Workshop**: the Builder owns "next step" suggestions; the Skeptic reviews milestones for scope creep; the Steward can be asked "should I keep going?" when a project stalls.

### Rules (put in every Sphere's system prompt)

- Argue from your framework and only from Library sources. Name the source. If there is none, say `cantTell` and say what would change your mind.
- Disagree with other Spheres when your framework disagrees. Do not converge for politeness.
- Never tell the user the idea is good because they had it. Never use the words "great idea."
- Distinguish fact, estimate, assumption, and opinion in every reason.
- Short. Two sentences per verdict, one per crossfire reply.
- You are a perspective, not a character. No catchphrases, no personality beyond the framework.

### Data model additions

```
Round        id, idea, pitchText, createdAt, verdicts[], crossfire[], rulings[], summary
Verdict      id, round, sphere, verdict (onTrack|offTrack|cantTell), criterionKey,
             reason, sources[], evidenceNeeded?
Crossfire    id, round, fromSphere, toSphere, text
Ruling       id, verdict, choice (agree|disagree|findOut), note?, resultingDecision?,
             resultingEvidence?, resultingAssumption?, resultingExperiment?
StewardCharter  text, updatedAt   (stored in Settings)
```

### Phase placement

See §11. Spheres land with the Evaluation Lab (verdicts need criteria keys). The Steward and its charter come with the Personal Growth lens. Before the Library exists, every Sphere will mostly say `cantTell` — that is correct behavior, not a bug.

---

## 6D. Reality Check (the AI goes and looks)

> **Superseded by `docs/ENGINE.md` (decision 0033) wherever they disagree.** The engine spec replaces this section's voices, pipeline and pivots with research → source verification → blind verdicts → the Tank → the Deal → the Test → the Loop. §0A and §6A's honesty rules still bind it. Screens: `docs/design/engine-tank-and-deal.pdf`.

The user's core ask: "Is this worth pursuing, based on what already exists — and if there are competitors, do I compete, or should I just use their product?"

A Reality Check is a single action on any Business-lens idea. The AI runs desk research through the proxy (web search + fetch), saves everything it finds as `ai-found` Sources in the idea's Library, and returns a structured report ending in one of four verdicts.

### What it gathers

1. **Who already does this** — 3–8 current alternatives, including "do nothing," DIY, and adjacent products. For each: name, URL, pricing (actual numbers where public), positioning in one line, what reviews praise, what reviews complain about (one-star reviews and support forums are the goldmine), how long they've existed, any signs of traction (review counts, funding, hiring, pricing increases).
2. **Demand signals** — complaint threads, community posts, job postings for roles that handle the problem, search-interest proxies, "I wish there was…" posts. Each tagged with the evidence-ladder rung it supports (almost always rung 2: the problem is real and people pay for workarounds).
3. **The gap map** — a Blue Ocean grid: what every alternative offers, what every alternative ignores, what customers complain about that nobody fixes, what everyone charges for that customers don't value.
4. **Fit to the user** — read against the user's Advantages list (§6B) and Constraints: does this use something the user already has?

### The four verdicts

| Verdict (stored value) | Shown as | One line under it | When | What the report leads with |
|---|---|---|---|---|
| `buildIt` | **Go build it** | There's a gap, and you can reach it. | A real gap exists and the user has an advantage reaching the people in it | The gap, the advantage, the smallest version, the first field test |
| `compete` | **Worth a fight** | It's crowded, but here's your opening. | Crowded, but reviews show a wedge competitors leave open | The wedge (ERRC grid), who to target first, why they'd switch, the first field test |
| `useTheirs` | **Already solved** | Something out there does this well. Try it first. | Someone already solves it well, and the user's underlying need is the problem, not the business | The product to go use, what it costs, what it won't do, and a prompt: "Does using this close the need? If yes, archive the idea with a note." |
| `cantTell` | **Go ask people** | Research ran out. Real people decide this one. | Market exists but demand for *this* angle is unproven | The riskiest assumption and the cheapest field test (Experiment card), with the interview questions or outreach script pre-drafted |

The verdict is advisory. The user records their own decision in the Decision Journal (§5), and that decision — not the verdict — is what the app later checks against reality.

### Honest limits (shown in the report)

Desk research can reach rung 2 on the evidence ladder: it proves the problem and the market exist. It cannot prove anyone will give *this user* time or money for *this* angle. Rungs 3–5 require a real person outside the app. The Reality Check prepares that test; the user runs it; the Workshop records the result. The report says this in plain words every time.

### Rules

- Every claim cites a saved Source. No source, no claim — the report says "could not find" rather than guessing.
- Pricing and traction figures are quoted with the date fetched.
- "Already solved" is a legitimate, non-negative outcome. The app never nudges toward building.
- A Reality Check can be re-run later; the app diffs the competitor set and verdict.
- One Reality Check is the most expensive action in the app (many fetches plus synthesis). Confirm before running; never show a price (§0A); cache results.

### Data model additions

```
RealityCheck   id, idea, createdAt, verdict (buildIt|compete|useTheirs|cantTell),
               competitors[], demandSignals[], gapMap, fitNotes, limitsNote,
               experiment?, sources[], costEstimate
Competitor     id, name, url, pricing, positioning, praises[], complaints[],
               tractionSignals[], fetchedAt, source
```

---

## 7. Home — the overview (v4.2)

Home is the overview of the three stages (the "Home overview" artboard). It must make the app's purpose obvious with no tutorial: *you give the panel an idea; the panel goes and finds out whether it's real; you decide; you go and do it.*

### First launch (empty Vault)

The six orbs are on screen, large, drifting slowly in a loose row, before any content exists. Under them, one line in serif:

> Six perspectives. Give them an idea and they'll go find out if it's real.

Under that, the capture field, focused, with the mic. Nothing else. Tapping an orb shows its one-line job.

### Home with content ("Home · leveled up")

Top to bottom:

1. **The sky.** A grainy mesh gradient (lavender, violet, rose, ember) whose bottom row is the page colour, so it melts into the ground, behind the date in mono caps, the settings button, *From idea to reality* in serif at 40 pt, and a live subline: "N ideas in motion · N out in the world".
2. **The pipeline strip.** Idea → Formation → Reality as glowing 40 pt nodes in the stage colours (Idea lavender, Formation violet, Reality ember) on a gradient line, each with its count and a one-line status ("Waiting for the panel", "Waiting on your ruling", "Out in the world"). Tap a node for its tab.
3. **Your next move.** One card, whichever is most urgent: the idea just captured (send it to the panel); a check that failed, with its error; the step owed in Reality; a Brief waiting to be heard; else the most recent unchecked idea. A real-world step always outranks a ruling. The Reality step is the next-move card: a 3 pt gradient top edge, the idea's title in serif, the step in 16 pt sans, full-width progress segments, then **What's riding on it**: Potential and Confidence as 56 pt rings, the Projection ("$X / mo if it works") with the verified-vs-estimate bar on Business ideas or the Impact line on Growth and Creative, and one generated line tying the step to the evidence it raises ("This step is how 33 becomes a real number. Five conversations move demand to rung 3."). Ideas with no evaluation hide the panel. *Questions* and *Log a conversation* beneath.
4. **Capture.** The field, *What if…* in italic serif, with the ember mic button.
5. **Your ideas, by stakes.** Cards with a stage-coloured side band, the idea's spark, the stage and the stage trail on the top line (never wrapping), the serif title, and a labelled **Est. return** row that carries the verdict word ("Go ask people · The desk found no price to go on"): before any check, "Send to the panel to estimate."; on a checked Business idea, the Investor's monthly range from the prefill ("$900–$2.4k / mo"), striped as AI-found, with a small "from competitor pricing" line; once the user enters price and units or a payment is logged, their single figure with "your numbers"; **Impact** on Growth and Creative ideas. Tapping the row opens the Projection card with the sources the estimate came from. Sorted by that figure, then Confidence. *All* opens the Idea tab. Placeholders ("Add who it helps") are 13 pt muted sans, never display serif or colour. An idea in Reality that never saw the panel reads "Reality · started without the panel" with a small *Check it* link. The prefill returns `projectionLow`, `projectionHigh` and `projectionBasis`, so the range is the panel's, never invented by the app.

**The Idea tab** opens with one line a day: a quote in small italic serif with its attribution in mono beneath, rotating daily, dismissible for the day. The quotes live in `Quotes.swift`, every entry with text, author and a source note, and only verifiable quotes are included. Settings: *Quotes · All / Scripture only / Secular only / Off*.

**The same idea never appears twice on the screen.** Whatever idea the next-move card is about is left out of the list.

No stats, no streaks, no charts, no prices.

### After capture

Saving an idea never lands on a static card. Home turns toward it: the new idea's title in serif, then

> Want us to look into this?

with the ember **Reality Check** button and a quiet *Later* link. Capture → one tap → the confirm sheet → working. The user never has to find the feature.

### The working state

While a Reality Check runs, the app narrates in the Spheres' voices, one line at a time as each starts, each tied to its orb lighting:

- Customer — "Reading what people complain about."
- Investor — "Checking what competitors charge and how they get found."
- Strategist — "Looking for what nobody offers."
- Builder — "Working out the smallest version."
- Skeptic — "Looking for the belief that kills it."

This is the only place the Spheres' jobs are ever explained, and it happens every time, in nine words each. The user can leave; the check keeps running, and the idea sits in Formation when it is back.

### The Formation idea page

A checked idea opens on **the council arc** ("Home A · the stage"): the six orbs on a half-circle of 150 pt radius with their names beneath, dashed ember lines between the pairs whose verdicts conflict, the verdict inside the arc, and *Hear the panel →*. Tap an orb to read that voice under the arc and rule on it; tap a line for the crossfire. Below the arc: the Brief (§0A step 3), and, once a step exists, the next-step card.

### Hear the panel

*Hear the panel* replaces the Round screen: one card per Sphere (orb at 40 pt in its verdict state, name, verdict, reason, source line, Agree · Disagree · Find out), with conflicting pairs sat next to each other under an ember *Split* bracket that opens the crossfire. The Steward is a dashed placeholder at the bottom until Phase 5. *Argue it out*, where the user pushes back and the two Spheres answer the point, arrives with credits (§11, Monetization & launch).

### Copy voice

The app speaks as the panel ("we," "us") only in these three moments: the empty state, the after-capture prompt, and the working narration. Everywhere else it is silent chrome. No exclamation marks, no "great," no encouragement.

---

## 8. Design direction

- **Feel:** a quiet studio at night, not a dashboard. The default theme is deep matte charcoal (ground #1C1916, cards #272320, hairlines #3A342E, text #F1EBE2, muted #A39B8F) with one ember accent (#C4441C on fills, #E58A62 as text) used only for capture, "next step," and the Confidence ring. A light theme is secondary and inverts the same tokens.
- **The idea's sky:** every idea detail opens with a grainy gradient header (lavender → ember, SVG turbulence overlay at ~35% multiply) whose blend shifts with the idea's stage: cool and quiet at Capture, warming toward ember as it moves to Build. It is the only large color field in the app.
- **Type:** Fraunces (or system New York) for idea titles, the user's own words, and every number that matters; IBM Plex Mono small caps with wide tracking for structure labels; Inter/system for body. The user's original text is always italic serif with a 2px ember rule on the left; AI text is small sans in muted with a spark glyph.
- **Evidence as pattern, not color:** verified = solid fill, AI-found = diagonal stripes, assumption = dot grid. These three fills appear on the Confidence breakdown, on every criterion row chip, and on the Projection/Impact bar, so evidence shape is readable without reading.
- **Every idea carries one spark** (`IdeaSpark`): a seed of lavender light while it waits, a swirl of the five Sphere colours weighted by verdict while it is in formation (a bright seam when two voices split), and an ember flame with one ring per logged conversation or payment once it is in reality. 44 pt on every card with a three-segment stage trail, 128 pt in the idea page header. Gradients, never images; still under Reduce Motion. The Sphere colours appear only after the panel has spoken. Orbs stay where the panel itself speaks.
- **Spheres are orbs, and the orbs are the hero.** Each Sphere is a soft sphere built from two or three overlapping radial gradients with a slight blur and an inner highlight, in its own palette (Customer blue, Investor ember, Strategist violet, Builder green, Skeptic stone, Steward gold), modeled on blurred-gradient record-sleeve art: luminous, not glossy. Rendered in SwiftUI with `Canvas` or layered `RadialGradient` + `.blur`, never a bitmap. States: **idle** (56 pt, slow 8-second drift of the gradient center, respects Reduce Motion by holding still), **working** (during a Reality Check the orb brightens and its drift speeds up; orbs light in sequence as each Sphere finishes), **speaking** (tapped: it grows to 96 pt, the others dim to 40%, and its verdict appears beneath in serif), **disagreeing** (a 1 pt hairline connects two orbs whose verdicts conflict). On the Brief screen the six orbs sit in a single row above everything else; on the Round screen each verdict card leads with its orb at 40 pt. No faces, no icons, no catchphrases, no names larger than mono caps; the orb is the whole identity.
- Reference canvas: see the "FORGE Idea Detail" design artifact for the idea detail and Round screens.
- **Motion:** subtle — cards settle, stages slide. Nothing bounces for attention.
- **Hierarchy:** the original idea text is always visually distinct from AI-generated text (e.g., AI text in a secondary color with a small spark glyph).
- **Evidence ladder** renders as an actual vertical ladder with the current rung lit.
- **Potential and Confidence** render as two separate rings, never merged. Confidence below 40 shows a soft label: "mostly enthusiasm so far — here's how to raise it."
- Accessibility: Dynamic Type, VoiceOver labels, reduced-motion respected.

---

## 9. Tech stack

**Decided: native iOS.** The developer has a Mac with Xcode. Do not propose cross-platform alternatives.
- Swift 5.10+, SwiftUI, iOS 17+.
- SwiftData for local persistence (CloudKit sync is a later phase, design the schema so it can be enabled).
- Speech framework for voice capture; AVFoundation for recording; recordings stored locally with transcripts.
- AI: Anthropic Messages API with web search and web fetch tools, called through a small serverless proxy (Vercel or Cloudflare Worker) so no API key ships in the app. Proxy holds the key, enforces rate limits, validates JSON output, and returns fetched pages as text snapshots for the Library. TTS for audio briefings also runs through the proxy.
- Citations: chunk source text on save; grounded answers reference chunk IDs so taps jump to the passage.
- No third-party UI frameworks. Minimal dependencies.

**Audience: personal tool first.** One user, the developer. No accounts, no monetization, no multi-screen onboarding tour — but the app must still explain itself on first launch, through the panel (§7), because a tool whose purpose is invisible is not finished even for one user. If it proves useful, it may later be shipped as a product — so keep the architecture clean (proxy-based AI, CloudKit-ready schema, no hardcoded personal data), but do not build for that case now.

**Non-goals for v1:** Android, web, teams/sharing, accounts, push notifications, in-app purchases, analytics SDKs, CloudKit sync, App Store submission.

---

## 10. Data model (SwiftData)

```
Idea
  id, title, originalText (immutable after create), aiSummary?, lensType?,
  stage (capture|explore|evaluate|build|launch|archived),
  tags[], createdAt, updatedAt, archivedAt?,
  pivotOf?: Idea, pivotType?, origin (captured|pitched|pivoted),
  triage: OpportunityFilter?, explorations[], evaluations[], sources[], project?

Pitch
  id, title, body, forWhom, whyNow, advantageUsed, riskiestAssumption,
  cluster (fastCash|recurring|asset|creative|growth), createdAt,
  status (open|saved|rejected), rejectionReason?, savedIdea?

Advantage      id, text, kind (skill|audience|relationship|asset), createdAt
Constraint     id, text (e.g. "no service businesses"), fromPitch?, createdAt

Exploration
  id, idea, createdAt, promptKey, userText, aiText?, confirmed

Evaluation (versioned; never overwritten)
  id, idea, lensType, version, createdAt,
  criteria[]: {key, score 1-5, evidenceLevel 0-5, note, evidence[]},
  potential 0-100, confidence 0-100,
  shortfalls[], riskiestAssumption, recommendation, experiment?

Source
  id, idea, kind (web|pdf|text|voice|image|note), title, url?, fileRef?,
  fullText, aiSummary?, sourceClass (userVerified|aiFound|assumption),
  reviewed (Bool), capturedAt, chunks[] (for citation anchoring)

Evidence  (a claim tied to a criterion, pointing at a Source)
  id, criterionKey, ladderRung 0-5, text, source?, createdAt

LibraryArtifact
  id, idea, kind (brief|audioBriefing|studyGuide|evidenceTable), content, audioRef?, createdAt

Project
  id, idea, name, description, desiredOutcome, status (active|paused|done|archived),
  milestones[], decisions[], notes[], resources[], nextStep?, createdAt, completedAt?

Milestone  id, project, title, order, done, tasks[]
Task       id, milestone, title, done, createdAt, completedAt?
Decision   id, project, text, date, reason
Experiment id, hypothesis, test, metric, cost, timeboxDays, decisionRule, outcome?
```

Lens definitions (criteria, rubrics, ladders, playbooks) live in `Lenses.swift` (or a JSON resource) as static content, not in the database.

---

## 11. Build plan — phased, each phase shippable

Work phase by phase. Do not start a phase until the previous one runs on device. After each phase, list what was built, what was deliberately skipped, and any decision that needs the developer.

**Phase 0 — Scaffold**
Project setup, SwiftData models, tab structure (now Home · Idea · Formation · Reality, §2), design tokens (colors, type, spacing), dark mode, empty states. Done when: app launches with empty states on all three tabs.

**Phase 1 — Capture & Vault**
Floating capture (text + voice + paste), Idea cards, search, filter, sort, archive, idea detail view with immutable original text. Done when: ten ideas can be captured by voice and text and found again.

**Phase 1b — Export & backup**
JSON + Markdown export of the whole Vault from Settings, before any AI feature exists. Ideas are the user's intellectual property; losing them destroys trust. Done when: an export can be re-imported into a fresh install.

**Phase 2 — Core loop: Explore → next action → outcome**
Guided Explore prompts per idea (no AI yet, or AI Expand/Summarize only, confirm-before-save). Minimal Workshop: convert idea → project, desired outcome, one next step, mark done, record "what happened." Decision Journal entries on commit and outcome. AI-sharing disclosure screen before the first AI call. Done when: an idea can go from capture to a completed real-world action with a recorded outcome, entirely without the Lab.

**Phase 3a — Evaluation Lab (Business lens), hand-scoring layer** *(built)*
Opportunity Filter (Business lens only), Lens A with all six criteria including definitions, rubrics, evidence ladder UI, playbooks, manual evidence attachment (links, notes, voice), Potential + Confidence rings, shortfalls, riskiest assumption, recommendation, Experiment card, versioning. Proxy deployed to Vercel. Spheres: Investor, Customer, Builder, Strategist, Skeptic with Rounds and rulings. Done when: an idea can be evaluated, a Round run, and the user's rulings land in the Journal.

**Phase 3b — Proxy, Reality Check, Sphere pre-fill, the Brief**
Vercel proxy with the live client (Sonnet for Spheres and synthesis, Haiku for summaries and transcript cleanup, prompt caching on for every multi-Sphere call). Reality Check (§6D) with web search and fetch, saving `ai-found` Sources. The `prefill` action: five Spheres fill explorations, criteria, projection, riskiest assumption, and next move from the Library, every field carrying source IDs. The Brief screen (§0A step 3) with orbs in working and speaking states, the verdict row, what-we-found, striped rings, the one human task with drafted assets, and the three buttons. *Not quite* opens the 3a Lab; *I know something you don't* records a `user-verified` Source and re-scores affected criteria. Cost estimate before, actual after, monthly ceiling in Settings. Done when: a captured idea goes Reality Check → Brief → Looks right → a Workshop task with drafted interview questions, in three taps, with every proposed value visibly AI-found.

**Phase 3c — Rounds and rulings**
Full Round flow from §6C on top of the pre-fill: crossfire where Spheres disagree, Agree / Disagree / Find out rulings, Journal entries, re-run diffs. Done when: the user can rule on a disputed criterion and see the ruling land in the Journal.

**Phase 4 — Research Library surface**
Source list per idea (web snapshot, PDF, paste, voice→transcript, image OCR), source classes, grounded Q&A with citations, evidence tagging bounded by rung, manual source add. Done when: the user can ask a question about an idea and get a cited answer from saved sources, and add their own interview memo as a `user-verified` Source.

**Phase 4b — Library artifacts**
Idea brief, evidence table, framework study guide, audio briefing (TTS via proxy). Done when: each can be generated and reopened offline.

**Phase 5 — Lenses B and C + Steward + Compare + Pivots**
Personal Growth and Creative lenses, Steward Sphere and charter, same-lens comparison, Pivot action producing linked sibling ideas. Done when: a low-scoring idea can be pivoted into three variants and each evaluated independently.

**Phase 5b — Pitches**
Advantages and Constraints in Settings, Pitches surface, clustering, save/reject/pivot actions, rejection reasons feeding constraints. Done when: the app can pitch five ideas grounded in existing Library sources and a rejection changes the next batch.

**Phase 6 — Full Workshop**
Milestones/tasks, decisions log, AI Plan / Next step, pause/complete/archive, launch definition and retrospective, Journal calibration view. Done when: a project can be run from first milestone to "launched" and the Journal shows predictions against outcomes.

**Phase 7 — Home & polish**
Home sections, reflective prompt, progressive disclosure pass (a first-time user never needs to learn "Lens," "Sphere," or "Ladder" before capturing), motion, accessibility, performance on older devices, TestFlight build. Trademark/App Store name check before any public name is committed.

**Phase 8 — Monetization & launch** *(recorded, not built)*
Everything that stays on the phone is free: capture, the Vault, rulings, logging, the Workshop, the Journal. The AI is paid for with **credits** (the "Credits screen" and "Credit moments" artboards):
- **Prices.** Reality Check 3 credits (research, five voices, their first argument, a verdict and the next step). *Argue it out* 1 credit (the user pushes back; the two Spheres answer the point). Agree, disagree, find out, and logging what happened: free. If a run fails partway, the credits come back.
- **Packs.** One-time purchases, no subscription; purchased credits never expire. Three packs (try it out · most people pick this · for lots of ideas), each described in ideas and months at the user's pace, never in tokens. *Restore purchases* on the screen.
- **The four credit moments.** A credits pill, always visible on Home, opens the Credits screen. Before anything is spent, a confirm sheet: what it does, *Uses 3 · 4 left after*, the refund line, the "your idea text is sent to an AI model through FORGE's server" line, one ember button with the cost on it, *Not now*, and *Don't ask again for Reality Checks*. A low-balance card ("Running low: 4 credits left. Enough for one more Reality Check and a debate.") with *See credits* and *Dismiss*. An out-of-credits state on the idea: "You're out of credits, so the panel can't research this one yet", *Add credits*, and the list of what still works for free: score it yourself in the Lab, write down what you know, take it straight to the Workshop, rule and log on other ideas. Running out only pauses the AI; nothing is locked.
- **Accounts and the ledger.** Sign in with Apple; a server-side credit ledger that the proxy debits per action and refunds on failure; App Attest on every proxy call so only the app can spend. The monthly ceiling in Settings stays as a personal guard.
- **Reviews.** The system review prompt only after a win (a step logged to its target, or a launch), never on first run or after a failure. A *Rate FORGE* row in Settings. A *Tell us what's broken* link shown to everyone. No review gating, no rewards for reviews.

---

## 12. Quality bar

- Every screen works with no network (AI actions show a calm "offline" state).
- Every AI write goes through a confirm step with a visible diff.
- Original idea text can never be edited or lost. Tests enforce this.
- Evaluations are append-only. Tests enforce this.
- Unit tests for scoring (Potential, Confidence, normalization) and for lens content integrity (every criterion has definition, 1/3/5 rubric, ladder, playbook).
- No streaks, badges, or notification nags anywhere in the codebase.
- Export works from Phase 1b onward and is tested on every phase.
- The app tells the user, once, before the first AI call, that idea text and sources are sent to an AI provider through the user's own proxy, and asks for consent. Settings shows what is sent.
- Progressive disclosure: capture and the core loop never require the user to know the Lab's vocabulary.

---

## 13. First deliverable before writing code

Return, in this order:
1. Any decision this brief leaves open that you need answered (max five questions).
2. The Phase 0 file tree.
3. The `Lenses` content for Lens A, criterion A2 (Demand evidence), fully written out, so the teaching layer's tone can be approved before the rest is authored.

Then wait for approval.

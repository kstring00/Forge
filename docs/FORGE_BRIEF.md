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
2. **Reality Check (one tap).** The app shows an estimated cost and a one-line "this sends your idea text to the AI through your proxy" note the first time, then runs. In the background, through the proxy: desk research (§6D) — competitors, pricing, complaints, demand signals, job postings — saved as `ai-found` Sources. Then the five Spheres each read the Library and **pre-fill the whole Lab**: a proposed answer to every Explore prompt, a proposed score and evidence rung for every criterion with the Source it leans on, a proposed Projection range, a proposed riskiest assumption, and a proposed next move. Progress is visible as the orbs light up one at a time. Typical wall time: one to three minutes. The user can leave and come back.
3. **The Brief (one screen).** When the check finishes, the idea opens on a single screen, led by the orbs:
   - **The verdict row** — Build it / Compete / Use theirs / Can't tell from the desk, with one sentence.
   - **The panel** — six orbs in a row (the sixth, Steward, dim until Phase 5). Tap an orb to read only that voice. Where two Spheres disagree, a thin line connects them; tap it for the crossfire.
   - **What we found** — three to five lines, each a claim with its Source chip (stripes = AI-found).
   - **Rings** — Potential and Confidence as proposed, drawn in the AI-found stripe until the user touches them.
   - **The one thing nobody can tell from a desk** — the riskiest assumption, and the single human action that tests it, already drafted (five Mom-Test questions, or a 20-message outreach script, or a landing page's copy).
   - **Three buttons:** *Looks right* · *Not quite* · *I know something you don't*.
4. **Review by exception.** *Looks right* accepts the panel's pass as-is; everything stays visibly AI-found and Confidence stays low, honestly. *Not quite* opens the criteria list; the user taps the row that is wrong and picks a different rubric anchor — one tap per correction, the AI's version shown struck through beside it. *I know something you don't* opens voice or text; what the user says is saved as a `user-verified` Source, and the affected Spheres re-score that criterion only. The full Lab — definitions, rubrics, ladder, playbook, history — is all still there, one tap deeper, for whoever wants it. It is never required.
5. **The task.** The next move becomes the Workshop's one next step with the drafted assets attached. The user goes and does it in the world.
6. **The return.** "What happened?" — one line, or a voice memo. The user's answer is a `user-verified` Source. The ladder moves, Confidence moves, the Journal records expected vs. actual, and the Spheres re-run on the changed criteria only. If the next move is now "build," the Workshop takes over.

### Rules this adds

- **Explore is no longer a stage the user fills in.** The six prompts become the structure of the Spheres' pre-fill and remain available as optional edit fields. "0 of 6" never appears anywhere.
- **No empty form is ever the first thing the user sees.** If the Reality Check hasn't run, the idea shows the sky, the original text, and the Reality Check button. Nothing else.
- **Pre-filled is not verified.** Everything the Spheres write is `ai-found` and drawn in stripes. Confidence cannot exceed what desk research supports (rung 2) until the user brings something back from the world. The honesty rules in §6A are unchanged; this section changes effort, not evidence.
- **Three taps to a task.** Reality Check → Looks right → Start. If the user does nothing else, that still yields a real next action in the world with drafted assets.
- **Correction is one tap.** Any proposed score, rung, or answer can be overridden by choosing a different anchor; the user never types to disagree.
- **Re-runs are partial.** New information re-scores only the criteria it touches; the user is never asked to re-review the whole idea.
- **Cost is visible.** Each Reality Check shows an estimate before running and the actual after. Settings has a monthly ceiling.

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

## 2. The five-stage pipeline

Stages are flexible, not gated. An idea can move backward, skip, or sit.

| Stage | What happens | Output |
|---|---|---|
| **Capture** | Raw idea saved. Original text preserved forever. AI may propose a title and one-line summary (user confirms). | `Idea` record |
| **Explore** | Guided thinking with AI: what problem, who, what they do today, why it interests you, what a tiny version looks like, what kills it. | Exploration notes, open questions |
| **Evaluate** | User picks a **Lens** (framework set). Scores each criterion 1–5 with rubric anchors. Attaches evidence. App computes Potential + Confidence and names the riskiest assumption. | `Evaluation` (versioned) |
| **Build** | Idea becomes a `Project` in the Workshop: outcome, milestones, tasks, decisions, next step. | `Project` |
| **Launch** | User defines what "done" means for *this* idea (first customer, finished chapter, shared prototype) and closes it. | Launch record + retrospective |

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

Over time the Journal becomes the most useful screen in the app: a record of the user's own calibration. Which beliefs held up, which didn't, which kinds of ideas they overrated. It is shown only when the user opens it; it never scores the user or sends a notification.

```
Decision   id, idea?, project?, kind (commit|setAside|ruling|pivot|outcome),
           decidedAt, decision, beliefs, reasoning, expectedResult, expectedBy?,
           actualResult?, recordedAt?
```

---

## 6. The AI Idea Partner

Contextual AI inside each idea and project. No global chat tab.

**Context passed to the model:** original idea, exploration notes, selected lens, scores and evidence so far, project milestones and decisions, open questions.

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
2. **Verdicts.** Each Sphere returns a structured verdict: `onTrack | offTrack | cantTell`, the criterion key it is judging, a two-sentence reason, and the Source IDs it relies on. A verdict with no sources must be `cantTell` and must name what evidence would change it. On-screen, verdicts are six cards; `cantTell` cards show a "go find out" button that creates an Experiment card.
3. **Crossfire.** Each Sphere may reply once to one other Sphere. Limited to one exchange per pair; this is not a chat.
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

The user's core ask: "Is this worth pursuing, based on what already exists — and if there are competitors, do I compete, or should I just use their product?"

A Reality Check is a single action on any Business-lens idea. The AI runs desk research through the proxy (web search + fetch), saves everything it finds as `ai-found` Sources in the idea's Library, and returns a structured report ending in one of four verdicts.

### What it gathers

1. **Who already does this** — 3–8 current alternatives, including "do nothing," DIY, and adjacent products. For each: name, URL, pricing (actual numbers where public), positioning in one line, what reviews praise, what reviews complain about (one-star reviews and support forums are the goldmine), how long they've existed, any signs of traction (review counts, funding, hiring, pricing increases).
2. **Demand signals** — complaint threads, community posts, job postings for roles that handle the problem, search-interest proxies, "I wish there was…" posts. Each tagged with the evidence-ladder rung it supports (almost always rung 2: the problem is real and people pay for workarounds).
3. **The gap map** — a Blue Ocean grid: what every alternative offers, what every alternative ignores, what customers complain about that nobody fixes, what everyone charges for that customers don't value.
4. **Fit to the user** — read against the user's Advantages list (§6B) and Constraints: does this use something the user already has?

### The four verdicts

| Verdict | When | What the report leads with |
|---|---|---|
| **Build it** | A real gap exists and the user has an advantage reaching the people in it | The gap, the advantage, the smallest version, the first field test |
| **Compete** | Crowded, but reviews show a wedge competitors leave open | The wedge (ERRC grid), who to target first, why they'd switch, the first field test |
| **Use theirs** | Someone already solves it well, and the user's underlying need is the problem, not the business | The product to go use, what it costs, what it won't do, and a prompt: "Does using this close the need? If yes, archive the idea with a note." |
| **Can't tell from the desk** | Market exists but demand for *this* angle is unproven | The riskiest assumption and the cheapest field test (Experiment card), with the interview questions or outreach script pre-drafted |

The verdict is advisory. The user records their own decision in the Decision Journal (§5), and that decision — not the verdict — is what the app later checks against reality.

### Honest limits (shown in the report)

Desk research can reach rung 2 on the evidence ladder: it proves the problem and the market exist. It cannot prove anyone will give *this user* time or money for *this* angle. Rungs 3–5 require a real person outside the app. The Reality Check prepares that test; the user runs it; the Workshop records the result. The report says this in plain words every time.

### Rules

- Every claim cites a saved Source. No source, no claim — the report says "could not find" rather than guessing.
- Pricing and traction figures are quoted with the date fetched.
- "Use theirs" is a legitimate, non-negative outcome. The app never nudges toward building.
- A Reality Check can be re-run later; the app diffs the competitor set and verdict.
- One Reality Check is the most expensive action in the app (many fetches plus synthesis). Show an estimated cost before running; cache results.

### Data model additions

```
RealityCheck   id, idea, createdAt, verdict (buildIt|compete|useTheirs|cantTell),
               competitors[], demandSignals[], gapMap, fitNotes, limitsNote,
               experiment?, sources[], costEstimate
Competitor     id, name, url, pricing, positioning, praises[], complaints[],
               tractionSignals[], fetchedAt, source
```

---

## 7. Home

Answers three questions at a glance: *What am I thinking about? What am I working on? What should I do next?*

Sections: Quick Capture (prominent) · Continue Exploring (most recent idea) · Active Workshop (current project + next step) · Recently Captured (3–5) · One reflective prompt (optional, dismissible, never nagging).

No stats, no streaks, no charts on Home.

---

## 8. Design direction

- **Feel:** a quiet studio at night, not a dashboard. The default theme is deep matte charcoal (ground #1C1916, cards #272320, hairlines #3A342E, text #F1EBE2, muted #A39B8F) with one ember accent (#C4441C on fills, #E58A62 as text) used only for capture, "next step," and the Confidence ring. A light theme is secondary and inverts the same tokens.
- **The idea's sky:** every idea detail opens with a grainy gradient header (lavender → ember, SVG turbulence overlay at ~35% multiply) whose blend shifts with the idea's stage: cool and quiet at Capture, warming toward ember as it moves to Build. It is the only large color field in the app.
- **Type:** Fraunces (or system New York) for idea titles, the user's own words, and every number that matters; IBM Plex Mono small caps with wide tracking for structure labels; Inter/system for body. The user's original text is always italic serif with a 2px ember rule on the left; AI text is small sans in muted with a spark glyph.
- **Evidence as pattern, not color:** verified = solid fill, AI-found = diagonal stripes, assumption = dot grid. These three fills appear on the Confidence breakdown, on every criterion row chip, and on the Projection/Impact bar, so evidence shape is readable without reading.
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

**Audience: personal tool first.** One user, the developer. No accounts, no onboarding flow, no monetization. If it proves useful, it may later be shipped as a product — so keep the architecture clean (proxy-based AI, CloudKit-ready schema, no hardcoded personal data), but do not build for that case now.

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
Project setup, SwiftData models, tab structure (Home · Vault · Workshop), design tokens (colors, type, spacing), dark mode, empty states. Done when: app launches with empty states on all three tabs.

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

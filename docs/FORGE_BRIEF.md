# FORGE — Idea-to-Execution App
## Build Brief for Claude Code

You are a senior iOS architect, product designer, and full-stack engineer. Build **FORGE**, a premium iPhone app that helps one person capture ideas, pressure-test them against established business and personal frameworks, understand *why* an idea falls short, and turn the worthwhile ones into projects.

> **"Capture the idea. Test its potential. Make it real."**

This brief is the source of truth. Read all of it before writing code. Where it is silent, make the choice that keeps the app small, calm, and honest.

---

## 0. The one-paragraph version

The user has no shortage of ideas. The problem is that ideas pile up in notes and chats, get worked on in bursts, and never get evaluated with any rigor. FORGE fixes this with a five-stage pipeline (**Capture → Explore → Evaluate → Build → Launch**), a Vault that holds every idea, an Evaluation Lab that scores ideas through *named, established frameworks* with a built-in teaching layer, and a Workshop that turns a chosen idea into milestones and a single next step. AI is a skeptical collaborator inside each idea, never a generic chatbot tab.

---

## 1. Non-negotiable principles

1. **Capture in seconds.** Text, voice, speech-to-text, paste. No required fields beyond the raw thought.
2. **Explore before judging.** The app never scores an idea the moment it is captured.
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

**Hard rule:** `ai-found` sources raise Confidence only after the user marks them reviewed. Compliments, AI summaries, and assumptions never raise Confidence. The Confidence ring shows a breakdown: % verified / % ai-found / % assumption.

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

Spheres land in **Phase 3** alongside the Evaluation Lab (verdicts need criteria keys to judge against) with the Investor, Customer, Builder, Strategist, and Skeptic. The Steward and its charter come in **Phase 5** with the Personal Growth lens. Sphere-voiced Pitches and Pivots are part of Phases 5 and 5b. Before Phase 4's Library exists, every Sphere will mostly say `cantTell` — that is correct behavior, not a bug, and it is the reason to build the Library next.

---

## 7. Home

Answers three questions at a glance: *What am I thinking about? What am I working on? What should I do next?*

Sections: Quick Capture (prominent) · Continue Exploring (most recent idea) · Active Workshop (current project + next step) · Recently Captured (3–5) · One reflective prompt (optional, dismissible, never nagging).

No stats, no streaks, no charts on Home.

---

## 8. Design direction

- **Feel:** a quiet studio, not a dashboard. Warm neutrals, generous whitespace, one ember-orange accent used sparingly for capture and "next step." Dark mode is first-class.
- **Type:** one display face for idea titles, system text for everything else. Idea titles are the hero of every card.
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

**Phase 2 — Explore**
Guided prompts per idea, AI Expand / Challenge / Summarize with confirm-before-save, exploration history. Done when: an idea can be explored and the notes persist and are visibly separated from AI text.

**Phase 3 — Evaluation Lab (Business lens first)**
Opportunity Filter, Lens A with all six criteria including definitions, rubrics, evidence ladder UI, playbooks, evidence attachment, Potential + Confidence rings, shortfalls, riskiest assumption, recommendation, Experiment card, versioning. Done when: an idea can be fully evaluated, re-evaluated, and both versions viewed.

**Phase 4 — Research Library**
Sources (web snapshot, PDF, paste, voice→transcript, image OCR), source classes, grounded Q&A with citations, "Map the market" and "Find demand signals" research actions through the proxy, evidence tagging to ladder rungs, Confidence breakdown. Done when: the user can ask a question about an idea and get a cited answer from saved sources, and an AI-found competitor page can be reviewed and promoted to evidence.

**Phase 4b — Library artifacts**
Idea brief, evidence table, framework study guide, audio briefing (TTS via proxy). Done when: each can be generated and reopened offline.

**Phase 5 — Lenses B and C + Compare + Pivots**
Personal Growth and Creative lenses, same-lens comparison view, Pivot action producing linked sibling ideas. Done when: a low-scoring idea can be pivoted into three variants and each evaluated independently.

**Phase 5b — Pitches**
Advantages and Constraints in Settings, Pitches surface, clustering, save/reject/pivot actions, rejection reasons feeding constraints. Done when: the app can pitch five ideas grounded in existing Library sources and a rejection changes the next batch.

**Phase 6 — Workshop**
Convert idea → project, milestones/tasks, decisions log, next step, AI Plan / Next step, pause/complete/archive, launch definition and retrospective. Done when: a project can be run from first milestone to "launched."

**Phase 7 — Home & polish**
Home sections, reflective prompt, motion, accessibility pass, performance on older devices, TestFlight build.

---

## 12. Quality bar

- Every screen works with no network (AI actions show a calm "offline" state).
- Every AI write goes through a confirm step with a visible diff.
- Original idea text can never be edited or lost. Tests enforce this.
- Evaluations are append-only. Tests enforce this.
- Unit tests for scoring (Potential, Confidence, normalization) and for lens content integrity (every criterion has definition, 1/3/5 rubric, ladder, playbook).
- No streaks, badges, or notification nags anywhere in the codebase.

---

## 13. First deliverable before writing code

Return, in this order:
1. Any decision this brief leaves open that you need answered (max five questions).
2. The Phase 0 file tree.
3. The `Lenses` content for Lens A, criterion A2 (Demand evidence), fully written out, so the teaching layer's tone can be approved before the rest is authored.

Then wait for approval.

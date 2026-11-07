# FORGE — First deliverable (brief §13)

Returned in the order the brief asks for:

1. Open decisions I need answered (five).
2. The Phase 0 file tree.
3. Lens A, criterion A2 (Demand evidence), fully written out, so the teaching layer's tone can be approved.

No code has been written. Phase 0 starts on approval.

---

## 1. Open decisions

Each question has a recommended default. If you reply "defaults," I proceed with the first option in every case.

### Q1. How should the Xcode project be generated?

I am building from a Linux container; you run Xcode on a Mac. A hand-written `.xcodeproj` is fragile to produce blind, and merge conflicts in `project.pbxproj` are miserable.

- **(Recommended) XcodeGen.** I commit a `project.yml`; you run `xcodegen generate` once (`brew install xcodegen`) and open `Forge.xcodeproj`. The project file is never committed. Every target, build setting and test bundle stays reviewable as YAML.
- **Committed `.xcodeproj`.** I generate one with XcodeGen on my side and commit it anyway, so you can double-click and go. Costs: noisy diffs, harder to review.

### Q2. Where does the AI proxy live, and how does the phone authenticate to it?

The brief allows Vercel or a Cloudflare Worker, and is silent on auth.

- **(Recommended) Cloudflare Worker, TypeScript, in this repo under `proxy/`.** Streaming works cleanly, KV covers rate limits and page-snapshot caching, Workers AI or an external TTS provider handles audio briefings. The app sends a long random bearer token stored in a git-ignored `Local.xcconfig`. That is adequate for a one-user personal tool and is swappable for App Attest later.
- **Vercel Edge Function.** Same shape; fine if you already pay for Vercel.
- **Separate repo for the proxy.** Only if you want different deploy cadences.

The proxy is not needed until Phase 2. Phase 0 only reserves the folder and the client protocol.

### Q3. Which display typeface for idea titles?

The brief says one display face for titles, system text elsewhere, and the references you attached lean typographic.

- **(Recommended) System serif, "New York".** Zero licensing, Dynamic Type for free, strong weight range, reads as a quiet studio rather than a startup dashboard. Pairs with SF for everything else.
- **Bundle an open-licensed serif** such as Fraunces or Instrument Serif (OFL). More character, slightly more work for Dynamic Type scaling.
- **A monospaced caption face** for labels (as in the sunset reference) alongside either option above. I would use SF Mono at small sizes for the "AI text" and metadata labels only, not for titles.

### Q4. How literally should the three reference images shape the UI?

I read them as follows and plan to use them this way unless you say otherwise:

- **Sunset app (grainy gradient, mono labels, small vertical gauges).** The grain-gradient hero becomes the header of an idea's detail view, tinted by lens (business = ember, growth = sage, creative = lavender) and intensity by Potential. The small vertical gauges become the per-criterion rubric control. Mono uppercase labels become the metadata style.
- **"Contexts" blob canvas.** Becomes an optional Vault view: soft colour fields grouped by lens and tag, idea titles floating inside. It is a second way to browse, never the default list. It is also the visual language for Pitch clusters later.
- **Brand slider spectrum.** Becomes the Compare view (two ideas, same lens, two paths across the six criteria) and the single-evaluation summary where the path across criteria makes shortfalls visible at a glance.

Tell me if any of these three is wrong, or if the images were mood only.

### Q5. Is a voice transcript "original text" the moment it is captured?

The brief makes `originalText` immutable after create. Speech-to-text is imperfect, so a transcript often has errors you would want to fix.

- **(Recommended) Editable until the first save, immutable after.** Voice capture shows the transcript with a short correction window; tapping Save freezes it. The audio file is kept alongside as the true original.
- **Immutable immediately, corrections go in a separate `correctedText` field.** Purest reading of the brief; clumsier to use.

---

## 2. Phase 0 file tree

Phase 0 is done when the app launches on device with empty states on all three tabs, dark mode works, and the tests for scoring, lens integrity, idea immutability and evaluation append-only pass. Models for later phases are created now, empty, so the schema never has to migrate mid-build.

```
Forge/
├── README.md
├── .gitignore
├── project.yml                         # XcodeGen spec (see Q1)
├── docs/
│   ├── FORGE_BRIEF.md                  # source of truth
│   ├── 00-first-deliverable.md         # this file
│   └── decisions/                      # one short file per decision that needed the developer
│
├── Forge/                              # app target
│   ├── ForgeApp.swift                  # @main, ModelContainer, root tabs
│   ├── Config/
│   │   ├── Base.xcconfig               # bundle id, versions
│   │   ├── Local.xcconfig.example      # PROXY_URL, PROXY_TOKEN placeholders
│   │   └── Info.plist                  # mic + speech usage strings
│   │
│   ├── App/
│   │   ├── RootTabView.swift           # Home · Vault · Workshop
│   │   ├── AppEnvironment.swift        # services injected via Environment
│   │   └── Navigation.swift            # typed routes per tab
│   │
│   ├── Models/                         # SwiftData, CloudKit-ready (all optionals / defaults)
│   │   ├── Enums.swift                 # LensType, Stage, Origin, SourceKind, SourceClass,
│   │   │                               #   ProjectStatus, PitchCluster, PitchStatus, Recommendation
│   │   ├── Idea.swift                  # originalText is `let`-like: set in init only
│   │   ├── OpportunityFilter.swift
│   │   ├── Exploration.swift
│   │   ├── Evaluation.swift            # versioned; new version per re-evaluation
│   │   ├── CriterionScore.swift        # key, score 1–5, evidenceLevel 0–5, note, evidence[]
│   │   ├── Evidence.swift
│   │   ├── Experiment.swift
│   │   ├── Source.swift
│   │   ├── SourceChunk.swift           # citation anchoring
│   │   ├── LibraryArtifact.swift
│   │   ├── Project.swift
│   │   ├── Milestone.swift
│   │   ├── ProjectTask.swift           # named to avoid clashing with Swift's Task
│   │   ├── Decision.swift
│   │   ├── Pitch.swift
│   │   ├── Advantage.swift
│   │   ├── Constraint.swift
│   │   ├── Round.swift                 # §6C: one panel session on an idea
│   │   ├── Verdict.swift               # §6C: sphere, onTrack|offTrack|cantTell, criterionKey, sources
│   │   ├── Crossfire.swift             # §6C: one reply per sphere pair
│   │   ├── Ruling.swift                # §6C: agree|disagree|findOut + what it produced
│   │   ├── StewardCharter.swift        # §6C: user-written, placeholder until Phase 5
│   │   └── ForgeSchema.swift           # VersionedSchema + migration plan stub
│   │
│   ├── Content/                        # static lens content; no UI code here
│   │   ├── LensContent.swift           # Lens, Criterion, Rubric, LadderRung, Playbook types
│   │   ├── Lenses.swift                # registry: Lens.business / .growth / .creative
│   │   ├── LensA_Business.swift        # A1–A6 (A2 authored now, rest in Phase 3)
│   │   ├── LensB_Growth.swift          # B1–B5 stubs, authored in Phase 5
│   │   ├── LensC_Creative.swift        # C1–C5 stubs, authored in Phase 5
│   │   ├── Spheres.swift               # §6C panel: what each Sphere judges, cites, refuses
│   │   ├── OpportunityFilterQuestions.swift
│   │   └── ReflectivePrompts.swift     # Home prompt pool
│   │
│   ├── Domain/                         # pure logic, no SwiftUI, no SwiftData imports
│   │   ├── Scoring.swift               # potential(), confidence(), normalize()
│   │   ├── Shortfalls.swift            # lowest criteria → "what would have to be true"
│   │   └── Triage.swift                # Opportunity Filter red-flag rule
│   │
│   ├── Services/
│   │   ├── AI/
│   │   │   ├── AIClient.swift          # protocol + typed actions (expand, challenge, …)
│   │   │   ├── AIContracts.swift       # Codable JSON output contracts per action
│   │   │   └── OfflineAIClient.swift   # Phase 0 stub: returns .offline
│   │   ├── Capture/
│   │   │   └── SpeechCapture.swift     # stub; Phase 1
│   │   └── Persistence/
│   │       └── ModelContainer+Forge.swift
│   │
│   ├── Design/
│   │   ├── Tokens/
│   │   │   ├── ForgeColor.swift        # warm neutrals, ember accent, lens tints; light + dark
│   │   │   ├── ForgeType.swift         # display face for titles, system text, mono labels
│   │   │   ├── ForgeSpacing.swift
│   │   │   └── ForgeMotion.swift       # settle/slide curves; honours Reduce Motion
│   │   ├── Components/
│   │   │   ├── IdeaCard.swift
│   │   │   ├── EmptyState.swift
│   │   │   ├── SparkGlyph.swift        # marks AI-generated text
│   │   │   ├── EmberButton.swift       # capture / next step
│   │   │   ├── GrainGradient.swift     # header material (reference image 1)
│   │   │   └── Ring.swift              # Potential / Confidence ring (shell only in Phase 0)
│   │   └── Assets.xcassets/            # AppIcon, AccentColor, named colours with dark variants
│   │
│   ├── Features/
│   │   ├── Home/HomeView.swift         # empty state only in Phase 0
│   │   ├── Vault/VaultView.swift
│   │   ├── Workshop/WorkshopView.swift
│   │   ├── Capture/CaptureSheet.swift  # shell; wired in Phase 1
│   │   └── Spheres/                    # Phase 3: Round, verdict cards, crossfire, rulings, summary
│   │
│   ├── Resources/
│   │   └── Localizable.xcstrings
│   └── PrivacyInfo.xcprivacy
│
├── ForgeTests/
│   ├── ScoringTests.swift              # potential, confidence, normalization, edge cases
│   ├── LensContentIntegrityTests.swift # every criterion has definition, 1/3/5, ladder, playbook
│   ├── IdeaImmutabilityTests.swift     # originalText cannot change after insert
│   ├── EvaluationAppendOnlyTests.swift # re-evaluate creates version n+1, never mutates n
│   └── TriageTests.swift               # ≥3 "no" → suggests explore/revisit
│
└── proxy/                              # Phase 2; folder reserved
    └── README.md
```

### Data model additions from §6C (Spheres)

Created empty in Phase 0 so the schema is complete from the first build. UI arrives in Phase 3.

```
Round           id, idea, pitchText, createdAt, verdicts[], crossfire[], rulings[], summary
Verdict         id, round, sphere, kind (onTrack|offTrack|cantTell), criterionKey,
                reason, sources[] → Source, evidenceNeeded?
Crossfire       id, round, fromSphere, toSphere, text
Ruling          id, verdict, choice (agree|disagree|findOut), note?,
                resultingDecision? → Decision, resultingEvidence? → Evidence,
                resultingAssumption? → Source(class: assumption), resultingExperiment? → Experiment
StewardCharter  id, text, updatedAt            (single row, edited in Settings)
```

`Sphere` is an enum in ForgeCore (`investor, customer, builder, strategist, skeptic, steward`). The panel's static content, what each Sphere judges, which frameworks bind it, and what it refuses to do, lives in `Content/Spheres.swift` next to the lenses, not in the database. "Challenge" is removed from the AI action list and replaced by `runRound`.

**Phase placement, confirmed:** Spheres ship in Phase 3 with the Evaluation Lab (Investor, Customer, Builder, Strategist, Skeptic). The Steward and its charter ship in Phase 5 with the Personal Growth lens. Sphere-voiced Pitches and Pivots are Phases 5 and 5b. Before the Phase 4 Library exists, verdicts will mostly be `cantTell`, which is the correct behaviour.

Decisions baked into this tree that the brief left open, and that I am making unless you object:

- Lens content lives in Swift, not JSON. Type-checked, testable, and the integrity tests become compile-time plus a unit test rather than a runtime parse.
- `Domain/` has no SwiftUI or SwiftData imports so scoring is trivially unit-tested.
- `Task` is named `ProjectTask` to avoid colliding with Swift concurrency.
- All SwiftData relationships are optional or have defaults, which is what CloudKit requires later.

---

## 3. Lens A · Criterion A2 — Demand evidence

Below is the content exactly as it will ship in `LensA_Business.swift`, in reading order as the UI presents it. Framework attributions appear in the UI, not only in code.

### Title

**Demand evidence**
Also called: commercial traction.
From: *The Mom Test* (Rob Fitzpatrick) · *The Lean Startup* (Eric Ries)

### Definition

Commercial traction is proof that people will give up something they value, time, attention, or money, to get this problem solved. Compliments are not traction. "That's a great idea" is worth zero.

This criterion asks one question: what have real people actually *done* about this problem? Not what they said they would do. Not what you believe they would do. What they did, with their calendar, their inbox, or their wallet.

It is the criterion most often faked by enthusiasm, which is why FORGE treats it differently from the other five. Everyone who describes their idea gets told it is good. That is politeness, not data. The Mom Test's rule is to talk about the other person's life and past behaviour and never pitch. The Lean Startup's rule is that an idea is a hypothesis until a measurable behaviour confirms it. Put together: demand is measured by behaviour, and ranked by how much that behaviour cost the person who did it.

### The evidence ladder

The ladder is the rubric. Your score on this criterion is the highest rung that **at least three independent people** have reached. One person at a high rung is a promising signal and FORGE will note it, but it does not move the score. Three is the minimum before a pattern is more than a story.

*Independent* means: not family, not close friends, not people who would say yes to be helpful, and not three people from the same conversation.

| Rung | What happened | What it is worth |
|---|---|---|
| **0** | I think it's good. | Nothing. This is where every idea starts, and there is no shame in it. It is just not evidence. |
| **1** | People said it's a good idea. | Nothing. FORGE will say so plainly. Compliments are what people give when they want the conversation to end pleasantly. Count them, then set them aside. |
| **2** | People described the problem without being led, or already pay for a workaround. | The first real rung. Someone volunteered the pain before you mentioned your idea, or you can point to money or hours they are already spending on a clumsy fix. This proves the *problem* is real. It does not yet prove they want *your* solution. |
| **3** | People gave time. | An interview about their past behaviour. A waitlist signup. A demo request. A reply to a cold message that asks a question. Time is the first thing people refuse to spend on things they do not care about. |
| **4** | People gave money. | A preorder. A deposit. A paid pilot, even a tiny one. A signed letter of intent. Money is the clearest signal there is, because it is the hardest thing to get from someone out of politeness. |
| **5** | People came back. | Renewed. Reordered. Referred someone else. Used the manual version a second time without being reminded. This is the only rung that proves the solution works, not just that the problem exists. |

### Rubric anchors

- **1 — Enthusiasm.** Rung 0 or 1. Nobody has done anything. You might be right. You do not yet know.
- **2 — Problem confirmed.** Rung 2 with three or more people. The pain is real and people are already paying for it somehow. Whether they would pay *you* is still open.
- **3 — Attention given.** Rung 3 with three or more people. Strangers have spent time on this. You have something worth testing with money.
- **4 — Money changed hands.** Rung 4 with three or more people. You have a business hypothesis with early proof. The risk has moved from "does anyone want this" to "can I deliver and repeat it."
- **5 — Repeat behaviour.** Rung 5 with three or more people. Demand is demonstrated. This criterion is no longer your riskiest assumption; look at distribution and economics instead.

On this criterion, and only this one, the score and the evidence level are the same number by design. You cannot score Demand evidence a 5 on feeling, because the rubric *is* the ladder.

### What does not count

FORGE will not let these raise the rung, and says why if you try to attach them:

- Likes, follows, upvotes, or views. Attention that cost nothing is rung 1 at best.
- "I would totally buy that." Future-tense statements are rung 1. Only past-tense actions count.
- Friends, family, and anyone who would be uncomfortable saying no.
- Your own excitement, however strong.
- AI summaries or AI-found sources you have not read yourself. These sit in the Library as `ai-found` until you mark them reviewed; then they can support rung 2.
- A competitor's existence on its own. That proves the category is paid for, which supports rung 2, but it says nothing about rungs 3 to 5 for your idea.

### How to find it this week

Ordered from cheapest to most demanding. Each step names the highest rung it can reach, so you can pick the step that moves the score rather than the one that feels productive. Save every hit as a Library source and tag it with its rung.

**Desk research (rung 2 ceiling, about an afternoon)**

1. **Find who already gets paid.** Search for products or services that solve this problem today. Save their pricing pages. If people are paying, the problem is real. Save their one-star reviews too; those are the complaints nobody has fixed, and they feed criterion A3 as well.
2. **Check search volume.** Type the problem, not your solution, into Google and watch autocomplete. Use Google Trends and the free Keyword Planner for the top three phrases. Volume is a rough proxy for how many people are actively looking.
3. **Read the complaint threads.** Reddit, Facebook groups, niche forums, G2 and Capterra reviews. Search for "how do you deal with," "is there a tool for," "anyone else frustrated by." Save threads where people describe their workaround in detail. Each distinct person is one toward your three.
4. **Look at job postings.** If companies are hiring someone to handle this problem by hand, companies are already spending on it. Search LinkedIn and Indeed for the task, not the title.

**Conversations (rung 2 to 3, this week)**

5. **Have five Mom Test conversations.** Talk to people who might have the problem about their life, not your idea. Ask: "When did this last come up?" "What did you do about it?" "What did that cost you?" "What else have you tried?" "Who else has this?" Never ask "would you use this?" If they describe the problem and a workaround unprompted, that is rung 2. If they ask to see what you are building, that is rung 3. Write down what they said in their words, as a Library source.
6. **Send twenty cold messages.** Short, specific, about their problem, not your product. Record every reply. Replies with a question in them are rung 3. Silence is data too; it tells you the problem is not top of mind for that group.

**Small public tests (rung 3, one to two weeks)**

7. **Landing page plus waitlist plus fifty dollars of ads.** One page, one promise, one email field. Send a small amount of paid traffic from where these people already are. A signup is rung 3. Be honest on the page that it is not built yet.
8. **Fake-door test, disclosed.** A "Get started" button that leads to "Not ready yet. Leave your email and I'll tell you when." Ethical only if you tell them on that page. Each email is rung 3.

**Money tests (rung 4, two to four weeks)**

9. **Sell the manual version to one customer.** Before building anything, do the job by hand for one person and charge for it. This is the single most informative test on the ladder: it reaches rung 4 and teaches you exactly what the product has to do. If you cannot find one person to pay for a manual version, no amount of software will change that.
10. **Take a deposit or preorder.** Even a small, refundable one. Or a signed letter of intent from a business buyer. Three of these and the score is a 4.

**The one you have to wait for (rung 5)**

11. **See if they come back.** Did the manual-version customer ask for it again? Did a preorder customer refer someone? Did anyone use it a second time without a nudge? You cannot manufacture this rung. You can only set it up and watch.

### Raising the score

When this criterion is among the shortfalls, FORGE phrases it as: *"You're at rung N with M of 3 people. To reach rung N+1 you need…"* followed by the single cheapest step above that gets there. If the Recommended next move is *Test the riskiest assumption*, the Experiment card defaults to that step.

### What the AI partner may and may not do here

The AI can run the desk research steps (1 to 4) through the Library and save what it finds as `ai-found` sources. Those raise Confidence only after you read them and mark them reviewed. The AI can draft the five interview questions and the twenty outreach messages for steps 5 and 6. It cannot do steps 5 through 11 for you, and it will never claim rung 3 or above on your behalf, because those rungs are things real people did.

### Shape in code

For reference, the type this content fills. Every criterion in every lens uses the same shape, and `LensContentIntegrityTests` fails if any field is empty.

```swift
struct Criterion {
    let key: String                     // "A2"
    let title: String                   // "Demand evidence"
    let alias: String?                  // "commercial traction"
    let frameworks: [Framework]         // [.momTest, .leanStartup]
    let definition: String              // the prose above
    let rubric: Rubric                  // anchors for 1, 2, 3, 4, 5 (1/3/5 required)
    let ladder: [LadderRung]            // six rungs, 0...5, each with label, description, worth
    let doesNotCount: [String]
    let playbook: [PlaybookStep]        // ordered; each has title, body, reachesRung, effort
    let shortfallTemplate: String
    let aiBoundary: String
    let scoreEqualsLadder: Bool         // true only for A2
}
```

---

Waiting on the five answers (or "defaults") before Phase 0.

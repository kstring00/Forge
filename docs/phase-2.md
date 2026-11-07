# Phase 2 — Core loop: Explore → next action → outcome

Done when: an idea can go from capture to a completed real-world action with a
recorded outcome, entirely without the Lab. Built from a Linux container; the
app target needs its first build on the Mac. ForgeCore's new prompt tests pass here.

## Built

- **Guided Explore.** Six prompts from the brief's Explore stage (problem, who, today, why, tiny, kills), each asked by a Sphere where one fits, shown as rows on idea detail with the answer or a hint. One answer per prompt, edited in place. The first answer moves the idea from Capture to Explore.
- **AI Expand and Summarize, confirm-before-save.** Two actions on the Explore section. The proposal is shown in full next to the user's original text and saved only on Accept, as separate confirmed "AI notes"; user text is never touched. With the Phase 0 offline client the action shows a calm offline note. A canned client exercises the whole flow in tests.
- **AI-sharing consent.** Shown once before the first AI action: what is sent, what is never sent, through which proxy, and that it can be withdrawn. Settings shows the same list, the date agreed, the proxy, and a withdraw button.
- **Make it real.** From idea detail: project name, what launched means, the one next step, and the Journal's commit entry (belief, why now, expected result, optional date). The idea moves to Build.
- **Minimal Workshop.** Project list grouped Active / Paused / Launched. Project detail with the next step as the only ember card, Done asks "what actually happened?" and for the next step, Pause and Mark launched ask the same question and record it against the open commitment, Resume. The originating idea is one tap away.
- **Decision Journal.** Entries on commit and on every outcome. Project detail lists its entries; a Journal screen off the Workshop lists everything newest first and lets an open commitment record its outcome. Nothing is scored.
- **Navigation.** Shared destinations so Home, Vault and Workshop can all open an idea or a project. Home's active workshop card opens the project.
- **Tests.** `WorkshopActionsTests` (commit, complete, pause, launch, idempotence), `ExploreActionsTests`, `ExploreAIControllerTests` (offline, propose, accept, discard, malformed), `ExplorePromptsTests` in ForgeCore.

## Deliberately skipped

- The proxy and the live AI client (Phase 3). The flow is complete; only the transport is a stub.
- AI title and summary proposals at capture time; Expand covers it from Explore for now.
- Milestones, tasks, decisions log UI beyond the Journal, launch retrospective (Phase 6).
- Journal calibration view (Phase 6). Phase 2 lists; it does not analyse.
- Archive from the Workshop; a paused project is enough for now.

## Needs the developer

1. **Regenerate and build.** Many new files. Run the scheme tests; the controller tests use the canned client.
2. **Walk the loop.** Capture an idea, answer two prompts, tap Expand (expect the offline note), tap Make it real, fill the commit, open the project from Home, tap Done on the step, record what happened, set the next step, then Mark launched. Open the Journal and check the commitment shows the expected result next to the outcome.
3. **Consent.** Tap Expand once with no consent: the sheet appears; Not now cancels without a call; Agree records the date in Settings; Withdraw clears it.
4. **Export** still round-trips (brief §12). The explorations and decisions were already in the export document.

# Backlog

Small asks from testing, waiting for the next code change. Newest first.

## Next up: the Home usability pass (brief agreed Nov 10, not started)

Starts only after #38 and #39 are merged, on a new branch off main, before #30. A refinement, not a redesign: the dark matte look, the orange accent, the orbs, the three stages, the five tabs and the mic button stay. It closes the two notes below marked **(Home pass)** and the Brief-rings note.

**Who it's for.** People with many ideas and little traction, often afraid their idea is bad. Home answers "what should I do next?" in one glance, "catch this idea" in one tap, "how are my ideas doing?" in one scroll. A coach showing the next step, not a report card.

**Two PRs.** (a) Overlap fixes: nothing under the status bar or Dynamic Island; content fades out behind the tab bar and the mic (don't fight the iOS 26 glass bar); the last row scrolls clear of both. (b) Rows, the next-move card, labels and empty states. A third PR may follow: the Ideas tab reusing the same rows (propose after Home, don't build).

**Home's layout.**
- A shorter sky header that keeps the checks pill and the settings button. The "What if…" capture field goes; the mic stays, and its sheet must clearly offer typing as well as voice.
- The stage tracker. Tapping a stage filters the list to that stage (from all ideas in it, not just the 8 showing); tapping again clears it.
- One "Your next move" card: the single most useful action across all ideas, one line on why, progress ("0 of 5 conversations"), and the only filled orange button on the screen.
- "Your ideas": up to 8 compact rows, then "See all N ideas" to the Ideas tab. No sort menu on Home.

**Rows.**
- Collapsed: the stage orb, the title (up to two lines), one plain status line, a chevron. The whole row is the tap target, at least 44 pt. Row text stays out of the mic's corner.
- Order: the next-move idea first, as a collapsed row with a small "Next" tag; then most recently worked on.
- Tap expands in place: description, Potential, Proof, the What-if, the idea's action (tinted or outlined, never filled), an "Open idea" link; any second action is a text link. One row open at a time.
- Which row starts open: the idea last worked on, unless that is the next-move idea, in which case none. With only one idea, its row is open. The app remembers the open row between launches: a row the person opened or closed by hand stays that way until they next work on a different idea, which then becomes the open one.
- Opening scrolls the title into view, with a short spring and a light haptic; a plain fade with Reduce Motion.
- A status line for every state an idea can be in ("Not checked yet", "Talked to 1 of 5 people", "Waiting on your decision", checking, check failed, offline…), all listed in the PR for review.

**Words and scores.**
- No boxes for nothing: when Potential, Proof or Est. return has no result, one line says what's missing and the next step. Est. return shows only with a real estimate (income ideas only; impact framing for the rest).
- On Home, the Potential word without the number, until the Potential fix lands. The number stays in the Brief as "4 of 100" with its word (fix the Brief's rings in this work).
- The lowest Potential band reads **"Unproven"** (temporary, until the Potential fix); show it in place before changing. Scoring itself doesn't change.
- Small all-caps lines become plain sentence case, at most one small label per row or card. Internal terms ("Ruled 0 of 5", "the panel's idea") become plain words; every wording change listed in the PR. Text-size floors from #25 stay.

**Titles.** New titles get up to seven words, cut at a word boundary, never ending on a connecting word ("for", "with", "of", "and"). Existing titles are left alone. Renaming by hand already exists (the title on the idea page is editable, and a renamed idea is never retitled by the panel). The panel also proposes a title with each check, asked for in 2 to 5 words by the proxy prompt; the app's own limit is what cut "Weekend site care for RV parks". Decided Nov 10: raise only the app's limit to seven; the proxy prompt stays as it is. A new check can still retitle an idea the person hasn't renamed, as today. Pin down the one-line "…" case with previews.

**States and access.** A friendly empty Home that points at the mic; loading, failed and offline states on the row. Dynamic Type to the largest accessibility sizes with nothing clipped; VoiceOver reads a row as one item with its state; spoken values for the ring and the ladder; contrast at least 4.5 to 1; stage never by colour alone.

**How.** Logic in ForgeCore with tests (which row starts open, the order, the stage filter, the status line per state). SwiftUI previews for every state, the largest text size, the iPhone SE and the Pro Max. Each PR carries a plain simulator checklist and the screenshots wanted back (iOS 26, and iOS 17 or 18).

**Done means.** With seven ideas, the next move and all seven titles fit in about two screens; a new user can say what to do next within five seconds; one filled orange button at rest; nothing overlaps on any supported phone at any text size; all of it works with VoiceOver and Reduce Motion.

**Not changed.** Colours, fonts, the orbs, the stages, the tabs; the check, scoring, plans, memberships, the proxy; the Ideas, Sparks, Plans and Journal tabs.

## Notes from testing

- **Five older app tests fail on the Mac (first full Cmd+U, Nov 9).** None is in code that #38 or #39 changed, so they fail on main too; app tests can't run on Linux, which is how they went unnoticed. To sort out in one small PR after #38 and #39 merge:
  - `WorkshopActionsTests` (logging a conversation): "she pays a nephew" is read as a payment (proof step 4) when it should be a conversation (step 3). **Possibly a real bug:** someone paying somebody else is not proof they'd pay you.
  - `ProjectCleanupTests` (merging duplicate projects): logged conversations are added together only when the two steps differ; the test expects them added when the steps are the same. Looks like a real bug in a one-time cleanup.
  - `PivotActionsTests` (a second tap on a What-if): making an idea from a What-if twice with the same card value makes two ideas. The app passes the updated card, so it likely doesn't show; worth hardening.
  - `RulingActionsTests`: expects the word "rung 2"; the app has said "proof level 2" since the legibility pass. The test is out of date.
  - `PrefillApplierTests`: expects Confidence 37, gets 27, since desk research was graded (decision 0037). The test is probably out of date; confirm.

- **Potential runs low and jumps around (Nov 9).** In the simulator two unrelated ideas scored 4 and 17, both "Long shot"; on the bench the same idea moved 15 to 25 points between runs. Before anyone talks to customers, Potential should say how big the idea could be, not how little is proven (that is Confidence's job). Look at the rubric anchors and how scoring treats "no customer evidence yet", then bench it. **Scheduled (Nov 10): right after #30 merges, before Under the Hood**, because See the Work will show each panelist's score. Target: a small swing between runs on the same idea, measured in the bench. Until then the Nov 9 sources fix counts as **unconfirmed** on a device: the simulator showed real pages cited, but two ideas scoring 4 and 17 proves nothing while one idea can move 15 to 25 points.

- **(Home pass)** **The Brief's rings still show a bare number (Nov 9).** `StripedRingCard` in `BriefSection.swift` draws Potential and Confidence its own way, without "of 100" or the word ("Long shot"). Switch it to `ScoreRing` like every other ring (decision 0038 follow-up).

- **(Home pass)** **Keep the idea you just worked on in reach (Nov 9).** After opening or working on an idea, it should sit in a special place at the top ("the idea you just worked on") instead of being buried in the list under everything else. Possibly each idea card collapsible, so the list stays short.

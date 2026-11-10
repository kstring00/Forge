# 0044 · The Home usability pass

**Date:** November 10 · **Status:** parts (a) and (b) built; both wait for a build and screenshots on Kyle's Mac

## Why

Home is the first screen, and in testing it had things sitting on top of each other: cards sliding under the clock and the Dynamic Island, text showing through the tab bar, and the capture button covering the right edge of whatever scrolled past it. It also took too long to say what to do next. Kyle and chat Claude agreed a refinement, not a redesign. This record keeps the agreed brief, what was built and why.

## What stays

The dark matte look, the orange accent, the orbs, the three stages, the five tabs, the capture button. Scoring, checks, plans, memberships and the proxy are untouched. The Ideas, Sparks, Plans and Journal tabs are untouched.

## Part (a): nothing overlaps

**What was wrong, and the cause.**

- **Cards under the clock.** Home lets its scroll area run to the very top so the sky can fill it. Nothing covered that strip once the page scrolled.
- **Text through the tab bar.** The app uses the standard tab bar. On iOS 26 and later Apple draws it as floating glass that content scrolls behind by design.
- **The capture button over text.** It floats over the bottom-right corner; the list only had space at its very end.

**What changed (Home only).**

- **A cover over the status bar.** At the top of Home the sky shows as before. As Home scrolls its first 40 points, a strip in the canvas colour builds over the status bar, with a soft 14-point edge under it. Rows pass behind it.
- **The header starts below the status bar on every phone.** It sits where the design had it (60 points down) or 6 points below the status bar or Dynamic Island, whichever is lower.
- **A fade above the tab bar.** Rows fade into the canvas colour over the last 104 points above the tab bar: the height of the capture button, the space under it, and 24 points of lead-in. They are half gone by the button's top edge and nearly gone by its middle. The canvas colour carries on behind the tab bar, so nothing shows through it.
- **The last row stops clear.** The list ends 112 points above the tab bar, above where the fade starts.
- **The tab bar itself is not restyled.** iOS draws it; the fade only decides what is behind it.

**Why a fade and not a solid bar.** A solid backing can't be forced reliably under the iOS 26 glass bar, and a hard edge above a floating button looks like a second bar. The fade works the same on iOS 17, 18 and 26.

**Where the rules live.** `HomeEdges` in ForgeCore holds the numbers (how solid the cover is for a scroll distance, where the header starts, the fade's height and stops, the list's end space), with tests. `HomeEdgeViews.swift` draws them. The cover's strength moves in tenths, so Home redraws at most ten times while it builds, not on every frame of a scroll.

**Not verified here.** The app only builds on Kyle's Mac. This needs his screenshots on a Dynamic Island phone and an iPhone SE, on iOS 26 or later and on iOS 17 or 18.

## Part (b): rows, the next move, plain words

**Who Home is for.** People with many ideas and little traction, often afraid their idea is bad. Home answers "what should I do next?" in one glance, "catch this idea" in one tap, and "how are my ideas doing?" in one scroll. A coach showing the next step, not a report card.

**Layout, top to bottom.**

1. **A shorter sky header:** the date, settings, "Have a hunch?", the checks pill. The "N ideas in motion" line is gone (the stages below say it). The "What if…" field is gone: the mic button is the one way to capture, and its sheet now says "Type your idea here, or tap Speak below".
2. **The three stages.** Tapping one filters the list to that stage, from every idea in it, not only the eight showing. Tapping it again, or "Show all", clears it. The chosen stage gets a ring, a tick and "Showing these", not only its colour.
3. **One "Your next move" card:** the idea, the move in plain words, one line on why, progress when there is a count ("1 of 5 conversations"), and the only filled orange button on Home. Which idea it is has not changed (`HomeCard.choose`).
4. **"Your ideas":** up to eight compact rows, then "See all N ideas", which opens the Ideas tab. No sort menu.

**Rows.**

- **Closed:** the stage orb, the title (two lines), one status line ("Reality · Talked to 1 of 5 people"), a chevron. The whole row is the button, at least 56 points tall.
- **Order:** the next-move idea first, tagged "Next"; then the most recently worked on. It used to be hidden from the list; now it is in both places, as agreed.
- **Open, in place:** the person's own first line, Potential and Proof as plain lines, the estimate only when there is one, the panel's What-if, the idea's action (tinted, never filled), and "Open idea". One row open at a time.
- **Which row starts open:** the idea last worked on, unless it is the next move (its card is right above), then none. With one idea, that idea. A row opened or closed by hand stays that way, across launches, until the person works on a different idea; that idea then opens.
- **Opening** scrolls the title into view with a short spring and a light tap; with Reduce Motion, a plain fade.

**A status line for every state.**

| State | The row says |
|---|---|
| Not checked | Not checked yet |
| Check running | The panel is checking it |
| Check failed | The check didn't finish. Try again. |
| Check failed, no connection | No connection. Try the check again later. |
| A personal idea (Growth or Creative) | Judged by what it changes for you |
| The panel answered, not opened yet | The panel's take is ready |
| Opened, nothing answered | Waiting on your decision |
| Part-way through the panel | You answered 2 of 5 panelists |
| All answered, nothing started | You heard the panel. Ready for a next step. |
| A step with a count | Talked to 1 of 5 people |
| A step without a count | Next step not done yet |
| The count is reached | Talked to all 5. Say what happened. |
| A single step done | Step done. Say what happened. |
| A commitment with no outcome | Waiting to hear what happened |
| Out in the world, no step | No next step set |
| Paused | Paused |
| Launched | Launched |

Each line is preceded by the stage in words ("Idea · ", "Formation · ", "Reality · "). A failed or offline check also shows a warning mark; a running check shows a spinner.

**No boxes for nothing.** The Potential and Proof tiles are not drawn on Home. A checked idea shows "Potential: Promising" and "Proof: Talked to 2" with what moves it next. An idea with no result shows one line saying what is missing and the step that fills it. The estimate shows only when there is a real one (or, for a personal idea, who it helps); "too early" is one small line, not a box.

**Words.**

- On Home, Potential is the word without the number. The number stays in the Brief, now as "4 of 100" with the word under the ring.
- **The lowest Potential band reads "Unproven"** (was "Long shot"), everywhere the word shows. Temporary, until Potential itself is steadier. Scoring is unchanged, and launch-plan requests still send the old word so plans read as before.
- Small all-caps lines on Home are now sentence case, with at most one small label per row or card. "Ruled 0 of 5" and "the panel's idea" are gone from Home; "Waiting on your ruling" is "Waiting on your decision".

**Titles.** New titles get up to seven words (was five), cut at a word, never ending on a connecting word ("for", "with", "of", "and", "along" and the like). Existing titles are left alone: the one-time clean-up only touches titles longer than the limit. The proxy still asks the panel for 2 to 5 words; a new check can still retitle an idea the person hasn't renamed.

**The mic's corner.** Row text is not re-flowed around the button. The fade from part (a) keeps text from showing beside it, and the list ends above it.

**Access.** A row is one VoiceOver item: title, "your next move" when it is, the stage, the status, and expanded or collapsed. The Proof line speaks its step of four. Text grows to the largest accessibility sizes: titles get four lines there, the orb shrinks, nothing has a fixed height. Stage and trouble are never shown by colour alone.

**Where the rules live.** `HomeRows`, `HomeRowState` and `PotentialBand` in ForgeCore (order, the stage filter, the open row, every status line, the next-move wording), with tests. `HomeRowsView.swift` reads the saved records into those values and draws them.

**Left for later.** The Ideas tab still draws the older full card with a filled button per card. Reusing Home's rows there is a proposal for after this lands, not built.

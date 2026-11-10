# 0044 · The Home usability pass

**Date:** November 10 · **Status:** part (a) built; part (b) next

## Why

Home is the first screen, and in testing it had things sitting on top of each other: cards sliding under the clock and the Dynamic Island, text showing through the tab bar, and the capture button covering the right edge of whatever scrolled past it. It also took too long to say what to do next. Kyle and chat Claude agreed a refinement, not a redesign. The full brief and every decision on it are in `docs/BACKLOG.md` under "Next up" until part (b) lands; this record keeps what was built and why.

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

## Part (b): next

Rows that expand in place, one "Your next move" card with the only filled orange button, the stage filter, plain labels, empty and failed states, titles up to seven words, the lowest Potential band's word, and the Brief's rings. As agreed in the brief.

# 0036 — One primary action, and orange only for it

Recorded 2026-11-08: calls to action were unclear.

- **Orange (`ember` / `emberText`) is only for tappable actions.** Verdict words on cards are
  neutral mono labels; the verdict's colour lives on the Brief and the Deal. Card labels,
  borders, progress segments and the Est. return figure are neutral.
- **One primary per card**, full width, 44 pt, at the bottom, verb first, from the idea's state
  (`CardAction.of`): no panel → *Get the panel's take*; panel spoke, no deal → *Hear the panel*;
  step in progress → *Log a conversation · N of M*; target reached or a commitment without an
  outcome → *What happened?*; in Reality with no step → *Set your next step*; Growth or Creative,
  not checked → *Make it real*; launched, paused, archived → none. *See signups · N so far* is
  defined for when test pages exist (engine step 6). A running check shows "The panel is on it"
  with Stop instead.
- **Everything else is secondary:** outlined, neutral, 44 pt (`SecondaryButtonLabel`). The
  panel's take card's *Check again*, *Questions*, *Mark the step done*, *Log another*.
- **The same rule on the next-move card, the idea page and the Reality page:** the journey
  bar carries the idea page's one primary (the capture-state button is gone; the card shows
  only progress while a check runs); the next-step card carries the Reality page's.
- **Est. return empty states fit one line:** "No price found yet", "Get the panel's take to
  estimate".
- **Lists end above the capture button:** bottom padding is its 64 pt, its 16 pt inset, and 16
  pt more (`ForgeSpacing.dockClearance`) on Home, Ideas and Journal.
- **Home header:** the sort is a neutral icon-only menu; "All" is the one orange element.
- Not changed: the stage colours (Reality's band and pipeline node are ember as the stage's
  identity) and the Membership screen.

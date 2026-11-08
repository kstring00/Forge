# 0016 — Nothing is sent without a confirm; no prices in the UI; Home · leveled up

Recorded 2026-11-08, after the first run of the v4.2 restructure.

- **Every proxy call opens `AIConfirmSheet` first** (Reality Check, Expand, Summarize,
  re-score): what will happen, how long it takes, the "your idea text is sent to an AI
  model through your proxy" line, Send and Cancel. Send also records the one-time
  consent Settings shows; the first sheet carries the full what-is-sent list. The
  earlier first-run consent sheet is gone. "Don't ask again" from the artboard is left
  out on purpose: the bug was an accidental run.
- **A free guard runs on the phone before the sheet** (`IdeaGuard`): under eight words,
  or no problem word and no person word, blocks the check with one line and no call.
  A personal idea that names neither is blocked too; its way past the panel is the lens
  menu (Growth and Creative are judged by impact).
- **Stop.** The working card has a Stop button. The runner runs as a cancellable task
  and checks for cancellation after every proxy call; on Stop it deletes the Library
  sources this run saved, reports the step it stopped in, and whether anything was
  charged (the number lives in Settings → Spend). Stopped shows on the card like a
  failure until dismissed.
- **No prices anywhere but Settings → Spend.** The button line reads "Runs on AI · your
  idea text is sent to the model." The pill reads "To the panel". The Brief's cost line,
  the failure messages' dollar figures and the over-ceiling figures are gone. Brief
  §0A's rule becomes "cost is tracked, not shown" until credits (Phase 8).
- **A real-world step outranks a ruling** on Home. Priority: just captured, failed check,
  step owed, Brief to hear, unchecked.
- **Counts agree.** One `Idea.track`: a project means Reality whatever the stored stage
  says. The strip, the tabs and the Idea list all use it.
- **The step's count comes from the step.** `NumberWords` reads one through twenty and
  digits ("Talk to five parents" → 5), then the drafted asset's kind, then one.
- **No raw ids in prose.** `IDScrub` replaces any UUID the model wrote into text with
  the source's title, or removes it, at prefill-apply time; the prompt says so too.
- **Council arc** verdict block sits lower, under the top orbs' labels, at 390 pt.
- **Theme.** `preferredColorScheme` stays; the window's `overrideUserInterfaceStyle` is
  set too, so presented sheets and UIKit chrome follow Dark by default.
- **Home · leveled up** replaces the overview: grainy sky header with the live subline,
  glowing pipeline nodes with one-line statuses, the next-move card with "What's riding
  on it" (`StakesPanel`: 56 pt rings, Projection or Impact, the generated riding line),
  "What if…" capture, and "Your ideas, by stakes" (`StakeCard`, sorted by projection then
  Confidence). The three per-track sections are gone; the tabs hold the full lists.

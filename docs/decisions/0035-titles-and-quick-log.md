# 0035 — Short titles, a clearer Done, and quick log by default

Recorded 2026-11-08, from testing the interview sheet (decision 0030).

- **Every idea has a short title, 2 to 5 words**, separate from the person's words.
  `ShortTitle` (ForgeCore) makes one at capture from the first clause, filler stripped
  ("If what if there was an app that…" → "App that helped me gauge"). The prefill proposes a
  better one (`title`, at most five words, enforced on the proxy) and the applier takes it
  unless the person renamed the idea (`Idea.titleEdited`, set by the idea page's title
  field). Cards show the title with the person's first line as one muted line under it.
  `LegacyCleanup` v3 shortens existing titles over five words, once, leaving typed ones alone.
- **Done is clearer.** It needs a name ("Who was it?"); after Save the sheet shows "Saved: 2
  of 5 answered · Gave time" with Close and Start the next conversation, never a blank sheet.
  The Conversations list opens past interviews; current and past share one sheet.
- **Quick log is the default.** Log a conversation opens one field, "Who did you talk to,
  and what did they say?", with the mic. The rung is read from the words (never below Gave
  time) and can be changed; Save makes the verified source, advances the count and writes
  the Journal line, then confirms. The question-by-question sheet stays behind Questions.

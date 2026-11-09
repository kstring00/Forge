# 0038 — Cards speak in words and shapes; the panel's best What-if is on the card

Recorded 2026-11-09, after "Potential 4" read as four out of five and "proof 20" meant nothing.

- **No bare numbers on cards.** Two tiles under the title, full width:
  *Potential*: a word (Long shot · Modest · Promising · Strong · Big, from the 0–100 score in
  fifths) over five segments, captioned "the panel's view" (or "your score" only when the
  person changed a score themselves, not when a logged conversation moved one).
  *Proof*: a word ("Desk only", "Talked to 2", "Someone paid") over a four-step ladder (desk ·
  talked · signups · paid), captioned with what comes next or "Up today · Dale" for a day after
  it moves. The numbers live on the Brief with their breakdown.
- **The panel's best "What if…" is on the card** when the check has one not yet turned into an
  idea: the sentence in italic serif, "Raises <criterion> · the panel's idea", opening the
  Brief. Checks made before decision 0024 have none until they are checked again.
- **One card everywhere.** Home's "Your ideas" uses the same card as the Ideas tab.
- **Free sees the first What-if on every Brief;** the rest are Plus. Recorded in
  `docs/PRICING.md`.
- **Fixed:** during "Replay first run", leaving the welcome brought it straight back, so
  neither button could get past it. The replay now keeps its own "welcome seen".

## Follow-ups (decision 0039, same PR)

- **Proof has the same four steps as "What did they give?"**: desk research · gave time
  (talked, or signed up) · paid · came back. The tile's caption says "step 2 of 4 · next: a
  payment". Tapping either tile opens what it means: Proof shows the four steps with "You are
  here"; Potential shows the six criteria the word comes from, as the panel scored them.
- **"What did they give?" is full-width rows** with the word and a line of what it means
  ("Gave money · Paid, or put money down"), on the outcome sheet and the interview's Done,
  never truncated chips.
- **Text fields in sheets take focus after the sheet settles** (450 ms), not in onAppear,
  which could leave a cursor that took no typing. The outcome sheet's step reads as a
  statement, not a title.
- **Home's title is "Have a hunch?"**

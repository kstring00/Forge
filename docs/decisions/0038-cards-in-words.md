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
- **No "proxy" anywhere a user reads.** The app runs its own server; people who download it
  never set one up. The confirm sheet says the idea goes "to an AI model through Hunch's
  server, only for this check"; error messages say what happened in plain words ("Hunch
  couldn't reach the panel just now") and keep the developer detail (tokens, status codes,
  Vercel logs) behind Details; the server address in Settings shows only in Debug builds; the
  "what is sent" list drops its phase numbers.
- **No "desk" on cards.** Proof's first step is "Not tested yet" on the card and "Looked up
  online" in the four steps; "desk research" elsewhere in the app reads "online research".
- **Nothing that matters is cut off.** Labels carrying lists ("Criteria · The Mom Test, The
  Lean Startup, …", a criterion's frameworks) become a short label plus a wrapping sentence
  ("Drawn from …"). Words on cards, tiles, buttons, the checks pill, source titles and the
  Hear-the-panel source line wrap to two or three lines instead of ending in "…". Still one
  line on purpose: an idea's own words under its title, step counts, and web addresses.
- **Membership opens on Monthly**, and both tabs quote the same yearly Plus: the founding
  price ($39.99) for testers, the regular one ($59.99) for everyone else, with "Yearly · save
  N%" computed from whichever is offered. `docs/PRICING.md` stays the source of truth.
- **Settings is App Store shaped.** Membership; AI and privacy (consent, withdraw, what is
  sent, privacy policy); what the panel knows about you; backup ("Export your ideas"); look
  and feel (appearance, daily quote); About (Send feedback to kyle@stringhamwebdesign.com with
  the app and iOS versions in the email, Terms of use, version). The server address, the cost
  cap, the dollar figures and data counts moved under Developer, Debug only. The $10 cost cap
  no longer stops a check in App Store builds; the check allowance and the server's daily
  ceiling do. "FORGE" no longer appears anywhere a user reads; it says Hunch.

**Follow-up (Nov 9): the Proof tile names the next step.** The four dots say where proof is; on their own they don't say what to do. Under the dots the tile now says "Next: …": the idea's own step when one is set ("Next: Call Shady Oaks"), otherwise the move the next rung needs (talk to 3 people who'd buy it → ask one of them to pay → get them to come back → find five more like them). The Proof explainer sheet repeats it as its own "Next step" box. "step 2 of 4" moves to VoiceOver only.

**Follow-up (Nov 9): "What's riding on it" never cuts text off.** The panel is three equal columns split by hairlines (Potential ring, Proof ring or the magnifier, Est. return), each label on its own lines and free to wrap; the Est. return column stacks label, figure and basis, with "Too early to estimate" in italic serif. A hairline, then the step's line in serif at 18 pt. The last one-line labels (the stage line on Home's cards, "Up today") wrap too; the original-words excerpt on cards shows up to three lines.

**Follow-up (Nov 9): one ring for every score, always "of 100".** "4" read as 4 out of 5. `ScoreRing` draws every Potential and Confidence: the number in the middle and "of 100" under it when there is room (56 pt and up), with the word ("Long shot", "Promising") beside or under it. Used on the card's Potential tile (46 pt, caption "out of 100 · the panel's view"), the panel's take card (Potential ring and Proof ring, or the magnifier and "Not tested yet"), "What's riding on it", and the Lab's ring cards.

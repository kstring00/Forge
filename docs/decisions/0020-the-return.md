# 0020 — The return: what comes back from the world is verified evidence

Recorded 2026-11-08. Public name noted: the app ships as **Hunch**; the repo, brief and
code keep FORGE.

- **Every report from the world is a user-verified Source** (`FieldEvidence`): a logged
  conversation, what happened when a step was done, a launch, an outcome recorded in
  the Journal. Spoken reports keep their recording as the Source's file. The Source is
  attached as Evidence to the criterion the step is testing (`Project.nextStepCriterionKey`,
  set at Looks right from the evaluation's ladder criterion, A2 on Business).
- **The rung comes from what the person did**, inferred from the words
  (`RungInference`: 3 gave time, 4 gave money, 5 came back; negations step down) and
  confirmed by the user on the sheet. A logged conversation is never below 3. Below 3
  the words are saved and nothing is claimed on the ladder.
- **User-verified evidence is not bound by the desk ceiling.** The criterion's rung rises
  to the report's; one person per report counts toward A2's three; A2's score follows
  the ladder; `aiProposed` clears; Confidence recomputes and can pass 2 here and nowhere
  else. A rung-4 payment counts toward the Projection's verified units, so the Est.
  return row, the flame's rings, the Confidence ring and "What's riding on it" all move
  from the same records.
- `OutcomeSheet` takes a `FieldEvidence.Report`; `VoiceNoteField` is the shared
  type-or-speak field. Pausing asks no rung.
- Not in this PR: the partial re-run of the Spheres the new source touches, with its
  diff and confirm sheet; voice on "I know something you don't". Each is its own PR.

**Follow-up (Nov 10): what a logged conversation counts as.** Found when the app tests first ran in full on the Mac (they can't run on Linux).

- **Paying someone else is not a payment for this idea.** "She pays a nephew" was read as "Gave money" (proof level 4), because the word "pays" was enough. Now a sentence whose only payment goes to someone else ("pays a nephew", "paid their agency", "pays someone") counts as a conversation (level 3). A sentence that names the payment ("paid a $149 deposit") or pays "me" or "us" still counts as money. The rule is `RungInference.withoutPaymentsToOthers`, tested in ForgeCore. It is a reading of the words, so it can be wrong; the person can always change it on the sheet.
- **The person's pick decides.** The "Counts as" menu on the log sheet let you lower the level, but the saved record kept the higher one read from the words while the screen said the lower. `WorkshopActions.logConversation` now saves what the person chose, never below 3 for a conversation.

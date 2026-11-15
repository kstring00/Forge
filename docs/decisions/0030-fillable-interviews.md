# 0030 — Fillable interview questions

Recorded 2026-11-08.

- **Questions opens an interview** (`InterviewSheet`): "Who did you talk to?" (a name or
  nickname, and who they are), then each question with a typed answer and a mic
  (`VoiceNoteField`). Resume picks up the open draft.
- **Questions are the user's.** Seeded once from the panel's drafted asset
  (`InterviewQuestions.parse`: numbered or bulleted lines, or lines ending in "?"), or five
  Mom Test questions when there is none. Editable, reorderable and deletable in a list;
  answers follow their questions. Share or copy the list as plain text.
- **Drafts save themselves** as values on the project (`Project.interviews`); empty drafts
  are not kept; Discard draft removes one.
- **Done is one logged conversation.** The rung is confirmed (time, money, came back; never
  below 3), the transcript becomes a user-verified Source on the step's criterion through
  `logConversation`, the count advances, the Journal gets its entry, and the interview stays
  under the step ("Conversations · N"), opening read-only with Share.
- Tests: `InterviewTests`.

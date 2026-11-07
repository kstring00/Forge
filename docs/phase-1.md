# Phase 1 — Capture & Vault

Done when: ten ideas can be captured by voice and text and found again.
Built from a Linux container; the app target needs its first build on the Mac,
and the voice path needs a real iPhone (the simulator has no microphone input
and usually no on-device speech model).

## Built

- **Voice capture.** `SpeechCapture` records to a local `.caf` in Application Support/Recordings while streaming a live transcript from the Speech framework. On-device recognition is required when the device supports it, so it works offline. Input level drives a soft ember dot, not a waveform.
- **Transcript correction window (decision 0005).** Dictation appends to whatever was typed. After Stop the text is editable; Save freezes it as `originalText` and stores the recording's file name on the Idea. Cancel or swipe-dismiss deletes the recording. Swipe-dismiss is blocked while recording.
- **Paste.** SwiftUI `PasteButton`, so there is no clipboard permission banner.
- **Vault.** Search across title, original text, notes, AI summary and tags; every term must match. Filter by lens, stage, tag, and an archived view. Sort by recently captured, recently updated, Potential, Confidence. Score sorts fall back to "updated" unless a lens is chosen, so ideas are never ranked across lenses (§4.5). Active filters show as removable chips. Count label. Archive with a confirmation dialog from a context menu; bring back from the archived view. No delete anywhere.
- **Idea detail.** Grain header tinted by lens, editable serif title, lens and stage pickers, the original text in a locked card with a play button when a recording exists, tags as a comma-separated field, notes, timestamps, archive from the toolbar menu.
- **Home.** Floating capture button now appears only on the Vault; Home keeps its Quick Capture card. Cards on Home open the idea.
- **Tests.** `VaultFilterTests` covers search, filters, the archived view, sort rules and the cross-lens guard; archive and unarchive keep the original text.

## Deliberately skipped

- Compare two ideas (Phase 5).
- Opportunity Filter chip on cards (Phase 3; the card already shows "Screened" once a triage exists).
- Convert to project (Phase 6).
- AI title and summary proposals (Phase 2).
- Image or PDF capture (Phase 4, as Library sources).
- A waveform. The brief asks for calm; a level dot is enough.

## Needs the developer

1. **Build and run the scheme tests.** New SwiftData-backed tests in `VaultFilterTests`.
2. **Voice on a real iPhone.** On device: tap Speak, allow both permissions, talk, Stop, correct a word, Save, then open the idea and play the recording. Also try Cancel mid-recording and confirm no file is left behind.
3. **The ten-idea check from the brief.** Capture ten ideas, half by voice, then find each by search, by tag and by lens.

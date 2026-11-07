# 0005 — Voice transcripts: editable until first save, then immutable

Decided 2026-11-06. Voice capture shows the transcript with a correction
window; tapping Save freezes it as `originalText`. The audio file is kept
alongside (`Idea.audioFileName`) as the true original. Implemented in Phase 1.

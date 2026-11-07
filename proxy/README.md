# FORGE proxy (Phase 2)

Vercel Edge Function, TypeScript. Holds the Anthropic API key, enforces rate
limits, validates every model response against the typed JSON contracts in
`Forge/Services/AI/AIContracts.swift`, returns fetched pages as text snapshots
for the Library, and runs TTS for audio briefings.

The app authenticates with a long random bearer token set in
`Forge/Config/Local.xcconfig` (git-ignored). Nothing here yet.

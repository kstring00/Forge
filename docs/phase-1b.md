# Phase 1b — Export & backup

Done when: an export can be re-imported into a fresh install. Built from a
Linux container; the app target needs its first build on the Mac.

## Built

- **Export document.** A versioned, plain-Codable shape (`VaultExportDocument`, schema 1) covering every model: ideas with their original text, triage, explorations, evaluations (criteria, evidence, experiment), sources and chunks, artifacts, rounds (verdicts, crossfire, rulings), reality checks and competitors, projects with milestones and tasks; plus top-level decisions, pitches, advantages, constraints and the Steward charter. Every ID is preserved. Enums are written as raw strings.
- **Export folder.** `FORGE Export <date>/` containing `vault.json` (pretty-printed, sorted keys, ISO-8601 dates), `vault.md` (a readable rendering, one section per idea with the original text quoted), and `recordings/` with every voice file an idea references. Shared from Settings with the system share sheet, so it can go to Files, AirDrop or anywhere else.
- **Import.** Pick the export folder, or a lone `vault.json`, from Files. Additive and idempotent: records whose IDs already exist are skipped, nothing is overwritten or deleted. Relationships are resolved by ID in dependency order (sources, ideas, evaluations, projects, decisions, rounds, pivots, pitches, constraints). Recordings are copied back for newly imported ideas. A newer schema version is refused with a plain message.
- **Settings screen.** Reached from the gear on Home. Backup section with Export, Share and Import, the Vault counts, and the version.
- **Tests.** `VaultExportTests` builds a graph that touches every model, exports it, imports it into a fresh in-memory store and checks the graph came back whole, including the original text byte for byte, the evaluation's version and scores, evidence pointing at the right source, a ruling pointing at the right decision, the pivot link, and the project tree. A second import changes nothing. Markdown and the written folder are checked too.

## Also on this branch: design tokens for brief v3.1

Dark default theme with the brief's exact hex tokens, an Appearance setting, serif
numerals and italic serif original text with the ember rule, pattern fills for
evidence, orb Spheres, and a stage-driven sky header. See `docs/decisions/0008-brief-v3-1-design-tokens.md`
and `docs/design/`. Check on first launch: the app opens dark, the Vault cards sit
on #272320 over #1C1916, and only capture controls are ember.

## Decisions made here

- **A folder, not a zip.** Foundation has no zip reader on iOS, and a dependency for it would be the app's first. A folder shares and re-imports cleanly through Files and avoids base64-inflating recordings into the JSON.
- **Import never merges into an existing record.** Simpler to reason about and impossible to lose data with. If a future need arises, "replace" can be a separate, explicit action.
- **`Evaluation.restore` is internal and refuses finalized instances**, so append-only stays enforced outside the import path.

## Deliberately skipped

- Import from other apps' formats.
- Scheduled or automatic backups. The brief forbids nags; a visible Export button is the contract.
- iCloud Drive as a destination beyond what the share sheet offers.

## Needs the developer

1. **Build and run the scheme tests.** `VaultExportTests` is the big one.
2. **Round trip on the simulator.** Settings → Export Vault → Share → Save to Files. Delete the app, reinstall, Settings → Import → pick the folder. Every idea should be back, including tags and notes, and the Vault counts should match.
3. **Export is now part of every phase's check**, per brief §12. The test above runs it; the manual round trip is worth repeating after Phase 2 adds Journal entries and projects.

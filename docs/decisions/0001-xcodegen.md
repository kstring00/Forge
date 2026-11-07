# 0001 — Project generation: XcodeGen

Decided 2026-11-06. `project.yml` is committed; `Forge.xcodeproj` is generated
locally with `xcodegen generate` and git-ignored. Rationale: reviewable YAML,
no pbxproj merge conflicts, reproducible from a Linux container.

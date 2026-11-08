# 0022 — Salvage, don't reject

Recorded 2026-11-08, after the first Reality Check on the app's own idea failed on one
unsourced competitor ("competitors.2.sourceID: expected string, received undefined").

- **Item by item.** When the model's answer fails the contract, `salvage` first fills the
  nullable fields an item may omit (`sourceID`, `url`, `evidenceNeeded`, `experiment`,
  `sphere`) with null, then removes the list items the remaining issues point at (the
  deepest list index on each issue's path) and parses again, up to six rounds. The run
  fails only when a required top-level field is missing or wrong.
- **Unsourced findings are dropped, never shown as fact.** `enforceRealityCheck` now
  removes competitors and demand signals whose source id is missing or unknown instead of
  nulling the id, and counts them. The envelope carries `dropped` by list; the app keeps
  the total on the check (`droppedFindings`) and says under "What we found" that N
  findings had no source and were left out.
- **One retry with the errors.** If salvage cannot produce a valid object, the model is
  asked once more with the validation issues listed; only then does the run fail, with
  the technical detail in the log and the error body (`X-Forge-Mode: json-retry` marks
  a retried answer).
- **Friendly in the app.** Contract and validation failures read "The panel tripped on one
  of its findings. Nothing you saved was lost. Try again." The technical message stays in
  the proxy log and behind a Details disclosure on the card.

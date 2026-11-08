# 0017 — Est. return on every card; the sky melts into the ground

Recorded 2026-11-08, after the first look at Home · leveled up.

- **The prefill returns the Investor's estimated return as data:** `projectionLow`,
  `projectionHigh` (monthly USD, nullable) and `projectionBasis` (a few words on what it
  rests on). The proxy orders the range; the app keeps it on the evaluation as
  `projectionEstimateLow/High/Basis`, exported as optionals. An older proxy's answer
  falls back to price × units from the range it did give.
- **Every idea card carries a labelled row** (`EstimatedReturnRow`): EST. RETURN with the
  user's own figure and "your numbers" once they enter price and units (solid when a
  payment is attached, dots until then); otherwise the Investor's range, striped as
  AI-found, with "from <basis>"; IMPACT on Growth and Creative ideas; before any check,
  "Send to the panel to estimate." "No figures yet" and "No lens yet" are gone. Tapping
  the row opens `ProjectionEstimateSheet`: the range, the Projection card to enter
  numbers, and the competitors' prices the estimate came from, each with its source
  chip and the rung-2 reminder. Home sorts the cards by the user's figure, else the
  middle of the range.
- **The sky** behind the Home header is a `MeshGradient` (lavender, violet, rose, peach,
  ember) whose bottom row is the page colour, so it melts into the ground in either
  theme; a linear fade stands in before iOS 18. The grain sits only where the sky has
  colour. The brown band came from the old three-stop sky meeting a light ground.
- Settings → Appearance now says which scheme is showing, so a light screenshot can be
  traced to the setting or to the window.

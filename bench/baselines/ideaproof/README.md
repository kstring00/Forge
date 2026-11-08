# IdeaProof, by hand

IdeaProof has no API, so this baseline is captured by a person, once per idea.

1. Open ideaproof.ai, start the free check, and paste the idea's `text` from `ideas/<id>.json`
   exactly, nothing added.
2. Time it from submit to the full result.
3. Copy `_template.json` to `<id>.json` here (the same id as the idea file) and fill it in
   with **its** words: every competitor it lists with the price it states, the risk it
   names, the next step it suggests, its overall conclusion, and the minutes it took.
   Write down what it said, not what is true; the key holds the truth.
4. Run the bench with `ideaproof` in `--systems` (it is by default). No cost, no network.

If the free check doesn't name a riskiest assumption or a next step, leave those empty;
the judge scores them as missing.

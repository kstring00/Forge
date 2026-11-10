# 0045 · A Potential score you can trust

**Date:** November 10 · **Status:** part 1 (the measurement) built; part 2 (the fix) follows the first measurement

## Why

Potential is meant to tell someone how big their idea could be if it works. In testing it did two things that make it useless for that:

- **It jumps.** The same idea landed 15 to 25 points apart between runs.
- **It sits at the bottom.** Two unrelated ideas scored 4 and 17, both in the lowest band. A 4 means five of the six criteria scored 1 out of 5 and one scored 2.

A person who is already afraid their idea is bad sees a 4 and stops. And Under the Hood will show each panelist's score, which would put the jumping on display. So this comes before Under the Hood.

## Part 1: measure it first

A fix can't be judged by eye when the thing being fixed is random. `npm run bench:swing` (in `proxy/`) is the ruler:

- It takes the five sample ideas the cost benchmark uses.
- It researches each idea **twice**, and scores each research **three times**: six Potential scores per idea.
- It reports how far the same idea's score moves, split two ways, because the cure differs:
  - **With the same research** (only the scoring ran again): the scoring's own randomness.
  - **From fresh research** (the web search came back different): the research moving the score.
- It also reports what the simulator showed: the average score, the share of scores under 20, how many ideas landed on two different words, how far apart different ideas are, and for each of the six criteria how often it scored 1 and how much it moved.

It runs the real research and the real scoring call a check makes (the server's re-score is that same call), and skips the Brief, so a full run costs about $1.25, not about $5.

**The target** (`target` in `proxy/bench/swing-stats.ts`): on every sample idea the six scores land within **8 points** of each other, and re-scoring the same research moves the score **5 points or less** on average. With bands 20 points wide, that keeps an idea on one word unless it sits right on a boundary. The numbers are a starting proposal, to be revisited when the first measurement is in.

## Part 2: the fix (not built yet)

To be written here once the "before" numbers show where the movement comes from. The first things to look at:

- **The rubric anchors score evidence, not size.** A1's anchors run from "I assume people have it. I have not asked anyone" (1) to "multiple specific people have shown me their workaround" (5). For an idea nobody has tested yet, that is a 1 by definition, whatever the market looks like. How much is proven is Confidence's job; Potential should be able to say "this could be big" before anyone has talked to a customer.
- **How firmly the scoring is asked to decide.** Six scores from five panelists in one call, with no worked examples of what a 2 or a 4 looks like from desk research.
- **Whether fresh research changes what the scoring sees** enough to move it, and if so, whether the packet should carry the same kinds of findings every time.

Whatever changes, scoring stays honest: no score rises without something in the research to point at, and the change is measured with the same ruler before it ships.

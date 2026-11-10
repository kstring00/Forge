# Backlog

Small asks from testing, waiting for the next code change. Newest first.

- **Potential runs low and jumps around (Nov 9).** In the simulator two unrelated ideas scored 4 and 17, both "Long shot"; on the bench the same idea moved 15 to 25 points between runs. Before anyone talks to customers, Potential should say how big the idea could be, not how little is proven (that is Confidence's job). Look at the rubric anchors and how scoring treats "no customer evidence yet", then bench it. **Scheduled (Nov 10): right after #30 merges, before Under the Hood**, because See the Work will show each panelist's score. Target: a small swing between runs on the same idea, measured in the bench. Until then the Nov 9 sources fix counts as **unconfirmed** on a device: the simulator showed real pages cited, but two ideas scoring 4 and 17 proves nothing while one idea can move 15 to 25 points.

- **The Brief's rings still show a bare number (Nov 9).** `StripedRingCard` in `BriefSection.swift` draws Potential and Confidence its own way, without "of 100" or the word ("Long shot"). Switch it to `ScoreRing` like every other ring (decision 0038 follow-up).

- **Keep the idea you just worked on in reach (Nov 9).** After opening or working on an idea, it should sit in a special place at the top ("the idea you just worked on") instead of being buried in the list under everything else. Possibly each idea card collapsible, so the list stays short.

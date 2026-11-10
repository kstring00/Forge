# Backlog

Small asks from testing, waiting for the next code change. Newest first.

## Notes from testing

- **Proposal, not built: the Ideas tab could use Home's rows (Nov 10).** After the Home pass (decision 0044), Home shows compact rows with one filled orange button on the whole screen, while Ideas still shows the older full card with a filled button on every card. Reusing the rows there would make the two tabs match and fit more ideas per screen; search, filters, sort and archive would stay. To decide after the Home pass is tested.

- **Five older app tests fail on the Mac (first full Cmd+U, Nov 9).** None is in code that #38 or #39 changed, so they fail on main too; app tests can't run on Linux, which is how they went unnoticed. To sort out in one small PR after #38 and #39 merge:
  - `WorkshopActionsTests` (logging a conversation): "she pays a nephew" is read as a payment (proof step 4) when it should be a conversation (step 3). **Possibly a real bug:** someone paying somebody else is not proof they'd pay you.
  - `ProjectCleanupTests` (merging duplicate projects): logged conversations are added together only when the two steps differ; the test expects them added when the steps are the same. Looks like a real bug in a one-time cleanup.
  - `PivotActionsTests` (a second tap on a What-if): making an idea from a What-if twice with the same card value makes two ideas. The app passes the updated card, so it likely doesn't show; worth hardening.
  - `RulingActionsTests`: expects the word "rung 2"; the app has said "proof level 2" since the legibility pass. The test is out of date.
  - `PrefillApplierTests`: expects Confidence 37, gets 27, since desk research was graded (decision 0037). The test is probably out of date; confirm.

- **Potential runs low and jumps around (Nov 9).** In the simulator two unrelated ideas scored 4 and 17, both "Long shot"; on the bench the same idea moved 15 to 25 points between runs. Before anyone talks to customers, Potential should say how big the idea could be, not how little is proven (that is Confidence's job). Look at the rubric anchors and how scoring treats "no customer evidence yet", then bench it. **Scheduled (Nov 10): right after #30 merges, before Under the Hood**, because See the Work will show each panelist's score. Target: a small swing between runs on the same idea, measured in the bench. Until then the Nov 9 sources fix counts as **unconfirmed** on a device: the simulator showed real pages cited, but two ideas scoring 4 and 17 proves nothing while one idea can move 15 to 25 points.

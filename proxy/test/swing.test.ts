import { test } from "node:test";
import assert from "node:assert/strict";
import { band, criterionStats, ideaStats, meetsTarget, overall, potential, report, type IdeaRuns } from "../bench/swing-stats.js";

const crit = (scores: number[]) => scores.map((score, i) => ({ key: `A${i + 1}`, score }));
const scoring = (scores: number[]) => ({ potential: potential(crit(scores)), criteria: crit(scores) });

test("Potential is the mean score on 0 to 100, as the app computes it", () => {
  assert.equal(potential(crit([1, 1, 1, 1, 1, 1])), 0);
  assert.equal(potential(crit([5, 5, 5, 5, 5, 5])), 100);
  assert.equal(potential(crit([3, 3, 3, 3, 3, 3])), 50);
  assert.equal(potential(crit([1, 1, 1, 1, 1, 2])), 4, "the 4 seen in the simulator: five 1s and a 2");
  assert.equal(potential(crit([2, 2, 2, 1, 1, 2])), 17);
  assert.equal(potential([]), 0);
  assert.equal(potential(crit([9, 0])), 50, "scores are held to 1 to 5");
  assert.equal(band(4), "Unproven");
  assert.equal(band(20), "Modest");
  assert.equal(band(45), "Promising");
  assert.equal(band(80), "Big");
});

const jumpy: IdeaRuns = {
  slug: "jumpy", title: "Jumpy",
  passes: [
    { scorings: [scoring([1, 1, 1, 1, 1, 2]), scoring([2, 2, 1, 1, 1, 2])] },   // 4, 13
    { scorings: [scoring([3, 2, 2, 2, 2, 2]), scoring([3, 3, 2, 2, 2, 2])] },   // 29, 33
  ],
};
const steady: IdeaRuns = {
  slug: "steady", title: "Steady",
  passes: [
    { scorings: [scoring([3, 3, 3, 3, 3, 3]), scoring([3, 3, 3, 3, 3, 3])] },
    { scorings: [scoring([3, 3, 3, 3, 3, 4]), scoring([3, 3, 3, 3, 3, 3])] },
  ],
};

test("swing separates the scoring's own noise from what fresh research moves", () => {
  const s = ideaStats(jumpy);
  assert.deepEqual(s.potentials, [[4, 13], [29, 33]]);
  assert.equal(s.swing, 29, "highest minus lowest over every scoring");
  assert.equal(s.swingSameResearch, 9, "the worst pass: 4 to 13");
  assert.equal(s.swingBetweenResearch, 22.5, "pass averages 8.5 and 31");
  assert.deepEqual(s.bands, ["Unproven", "Modest"]);

  const t = ideaStats(steady);
  assert.equal(t.swing, 4);
  assert.equal(t.swingSameResearch, 4);
  assert.deepEqual(t.bands, ["Promising"]);
});

test("the overall numbers and the target", () => {
  const o = overall([jumpy, steady]);
  assert.equal(o.ideas, 2);
  assert.equal(o.scorings, 8);
  assert.equal(o.averageSwing, 16.5);
  assert.equal(o.worstSwing, 29);
  assert.equal(o.ideasChangingBand, 1);
  assert.equal(o.shareInLowestBand, 0.25);
  assert.equal(o.spreadBetweenIdeas, 31.2, "idea averages 19.8 (19.75 rounded) and 51");
  assert.equal(meetsTarget(o), false);
  assert.equal(meetsTarget(overall([steady])), true);
  assert.equal(meetsTarget(overall([])), false, "nothing measured is not a pass");
});

test("criteria: which ones sit at 1 and which ones move", () => {
  const c = criterionStats([jumpy, steady]);
  assert.deepEqual(c.map((x) => x.key), ["A1", "A2", "A3", "A4", "A5", "A6"]);
  const a1 = c[0];
  assert.equal(a1.shareAtOne, 1 / 8, "one of the eight A1 scores is a 1");
  assert.equal(a1.averageSwing, 1, "A1 moves 1 to 3 on the jumpy idea and not at all on the steady one");
  assert.equal(c[5].shareAtOne, 0);
});

test("an idea with a failed pass is reported, not dropped or counted", () => {
  const partial: IdeaRuns = { slug: "p", title: "P", passes: [{ scorings: [] }, { scorings: [scoring([2, 2, 2, 2, 2, 2])] }] };
  const s = ideaStats(partial);
  assert.deepEqual(s.potentials, [[25]]);
  assert.equal(s.swing, 0);
  assert.equal(overall([{ slug: "none", title: "None", passes: [] }]).ideas, 0);
});

test("the report prints one run or a before and after", () => {
  const one = report(["before"], [[jumpy, steady]]);
  assert.match(one, /Average swing on the same idea/);
  assert.match(one, /4, 13 · 29, 33/);
  const two = report(["before", "after"], [[jumpy], [steady]]);
  assert.match(two, /before → after/);
  assert.match(two, /\| steady \| before \| missing/);
});

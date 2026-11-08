import { test } from "node:test";
import assert from "node:assert/strict";
import { PrefillResult, RealityCheckResult } from "../lib/schemas.js";
import { fillOmittedNulls, salvage } from "../lib/salvage.js";
import { enforcePrefill, enforceRealityCheck } from "../lib/enforce.js";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";

const competitor = (name: string, sourceID?: string | null) => {
  const c: Record<string, unknown> = { name, url: null, pricing: "$149/mo", positioning: "Web care", praises: [], complaints: [], tractionSignals: [] };
  if (sourceID !== undefined) c.sourceID = sourceID;
  return c;
};

/// The run that failed: three competitors, the third with no sourceID at all.
const fixture = {
  realityCheck: {
    verdict: "compete", summary: "Crowded.", gapMap: "", fitNotes: "", experiment: null, costEstimate: "",
    competitors: [competitor("Northline", A), competitor("Harbor", B), competitor("Unsourced Co")],
    demandSignals: [{ text: "Owners complain", url: null, rung: 2, sourceID: A }, { text: "Made up", rung: 2 }],
  },
  explorations: [], criteria: [], projection: null, projectionLow: null, projectionHigh: null, projectionBasis: "",
  riskiestAssumption: { belief: "b", consequence: "c", sourceIDs: [] },
  nextMove: { recommendation: "testRiskiestAssumption", step: "Ask five", experiment: null },
  draftedAssets: { kind: "interviewQuestions", title: "Five", body: "1." },
  panel: [], crossfire: [],
};

test("an unsourced competitor no longer sinks the run: it is dropped and counted", () => {
  const s = salvage(fixture, PrefillResult);
  assert.ok(s.data, `salvage should succeed; issues: ${s.issues.join("; ")}`);
  // The omitted key became null and parsed; the source rules then drop it.
  assert.equal(s.data!.realityCheck.competitors.length, 3);
  const dropped: Record<string, number> = { ...s.dropped };
  const enforced = enforcePrefill(s.data!, new Set([A, B]), ["A1", "A2"], ["problem"], dropped);
  assert.deepEqual(enforced.realityCheck.competitors.map((c) => c.name), ["Northline", "Harbor"]);
  assert.deepEqual(enforced.realityCheck.demandSignals.map((d) => d.text), ["Owners complain"]);
  assert.equal(dropped["realityCheck.competitors"], 1);
  assert.equal(dropped["realityCheck.demandSignals"], 1);
});

test("a list item that is wrong in other ways is dropped by salvage itself", () => {
  const bad = structuredClone(fixture) as typeof fixture & { realityCheck: { demandSignals: unknown[] } };
  bad.realityCheck.demandSignals.push({ text: "Bad rung", url: null, rung: "two", sourceID: A });
  bad.realityCheck.demandSignals.push({ text: 42, url: null, rung: 1, sourceID: A });
  const s = salvage(bad, PrefillResult);
  assert.ok(s.data);
  assert.equal(s.dropped["realityCheck.demandSignals"], 2);
  assert.equal(s.data!.realityCheck.demandSignals.length, 2);
});

test("a missing required top-level field still fails, with the issues named", () => {
  const broken = structuredClone(fixture) as Record<string, unknown>;
  delete (broken.realityCheck as Record<string, unknown>).verdict;
  const s = salvage(broken, PrefillResult);
  assert.equal(s.data, null);
  assert.ok(s.issues.some((i) => i.startsWith("realityCheck.verdict")));
});

test("fillOmittedNulls fills only the nullable fields an item may omit", () => {
  const filled = fillOmittedNulls({ competitors: [competitor("X")], other: { name: "keep", extra: 1 } }) as { competitors: Array<Record<string, unknown>>; other: Record<string, unknown> };
  assert.equal(filled.competitors[0].sourceID, null);
  assert.equal(filled.competitors[0].url, null);
  assert.equal("sourceID" in filled.other, true, "an object with a name is treated as an item");
  const rc = RealityCheckResult.parse(fillOmittedNulls({ ...fixture.realityCheck }));
  assert.equal(rc.competitors[2].sourceID, null);
  const enforced = enforceRealityCheck(rc, new Set([A]));
  assert.deepEqual(enforced.competitors.map((c) => c.name), ["Northline"]);
});

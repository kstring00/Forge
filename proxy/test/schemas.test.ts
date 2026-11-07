import { test } from "node:test";
import assert from "node:assert/strict";
import { ActionRequest, PrefillResult, RoundResult } from "../lib/schemas.js";
import { enforcePrefill, enforceRound } from "../lib/enforce.js";
import { costUSD, realityCheckEstimateUSD } from "../lib/pricing.js";
import { content, lensText, lens } from "../lib/content.js";
import { actionInstruction, stableSystem } from "../lib/prompts.js";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
const UNKNOWN = "33333333-3333-4333-8333-333333333333";

test("content.json carries every lens, sphere and prompt", () => {
  assert.equal(content.lenses.length, 3);
  assert.equal(lens("business").criteria.length, 6);
  assert.equal(content.spheres.length, 6);
  assert.equal(content.explorePrompts.length, 6);
  assert.equal(content.deskResearchRungCeiling, 2);
  assert.ok(lensText("business").includes("Demand evidence"));
  assert.ok(stableSystem("business").includes("great idea"));
});

test("a minimal action request parses with defaults", () => {
  const r = ActionRequest.parse({ action: "expand", context: { ideaID: A, originalText: "x", title: "t" } });
  assert.equal(r.context.spheres.length, 5);
  assert.deepEqual(r.context.sources, []);
  for (const a of ["expand", "prefill", "runRound", "realityCheck"] as const) assert.ok(actionInstruction(a).length > 20);
});

test("a verdict with no known source becomes cantTell; crossfire is one per pair", () => {
  const r = RoundResult.parse({
    verdicts: [
      { sphere: "investor", verdict: "onTrack", criterionKey: "A5", reason: "r", sourceIDs: [UNKNOWN], evidenceNeeded: null },
      { sphere: "customer", verdict: "offTrack", criterionKey: "A2", reason: "r", sourceIDs: [A], evidenceNeeded: null },
    ],
    crossfire: [
      { from: "investor", to: "customer", text: "a" },
      { from: "customer", to: "investor", text: "b" },
      { from: "skeptic", to: "skeptic", text: "c" },
    ],
  });
  const e = enforceRound(r, new Set([A, B]));
  assert.equal(e.verdicts[0].verdict, "cantTell");
  assert.deepEqual(e.verdicts[0].sourceIDs, []);
  assert.ok(e.verdicts[0].evidenceNeeded);
  assert.equal(e.verdicts[1].verdict, "offTrack");
  assert.equal(e.crossfire.length, 1);
});

test("prefill is clamped to the desk ceiling and known keys", () => {
  const p = PrefillResult.parse({
    realityCheck: { verdict: "compete", summary: "s", competitors: [{ name: "X", url: null, pricing: "$99", positioning: "p", praises: [], complaints: [], tractionSignals: [], sourceID: UNKNOWN }],
      demandSignals: [{ text: "d", url: null, rung: 5, sourceID: A }], gapMap: "g", fitNotes: "f", experiment: null, costEstimate: "$0.3" },
    explorations: [{ promptKey: "problem", answer: "a", sourceIDs: [A] }, { promptKey: "bogus", answer: "b", sourceIDs: [] }],
    criteria: [
      { key: "A2", score: 9, evidenceLevel: 4, note: "n", sourceIDs: [A] },
      { key: "A1", score: 3, evidenceLevel: 2, note: "n", sourceIDs: [] },
      { key: "Z9", score: 3, evidenceLevel: 2, note: "n", sourceIDs: [] },
    ],
    projection: null,
    riskiestAssumption: { belief: "b", consequence: "c", sourceIDs: [UNKNOWN] },
    nextMove: { recommendation: "testRiskiestAssumption", step: "s", experiment: null },
    draftedAssets: { kind: "interviewQuestions", title: "t", body: "b" },
    panel: [{ sphere: "skeptic", verdict: "onTrack", criterionKey: "A2", reason: "r", sourceIDs: [], evidenceNeeded: null }],
    crossfire: [],
  });
  const e = enforcePrefill(p, new Set([A]), lens("business").criteria.map((c) => c.key), content.explorePrompts.map((x) => x.key));
  assert.equal(e.realityCheck.competitors[0].sourceID, null);
  assert.equal(e.realityCheck.demandSignals[0].rung, 2);
  assert.deepEqual(e.explorations.map((x) => x.promptKey), ["problem"]);
  assert.deepEqual(e.criteria.map((c) => c.key), ["A2", "A1"]);
  assert.equal(e.criteria[0].score, 5);
  assert.equal(e.criteria[0].evidenceLevel, 2);
  assert.equal(e.criteria[1].evidenceLevel, 1, "no source: at most rung 1");
  assert.deepEqual(e.riskiestAssumption.sourceIDs, []);
  assert.equal(e.panel[0].verdict, "cantTell");
});

test("cost accounting", () => {
  const c = costUSD("claude-sonnet-5-5", { input_tokens: 1_000_000, output_tokens: 0, server_tool_use: { web_search_requests: 3 } });
  assert.equal(Math.round(c * 100) / 100, 2.03);
  const est = realityCheckEstimateUSD();
  assert.ok(est.low < est.high);
});

test("the bearer token is compared trimmed on both sides", async () => {
  process.env.FORGE_PROXY_TOKEN = "  abc123\n";
  process.env.ANTHROPIC_API_KEY = "sk-test";
  const { requireAuth } = await import("../lib/http.js?" + Date.now());
  const { config } = await import("../lib/env.js?" + Date.now());
  assert.equal(config.proxyToken, "abc123");
  const ok = { headers: { authorization: "Bearer abc123 " } } as never;
  assert.doesNotThrow(() => requireAuth(ok));
  const bad = { headers: { authorization: "Bearer abc124" } } as never;
  assert.throws(() => requireAuth(bad), /invalid proxy token/);
});

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
  // The investor fell to cantTell, so nobody conflicts and no crossfire survives.
  assert.equal(e.crossfire.length, 0);
});

test("crossfire survives only between conflicting verdicts, once per pair", () => {
  const r = RoundResult.parse({
    verdicts: [
      { sphere: "investor", verdict: "onTrack", criterionKey: "A5", reason: "r", sourceIDs: [A], evidenceNeeded: null },
      { sphere: "customer", verdict: "offTrack", criterionKey: "A2", reason: "r", sourceIDs: [B], evidenceNeeded: null },
      { sphere: "builder", verdict: "onTrack", criterionKey: "A6", reason: "r", sourceIDs: [A], evidenceNeeded: null },
      { sphere: "skeptic", verdict: "cantTell", criterionKey: "A2", reason: "r", sourceIDs: [], evidenceNeeded: "x" },
    ],
    crossfire: [
      { from: "investor", to: "customer", text: "a" },
      { from: "customer", to: "investor", text: "b" },
      { from: "investor", to: "builder", text: "agree, no fight" },
      { from: "skeptic", to: "investor", text: "cantTell argues with nobody" },
      { from: "customer", to: "builder", text: "c" },
    ],
  });
  const e = enforceRound(r, new Set([A, B]));
  assert.deepEqual(e.crossfire.map((c) => c.text), ["a", "c"]);
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
    projectionLow: 2400, projectionHigh: 900, projectionBasis: "three pricing pages",
    riskiestAssumption: { belief: "b", consequence: "c", sourceIDs: [UNKNOWN] },
    nextMove: { recommendation: "testRiskiestAssumption", step: "s", experiment: null },
    draftedAssets: { kind: "interviewQuestions", title: "t", body: "b" },
    panel: [{ sphere: "skeptic", verdict: "onTrack", criterionKey: "A2", reason: "r", sourceIDs: [], evidenceNeeded: null }],
    crossfire: [],
    pivots: [
      { whatIf: "you sold to the park owners' association instead of parks one by one", pivotType: "channel", fixes: "A5", why: "Three parks name the same association.", firstTest: "Email the association.", sourceIDs: [A, UNKNOWN] },
      { whatIf: "What if the site were free and the upsell were bookings?", pivotType: "businessModel", fixes: "Z9", why: "w", firstTest: "f", sourceIDs: [] },
      { whatIf: "What if only RV parks on I-10?", pivotType: "zoomIn", fixes: "A2", why: "w", firstTest: "f", sourceIDs: [] },
      { whatIf: "What if a fourth?", pivotType: "zoomOut", fixes: "A1", why: "w", firstTest: "f", sourceIDs: [] },
      { whatIf: "What if a fifth?", pivotType: "technology", fixes: "A3", why: "w", firstTest: "f", sourceIDs: [] },
    ],
  });
  const dropped: Record<string, number> = {};
  const e = enforcePrefill(p, new Set([A]), lens("business").criteria.map((c) => c.key), content.explorePrompts.map((x) => x.key), dropped);
  assert.equal(e.realityCheck.competitors.length, 0, "an unknown source is not a finding");
  assert.equal(dropped["realityCheck.competitors"], 1);
  assert.equal(e.realityCheck.demandSignals[0].rung, 2);
  assert.deepEqual(e.explorations.map((x) => x.promptKey), ["problem"]);
  assert.deepEqual(e.criteria.map((c) => c.key), ["A2", "A1"]);
  assert.equal(e.criteria[0].score, 5);
  assert.equal(e.criteria[0].evidenceLevel, 2);
  assert.equal(e.criteria[1].evidenceLevel, 1, "no source: at most rung 1");
  assert.deepEqual(e.riskiestAssumption.sourceIDs, []);
  assert.equal(e.panel[0].verdict, "cantTell");
  assert.equal(e.pivots.length, 3, "at most three pivots, and never one that raises a criterion the lens does not have");
  assert.equal(e.pivots[0].whatIf, "What if you sold to the park owners' association instead of parks one by one?", "phrased as a what-if");
  assert.deepEqual(e.pivots[0].sourceIDs, [A], "cites only known sources");
  assert.deepEqual(e.pivots.map((x) => x.fixes), ["A5", "A2", "A1"]);
  // The range is put in order.
  assert.equal(e.projectionLow, 900);
  assert.equal(e.projectionHigh, 2400);
});

test("cost accounting", () => {
  const c = costUSD("claude-sonnet-5-5", { input_tokens: 1_000_000, output_tokens: 0, server_tool_use: { web_search_requests: 3 } });
  assert.equal(Math.round(c * 100) / 100, 2.03);
  const est = realityCheckEstimateUSD();
  assert.ok(est.low < est.high);
  // The target is 10 to 20 cents a check; the estimate must stay near it.
  assert.ok(est.low >= 0.05 && est.high <= 0.3, `estimate ${est.low}-${est.high}`);
});

test("Haiku switches rate card past 100K prompt tokens", () => {
  const short = costUSD("claude-haiku-5-5", { input_tokens: 100_000, output_tokens: 0 });
  assert.equal(Math.round(short * 1000) / 1000, 0.01);
  const long = costUSD("claude-haiku-5-5", { input_tokens: 90_000, cache_read_input_tokens: 20_000, output_tokens: 1000 });
  // 90K * 0.5 + 20K * 0.05 + 1K * 2.5, per million
  assert.equal(Math.round(long * 100000) / 100000, 0.0485);
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

test("research runs on Haiku with the basic web tools and capped page size", async () => {
  const { researchTools } = await import("../api/research.js");
  const haiku = researchTools("claude-haiku-5-5") as Array<{ type: string; max_uses?: number; max_content_tokens?: number }>;
  assert.deepEqual(haiku.map((t) => t.type), ["web_search_20250305", "web_fetch_20250910"]);
  assert.ok((haiku[0].max_uses ?? 99) <= 5);
  assert.ok((haiku[1].max_content_tokens ?? 99_999) <= 4000);
  const sonnet = researchTools("claude-sonnet-5-5") as Array<{ type: string }>;
  assert.deepEqual(sonnet.map((t) => t.type), ["web_search_20260209", "web_fetch_20260209"]);
});

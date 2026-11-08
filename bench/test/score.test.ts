import { test } from "node:test";
import assert from "node:assert/strict";
import { competitorRecall, gate, normalize, parsePrices, priceAccurate, priceScore, sameCompetitor, scoreIdea, sourceSupports, totals } from "../src/score.js";
import { AnswerKey, type SystemOutput } from "../src/types.js";
import { chunks } from "../src/engine.js";

const key = AnswerKey.parse({
  competitors: [
    { name: "Google Drive", aliases: ["Google One"], url: "https://one.google.com/about/plans", priceLow: 1.99, priceHigh: 9.99 },
    { name: "iCloud", aliases: ["iCloud+"], priceLow: 0.99, priceHigh: 9.99 },
    { name: "OneDrive", url: "https://www.microsoft.com/microsoft-365/onedrive", priceLow: 1.99, priceHigh: 9.99 },
    { name: "Dropbox", priceLow: 9.99, priceHigh: 11.99 },
  ],
  riskiestAssumption: "People will pay for another sync service.",
  keyedBy: "test", keyedAt: "2026-11-08", verified: true,
});

test("names normalise and match by name, alias, containment or website", () => {
  assert.equal(normalize("Dropbox, Inc."), "dropbox");
  assert.equal(normalize("Pressed Juicery (pressed.com)"), "pressed juicery pressed");
  assert.ok(sameCompetitor(key.competitors[0], { name: "Google One", url: null }));
  assert.ok(sameCompetitor(key.competitors[0], { name: "Google Drive storage plans", url: null }), "whole-word containment");
  assert.ok(sameCompetitor(key.competitors[2], { name: "Microsoft's cloud", url: "https://www.microsoft.com/microsoft-365/onedrive/x" }), "same website");
  assert.ok(!sameCompetitor(key.competitors[1], { name: "Box", url: null }));
  assert.ok(!sameCompetitor({ ...key.competitors[3] }, { name: "Drop", url: null }), "short fragments don't count");
});

test("recall counts the key's true top three only", () => {
  const r = competitorRecall(key, [
    { name: "Google One", url: null, pricing: "", supported: null },
    { name: "Dropbox", url: null, pricing: "", supported: null },
  ]);
  assert.deepEqual(r, { hits: 1, of: 3, matched: ["Google Drive"] });
});

test("prices are read from the ways people write them", () => {
  assert.deepEqual(parsePrices("$9.99/mo or $1,299 once; USD 19; $1.2k a year; 149 dollars"), [9.99, 1299, 19, 1200, 149]);
  assert.deepEqual(parsePrices("free"), []);
  assert.equal(priceAccurate(key.competitors[0], "$2/month for 100 GB"), true);
  assert.equal(priceAccurate(key.competitors[0], "$29.99"), false);
  assert.equal(priceAccurate(key.competitors[0], "varies"), null, "no number is not checked");
  assert.deepEqual(priceScore(key, [
    { name: "Google One", url: null, pricing: "$1.99–$9.99 a month", supported: null },
    { name: "iCloud+", url: null, pricing: "$30", supported: null },
    { name: "OneDrive", url: null, pricing: "bundled", supported: null },
  ]), { accurate: 1, checked: 2 });
});

test("a claim is supported only when its page carries the name and every figure", () => {
  const page = "Google One plans\n\n100 GB for $1.99 per month. 2 TB for $9.99 per month.";
  assert.ok(sourceSupports("Google One", "$1.99 to $9.99 a month", page));
  assert.ok(!sourceSupports("Google One", "$2.99 a month", page), "a figure the page doesn't show");
  assert.ok(!sourceSupports("iCloud", "$0.99", page), "a name the page doesn't show");
  assert.ok(!sourceSupports("Google One", "$1.99", null), "no page");
});

test("the app's chunker packs paragraphs to about 1,200 characters", () => {
  const para = "x".repeat(700);
  const c = chunks([para, para, para].join("\n\n"));
  assert.equal(c.length, 3);
  assert.ok(c.every((s) => s.length <= 1200));
});

const out = (system: string, competitors: SystemOutput["competitors"], extra: Partial<SystemOutput> = {}): SystemOutput => ({
  system, ideaId: "classic-dropbox", verdict: "useTheirs", competitors, riskiestAssumption: "r", theTest: "t",
  costUSD: 0.2, latencyMs: 60_000, models: ["m"], ranAt: "2026-11-08", ...extra,
});
const sameRisk = { riskMatch: "same" as const, riskWhy: "", step: { onePerson: true, withinAWeek: true, underFifty: true, concrete: true, why: "" }, model: "j", costUSD: 0.01 };
const otherRisk = { ...sameRisk, riskMatch: "different" as const, step: { ...sameRisk.step, concrete: false } };

test("totals and the ship gate: beat both baselines on 1, 2 and 4, with 100% source truth", () => {
  const engine = scoreIdea(key, out("engine", [
    { name: "Google One", url: null, pricing: "$1.99", supported: true },
    { name: "iCloud", url: null, pricing: "$0.99", supported: true },
  ]), sameRisk);
  const base = scoreIdea(key, out("baseline", [{ name: "Google Drive", url: null, pricing: "$2", supported: null }]), otherRisk);
  const proof = scoreIdea(key, out("ideaproof", []), otherRisk);
  const t = totals([engine, base, proof]);
  assert.equal(t.find((x) => x.system === "engine")!.sourceTruthPct, 100);
  assert.equal(t.find((x) => x.system === "baseline")!.sourceTruthPct, 0, "a claim with no page is not supported");
  assert.equal(t.find((x) => x.system === "baseline")!.stepPass.pass, 0);
  assert.equal(gate(t).verdict, "ship");

  const half = scoreIdea(key, out("engine", [
    { name: "Google One", url: null, pricing: "$1.99", supported: true },
    { name: "iCloud", url: null, pricing: "$0.99", supported: false },
  ]), sameRisk);
  assert.equal(gate(totals([half, base, proof])).verdict, "hold", "source truth under 100% holds the release");
  assert.equal(gate(totals([engine, base])).verdict, "incomplete", "IdeaProof not captured");
});

test("a refusal or an error scores zero and is counted as failed", () => {
  const s = scoreIdea(key, out("baseline", [], { refused: true, error: "refused (cyber)" }), null);
  assert.equal(s.failed, true);
  assert.equal(s.recall.hits, 0);
  assert.equal(s.risk, 0);
  assert.equal(totals([s])[0].failed, 1);
});

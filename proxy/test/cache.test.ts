import { test } from "node:test";
import assert from "node:assert/strict";
import { cacheLine } from "../lib/cachelog.js";
import { panelSystem, scoreInstruction, briefInstruction, actionInstruction, userTurn } from "../lib/prompts.js";
import { ActionRequest } from "../lib/schemas.js";

test("every panel call puts the stable parts first, both marked for caching, the idea after", () => {
  const a = panelSystem("business", scoreInstruction);
  const b = panelSystem("business", briefInstruction);
  assert.equal(a.length, 2);
  assert.ok(a.every((x) => x.cache_control?.type === "ephemeral"));
  assert.equal(a[0].text, b[0].text, "the shared prefix is byte-identical across actions");
  assert.equal(panelSystem("business", scoreInstruction)[1].text, a[1].text, "and across calls of one action");
  const ctx = ActionRequest.parse({ action: "rescore", context: { ideaID: "11111111-1111-4111-8111-111111111111", originalText: "Weekend website care", title: "t" } }).context;
  for (const block of a) assert.ok(!block.text.includes("Weekend website care"), "nothing idea-specific in the cached system prompt");
  assert.ok(userTurn(ctx, undefined).includes("Weekend website care"));
  assert.equal(actionInstruction("rescore"), scoreInstruction);
});

test("the cache log reads hits and misses from the API's usage", () => {
  assert.deepEqual(cacheLine("action.prefill.score", "claude-haiku-5-5", { input_tokens: 2000, cache_read_input_tokens: 6000, cache_creation_input_tokens: 0 }),
    { at: "cache", label: "action.prefill.score", model: "claude-haiku-5-5", read: 6000, written: 0, fresh: 2000, hitRate: 0.75, result: "hit" });
  assert.equal(cacheLine("x", "m", { input_tokens: 2000, cache_read_input_tokens: 0, cache_creation_input_tokens: 6000 }).result, "miss");
});

test("the plan numbers the server sends are the ones the app ships with", async () => {
  const { readFileSync } = await import("node:fs");
  const { hunchConfig } = await import("../lib/config.js");
  const fixture = JSON.parse(readFileSync(new URL("./fixtures/rules.json", import.meta.url), "utf8"));
  assert.deepEqual(JSON.parse(JSON.stringify(hunchConfig.rules)), fixture,
    "config/hunch.ts rules and test/fixtures/rules.json differ: change both, and ForgeCore's PlanRules defaults (RulesFixtureTests checks those)");
});

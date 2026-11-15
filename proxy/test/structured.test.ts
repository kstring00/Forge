import { test } from "node:test";
import assert from "node:assert/strict";

// The bench saw a re-score cut off mid-answer (Haiku's thinking used up
// max_tokens); the SDK then threw and the call failed with a bare 500.
test("a cut-off structured answer is retried as plain JSON, not a 500", async () => {
  const { startMock } = await import("../bench/mock-anthropic.js");
  const mock = await startMock({ truncateFirst: true });
  process.env.ANTHROPIC_BASE_URL = mock.url;
  process.env.ANTHROPIC_API_KEY = "mock";
  try {
    // The same call a re-score makes, without the handler in front of it: the
    // handler refuses every request now that the bearer token is gone (PARKED.md).
    const { callStructured } = await import("../lib/structured.js");
    const { ActionRequest, ScoreResult, withRationale } = await import("../lib/schemas.js");
    const { panelSystem, scoreInstruction, userTurn } = await import("../lib/prompts.js");
    const { effortFor, modelFor } = await import("../lib/config.js");
    const { context } = ActionRequest.parse({ action: "rescore", context: { ideaID: "11111111-1111-4111-8111-111111111111", originalText: "x", title: "t",
      sources: [{ id: "22222222-2222-4222-8222-222222222222", title: "p", sourceClass: "aiFound", reviewed: false, chunks: [] }] } });
    const result = await callStructured({
      label: "action.rescore", model: modelFor("scoring"), maxTokens: 16000, mode: "structured", effort: effortFor("scoring"),
      system: panelSystem("business", scoreInstruction), user: userTurn(context, undefined),
      schema: withRationale(ScoreResult), timeoutMs: 20_000,
    });
    assert.equal((result.parsed as { payload: { criteria: unknown[] } }).payload.criteria.length, 6);
    assert.deepEqual(mock.requests, ["structured", "json"], "one cut-off structured try, then plain JSON");
  } finally {
    mock.server.close();
  }
});

test("the Brief goes straight to plain JSON: its schema is too large to compile", async () => {
  const { readFileSync } = await import("node:fs");
  const src = readFileSync(new URL("../api/action.ts", import.meta.url), "utf8");
  assert.ok(/jsonOnly = new Set<string>\(\["brief"/.test(src));
});

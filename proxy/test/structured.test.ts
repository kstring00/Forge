import { test } from "node:test";
import assert from "node:assert/strict";

// The bench saw a re-score cut off mid-answer (Haiku's thinking used up
// max_tokens); the SDK then threw and the call failed with a bare 500.
test("a cut-off structured answer is retried as plain JSON, not a 500", async () => {
  const { startMock } = await import("../bench/mock-anthropic.js");
  const mock = await startMock({ truncateFirst: true });
  process.env.ANTHROPIC_BASE_URL = mock.url;
  process.env.ANTHROPIC_API_KEY = "mock";
  process.env.FORGE_PROXY_TOKEN = "t";
  try {
    const { default: action } = await import("../api/action.js");
    const reply = await new Promise<{ status: number; body: any }>((resolve) => {
      const res = {
        statusCode: 200,
        status(c: number) { this.statusCode = c; return this; },
        setHeader() {},
        json(b: unknown) { resolve({ status: this.statusCode, body: b }); },
      };
      action({ method: "POST", headers: { authorization: "Bearer t" },
        body: { action: "rescore", context: { ideaID: "11111111-1111-4111-8111-111111111111", originalText: "x", title: "t",
          sources: [{ id: "22222222-2222-4222-8222-222222222222", title: "p", sourceClass: "aiFound", reviewed: false, chunks: [] }] } } } as never, res as never);
    });
    assert.equal(reply.status, 200, JSON.stringify(reply.body));
    assert.equal(reply.body.payload.criteria.length, 6);
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

import { test } from "node:test";
import assert from "node:assert/strict";

// PARKED.md: the proxy is shut down. Two things hold that, and each is tested
// on its own: the kill switch, and the bearer token being gone from the code.

function fakeRes() {
  const out = { status: 0, body: undefined as unknown };
  const res = {
    statusCode: 200,
    status(c: number) { out.status = c; return res; },
    setHeader() {},
    json(b: unknown) { out.body = b; },
  };
  return { res: res as never, out };
}

/// A request that throws if anything tries to read it: the switch must answer first.
function untouchable(): never {
  return new Proxy({}, {
    get(_t, prop) { throw new Error(`the request was read (${String(prop)}) before the kill switch answered`); },
  }) as never;
}

const routes = ["action", "research", "health"] as const;

test("PROXY_DISABLED=true: every route answers 503 {\"error\":\"Service paused\"} before auth, before reading the request, before any upstream call", async () => {
  process.env.PROXY_DISABLED = "true";
  process.env.ANTHROPIC_API_KEY = "sk-test-must-never-be-used";
  // Any call to the Claude API would have to go through fetch.
  const realFetch = globalThis.fetch;
  let upstreamCalls = 0;
  globalThis.fetch = (async () => { upstreamCalls++; throw new Error("no upstream call is allowed while paused"); }) as never;
  try {
    for (const route of routes) {
      const { default: handler } = await import(`../api/${route}.js`);
      const r = fakeRes();
      await handler(untouchable(), r.res);
      assert.equal(r.out.status, 503, route);
      assert.deepEqual(r.out.body, { error: "Service paused" }, route);
    }
    // The old token makes no difference, nor does the method.
    for (const route of routes) {
      const { default: handler } = await import(`../api/${route}.js`);
      for (const method of ["GET", "POST"]) {
        const r = fakeRes();
        await handler({ method, headers: { authorization: "Bearer the-old-token-0123456789" }, body: { action: "rescore" } } as never, r.res);
        assert.equal(r.out.status, 503, `${method} ${route}`);
        assert.deepEqual(r.out.body, { error: "Service paused" });
      }
    }
    assert.equal(upstreamCalls, 0);
  } finally {
    globalThis.fetch = realFetch;
    delete process.env.PROXY_DISABLED;
  }
});

test("the switch is exactly \"true\" (any case, spaces trimmed); anything else leaves it off", async () => {
  const { paused } = await import("../lib/http.js");
  for (const [value, on] of [["true", true], ["TRUE", true], [" true\n", true], ["false", false], ["1", false], ["yes", false], ["", false]] as const) {
    process.env.PROXY_DISABLED = value;
    const r = fakeRes();
    assert.equal(paused(r.res), on, JSON.stringify(value));
    assert.equal(r.out.status, on ? 503 : 0);
  }
  delete process.env.PROXY_DISABLED;
  assert.equal(paused(fakeRes().res), false, "unset is off");
});

test("with the switch off, the proxy still serves nothing: the old bearer token opens no route and nothing goes upstream", async () => {
  delete process.env.PROXY_DISABLED;
  process.env.ANTHROPIC_API_KEY = "sk-test-must-never-be-used";
  process.env.FORGE_PROXY_TOKEN = "the-old-token-0123456789";
  const realFetch = globalThis.fetch;
  let upstreamCalls = 0;
  globalThis.fetch = (async () => { upstreamCalls++; throw new Error("no upstream call is allowed"); }) as never;
  try {
    const body = { action: "rescore", context: { ideaID: "11111111-1111-4111-8111-111111111111", originalText: "x", title: "t", sources: [] } };
    for (const route of ["action", "research"] as const) {
      const { default: handler } = await import(`../api/${route}.js`);
      const r = fakeRes();
      await handler({ method: "POST", headers: { authorization: "Bearer the-old-token-0123456789" }, body } as never, r.res);
      assert.equal(r.out.status, 401, route);
      assert.equal((r.out.body as { error: { code: string } }).error.code, "unauthorized");
    }
    // Health still says the deployment is alive, and reveals no configuration.
    const { default: health } = await import("../api/health.js");
    const r = fakeRes();
    await health({ method: "GET", headers: { authorization: "Bearer the-old-token-0123456789" } } as never, r.res);
    assert.equal(r.out.status, 200);
    const h = r.out.body as { authorized: boolean; missing?: unknown; models?: unknown };
    assert.equal(h.authorized, false);
    assert.equal(h.missing, undefined);
    assert.equal(h.models, undefined);
    assert.equal(upstreamCalls, 0);
  } finally {
    globalThis.fetch = realFetch;
    delete process.env.FORGE_PROXY_TOKEN;
  }
});

test("nothing in the proxy's code reads the old token", async () => {
  const { readdirSync, readFileSync } = await import("node:fs");
  const root = new URL("../", import.meta.url);
  for (const dir of ["api", "lib", "scripts", "bench", "config"]) {
    for (const name of readdirSync(new URL(dir + "/", root))) {
      if (!name.endsWith(".ts")) continue;
      const src = readFileSync(new URL(`${dir}/${name}`, root), "utf8");
      assert.equal(/process\.env\.FORGE_PROXY_TOKEN|process\.env\[["']FORGE_PROXY_TOKEN/.test(src), false, `${dir}/${name} reads FORGE_PROXY_TOKEN`);
      assert.equal(/Bearer \$\{/.test(src), false, `${dir}/${name} builds a bearer header`);
    }
  }
});

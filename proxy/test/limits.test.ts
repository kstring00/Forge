import { test } from "node:test";
import assert from "node:assert/strict";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { actions, payloadSchemas, withRationale } from "../lib/schemas.js";
import { extractJSON } from "../lib/structured.js";
import { enforcePitch } from "../lib/enforce.js";

/// The structured-output limits from the docs: at most 16 union-typed
/// parameters and 24 optional ones per request. No string formats either:
/// they add grammar, and enforce.ts checks IDs instead.
function measure(schema: unknown) {
  let unions = 0, optional = 0, formats = 0;
  const walk = (node: any) => {
    if (!node || typeof node !== "object") return;
    if (node.format) formats++;
    if (node.properties) {
      const required = new Set<string>(node.required ?? []);
      for (const [k, v] of Object.entries<any>(node.properties)) {
        if (!required.has(k)) optional++;
        if ((Array.isArray(v.type) && v.type.length > 1) || v.anyOf) unions++;
      }
    }
    for (const v of Object.values(node)) if (typeof v === "object") walk(v);
  };
  walk(schema);
  return { unions, optional, formats, bytes: JSON.stringify(schema).length };
}

for (const action of actions) {
  test(`${action}: schema within structured-output limits`, () => {
    const m = measure(zodOutputFormat(withRationale(payloadSchemas[action])).schema);
    assert.ok(m.unions <= 16, `${action} has ${m.unions} union-typed parameters`);
    assert.ok(m.optional <= 24, `${action} has ${m.optional} optional parameters`);
    assert.equal(m.formats, 0, `${action} still carries string formats`);
  });
}

test("extractJSON finds the object inside fences or prose", () => {
  assert.deepEqual(extractJSON('{"a":1}'), { a: 1 });
  assert.deepEqual(extractJSON('Here you go:\n```json\n{"a":{"b":"}"}}\n```'), { a: { b: "}" } });
  assert.deepEqual(extractJSON('x {"s":"a \\"quoted\\" {brace}"} y'), { s: 'a "quoted" {brace}' });
  assert.equal(extractJSON("no json here"), undefined);
  assert.equal(extractJSON('{"unterminated": '), undefined);
});

test("a pitch keeps only source IDs the app sent", () => {
  const known = new Set(["11111111-1111-4111-8111-111111111111"]);
  const out = enforcePitch({ pitches: [{ title: "t", body: "b", forWhom: "f", whyNow: "w", advantageUsed: "a", riskiestAssumption: "r",
    cluster: "recurring", sphere: null, groundedIn: ["11111111-1111-4111-8111-111111111111", "made-up"] }] }, known);
  assert.deepEqual(out.pitches[0].groundedIn, ["11111111-1111-4111-8111-111111111111"]);
});

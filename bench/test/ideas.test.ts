import { test } from "node:test";
import assert from "node:assert/strict";
import { loadIdeas } from "../src/io.js";

test("every idea file is valid, named by its id, and long enough to pass the app's guard", () => {
  const ideas = loadIdeas();
  assert.ok(ideas.length >= 5);
  assert.equal(new Set(ideas.map((i) => i.id)).size, ideas.length);
  for (const i of ideas) {
    assert.ok(i.text.split(/\s+/).length >= 8, `${i.id}: the app blocks ideas under eight words`);
    if (i.key) assert.ok(i.key.competitors.length >= 3, `${i.id}: a key names the true top 3`);
    if (i.kind === "classic") assert.ok(i.outcome, `${i.id}: a classic records what happened`);
  }
});

import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPacket } from "../lib/packet.js";
import { ActionRequest } from "../lib/schemas.js";
import { userTurn } from "../lib/prompts.js";

const notes = `RESEARCH NOTES
COMPETITORS
- Campspot bundles a booking site for parks on its software (https://www.campspot.com/websites)
- RoverPass offers a website only to parks using its reservations https://roverpass.com/websites, also https://www.g2.com/products/roverpass/reviews
## Prices
- Bundled park sites cost $35 to $65 per month https://www.campspot.com/pricing (2026-10-01)
**Complaints:**
- Owners say booking widgets break on mobile — https://www.reddit.com/r/RVLiving/comments/abc
- Parks hate long contracts
DEMAND
- Could not find search volume for "rv park website"
OTHER
That is all I found.`;

test("the research notes become a packet: findings carry their URL, the rest is kept apart", () => {
  const p = buildPacket(notes, [{ url: "https://www.campspot.com/pricing", title: "Campspot pricing", text: "", kind: "searchHit", retrievedAt: null }]);
  assert.deepEqual(p.findings.map((f) => f.section), ["competitors", "competitors", "prices", "complaints"]);
  assert.equal(p.findings[1].url, "https://roverpass.com/websites");
  assert.deepEqual(p.findings[1].alsoURLs, ["https://www.g2.com/products/roverpass/reviews"]);
  assert.equal(p.findings[2].title, "Campspot pricing");
  assert.equal(p.findings[2].text, "Bundled park sites cost $35 to $65 per month (2026-10-01)");
  assert.equal(p.findings[3].text, "Owners say booking widgets break on mobile");
  assert.deepEqual(p.unsourced, ["Parks hate long contracts"], "a claim with no page is never a finding");
  assert.equal(p.gaps.length, 1);
  assert.ok(p.findings.every((f) => f.url.startsWith("https://")));
});

test("the panel reads the packet with each finding's source id; pages arrive by title", () => {
  const A = "11111111-1111-4111-8111-111111111111";
  const ctx = ActionRequest.parse({
    action: "prefill",
    context: {
      ideaID: A, originalText: "x", title: "t",
      sources: [{ id: A, title: "Campspot pricing", sourceClass: "aiFound", reviewed: false, chunks: [] }],
      packet: { researchedAt: "2026-11-09T10:00:00Z", findings: [
        { section: "prices", text: "Bundled sites cost $35 to $65 a month", url: "https://www.campspot.com/pricing", sourceID: A },
        { section: "complaints", text: "Widgets break on mobile", url: "https://x.example/y", sourceID: null },
      ], gaps: ["Could not find search volume"] },
    },
  }).context;
  const turn = userTurn(ctx, undefined);
  assert.ok(turn.includes("RESEARCH PACKET (researched 2026-11-09)"));
  assert.ok(turn.includes(`PRICES:\n- [${A}] Bundled sites cost $35 to $65 a month`));
  assert.ok(turn.includes("- [no id] Widgets break on mobile"));
  assert.ok(turn.includes("THE RESEARCH COULD NOT FIND:\n- Could not find search volume"));
  assert.ok(turn.includes(`--- source id=${A} class=aiFound reviewed=false\nCampspot pricing`));
});

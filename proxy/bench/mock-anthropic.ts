// A stand-in for the Claude API, for checking the pipeline's wiring where no
// API key is available: research returns sectioned notes with URLs, and each
// structured call returns a canned answer of the right shape, citing the ids
// it was given. Its outputs say nothing about quality or real cost.
//
//   npm run bench:checks -- --label mock --mock
import { createServer, type Server } from "node:http";
import { lens, content } from "../lib/content.js";
import { BriefResult, LaunchPlanResult, PrefillResult, ScoreResult, withRationale } from "../lib/schemas.js";

const notes = `RESEARCH NOTES
COMPETITORS
- Campspot bundles a booking site for parks on its software (https://www.campspot.com/websites)
- RoverPass offers a website only to parks using its reservations https://roverpass.com/websites
PRICES
- Bundled park sites cost $35 to $65 per month https://www.campspot.com/pricing
COMPLAINTS
- Owners say booking widgets break on mobile https://www.reddit.com/r/RVLiving/comments/abc
- Reviewers complain about slow support https://www.g2.com/products/campspot/reviews
DEMAND
- Could not find search volume for this exact service
OTHER
- Parks list "website" among top marketing costs https://www.arvc.org/survey-2025`;

function ids(text: string): string[] {
  return [...new Set([...text.matchAll(/(?:id=|\[)([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/g)].map((m) => m[1]))];
}

function score(id: (i: number) => string | null) {
  const keys = lens("business").criteria.map((c) => c.key);
  return {
    criteria: keys.map((key, i) => ({ key, score: 2 + (i % 3), evidenceLevel: 2, note: `Mock note for ${key}.`, sourceIDs: [id(i)].filter(Boolean) as string[] })),
    projection: null, projectionLow: null, projectionHigh: null, projectionBasis: "",
    estimate: {
      price: { low: 35, high: 65, basis: "competitor pricing", sourceID: id(2) },
      reachable: { low: 20, high: 40, basis: "parks on the corridor", sourceID: null },
      conversion: { low: 0.1, high: 0.2, basis: "assumption", sourceID: null },
    },
    panel: ["investor", "customer", "builder", "strategist", "skeptic"].map((sphere, i) => ({
      sphere, verdict: i === 4 ? "cantTell" : "onTrack", criterionKey: keys[i], reason: "Mock reason. Two sentences.",
      sourceIDs: i === 4 ? [] : [id(i)].filter(Boolean), evidenceNeeded: i === 4 ? "What parks pay today, from a park owner." : null,
    })),
    crossfire: [],
  };
}

function brief(id: (i: number) => string | null) {
  return {
    title: "RV park website care",
    realityCheck: {
      verdict: "compete", summary: "Mock summary: crowded, but bundled sites leave a gap.",
      competitors: [{ name: "Campspot", url: "https://www.campspot.com/websites", pricing: "$35–$65/mo", positioning: "bundled", praises: [], complaints: ["widgets break"], tractionSignals: [], sourceID: id(0) }],
      demandSignals: [{ text: "Owners complain about mobile booking", url: null, rung: 2, sourceID: id(3) }],
      gapMap: "Mock gap.", fitNotes: "Mock fit.", experiment: null, costEstimate: "",
    },
    explorations: content.explorePrompts.map((p) => ({ promptKey: p.key, answer: `Mock answer for ${p.key}.`, sourceIDs: [] })),
    riskiestAssumption: { belief: "Parks pay monthly for upkeep.", consequence: "No recurring revenue.", sourceIDs: [] },
    nextMove: { recommendation: "testRiskiestAssumption", step: "Call three park owners this week.", experiment: null },
    draftedAssets: { kind: "interviewQuestions", title: "Five questions", body: "1. When did your site last break?" },
    pivots: [{ whatIf: "What if you sold only to parks on other software?", pivotType: "customerSegment", fixes: "A3", why: "Bundled sites only cover their own parks.", firstTest: "Ask five parks what they use.", sourceIDs: [id(1)].filter(Boolean) as string[] }],
  };
}

function plan(id: (i: number) => string | null) {
  const phase = { title: "Sell to 3 parks", detail: "Visit three.", decide: "If 2 say yes, build." };
  return {
    oneLine: "Website care for RV parks.", forWho: "Small parks.",
    proven: [{ text: "Bundled sites cost $35–$65 a month", sourceID: id(2) }], unproven: ["No park has paid yet"],
    riskiest: "Parks pay monthly", days1to30: phase, days31to60: phase, days61to90: phase,
    customerNoun: "parks", stopRule: "If no park pays by day 45.", stewardNote: null,
  };
}

export function startMock(): Promise<{ url: string; server: Server }> {
  const server = createServer((req, res) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      const body = JSON.parse(raw || "{}");
      const system = (body.system ?? []).map((b: { text: string }) => b.text).join("\n");
      const user = JSON.stringify(body.messages ?? []);
      const found = ids(user);
      const id = (i: number) => (found.length ? found[i % found.length] : null);
      let text: string;
      const cached = system.length > 2000 ? 3000 : 0;
      if (Array.isArray(body.tools) && body.tools.some((t: { name: string }) => t.name === "web_search")) {
        text = notes;
      } else {
        const instruction = (body.system ?? []).at(-1)?.text ?? "";
        const [schema, payload] =
          instruction.startsWith("SCORE.") ? [ScoreResult, score(id)]
          : instruction.startsWith("BRIEF.") ? [BriefResult, brief(id)]
          : instruction.startsWith("PREFILL.") ? [PrefillResult, { ...brief(id), ...score(id) }]
          : instruction.startsWith("LAUNCH PLAN.") ? [LaunchPlanResult, plan(id)]
          : [null, null];
        if (!schema) { res.writeHead(400, { "content-type": "application/json" }); res.end(JSON.stringify({ type: "error", error: { type: "invalid_request_error", message: "mock: unknown instruction" } })); return; }
        const answer = { payload, rationale: "Mock rationale." };
        withRationale(schema as never).parse(answer); // the mock never lies about shape
        text = JSON.stringify(answer);
      }
      res.writeHead(200, { "content-type": "application/json", "request-id": "req_mock" });
      res.end(JSON.stringify({
        id: "msg_mock", type: "message", role: "assistant", model: body.model, stop_reason: "end_turn", stop_sequence: null,
        content: [{ type: "text", text }],
        usage: { input_tokens: 2000, output_tokens: Math.round(text.length / 4), cache_read_input_tokens: cached, cache_creation_input_tokens: cached ? 0 : 1000 },
      }));
    });
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => {
    const a = server.address();
    resolve({ url: `http://127.0.0.1:${typeof a === "object" && a ? a.port : 0}`, server });
  }));
}

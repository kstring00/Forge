// Baseline 2 (§6): IdeaProof's free check, run by hand on the website and
// written down in baselines/ideaproof/<idea-id>.json. See the README there.
import { existsSync, readFileSync } from "node:fs";
import { z } from "zod";
import type { SystemOutput } from "./types.js";

const Captured = z.object({
  capturedAt: z.string(),
  verdict: z.string().nullable().default(null),
  competitors: z.array(z.object({ name: z.string(), url: z.string().nullable().default(null), pricing: z.string().default("") })),
  riskiestAssumption: z.string().default(""),
  theTest: z.string().default(""),
  minutes: z.number().default(0),
});

export function loadIdeaProof(dir: string, ideaId: string): SystemOutput | null {
  const path = `${dir}/${ideaId}.json`;
  if (!existsSync(path)) return null;
  const c = Captured.parse(JSON.parse(readFileSync(path, "utf8")));
  return {
    system: "ideaproof", ideaId, verdict: c.verdict,
    competitors: c.competitors.map((x) => ({ ...x, supported: null })),
    riskiestAssumption: c.riskiestAssumption, theTest: c.theTest,
    costUSD: 0, latencyMs: c.minutes * 60_000, models: ["ideaproof.ai (free check)"], ranAt: c.capturedAt,
  };
}

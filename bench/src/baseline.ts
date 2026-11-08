// Baseline 1 (§6): the same idea pasted into a plain chat model, asked what a
// person would ask. With --baseline-web it may search, like a chatbot with
// search on. A second model only extracts what the answer says into the
// bench's shape; it adds nothing.
import type Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { baselineModel, claude, cost, extractModel, guard, Refused, textOf } from "./claude.js";
import type { BenchIdea, SystemOutput } from "./types.js";

export const question = "Is this a good idea? Who already does this, and what do they charge? What's the riskiest assumption, and what should I do this week to test it?";

const Extracted = z.object({
  verdict: z.enum(["buildIt", "compete", "useTheirs", "cantTell"]).nullable(),
  competitors: z.array(z.object({ name: z.string(), url: z.string().nullable(), pricing: z.string() })),
  riskiestAssumption: z.string(),
  theTest: z.string(),
});

export async function runBaseline(idea: BenchIdea, web: boolean): Promise<SystemOutput> {
  const started = Date.now();
  const system = web ? "baseline-web" : "baseline";
  let spent = 0;
  try {
    const messages: Anthropic.MessageParam[] = [{ role: "user", content: `${idea.text}\n\n${question}` }];
    const tools: Anthropic.ToolUnion[] = web ? [{ type: "web_search_20260209", name: "web_search", max_uses: 5 }] : [];
    let answer = "";
    for (let turn = 0; turn < 4; turn++) {
      const m = guard(await claude().messages.create({
        model: baselineModel, max_tokens: 16000, messages, ...(web ? { tools } : {}),
      }));
      spent += cost(m);
      answer += textOf(m);
      if (m.stop_reason !== "pause_turn") break;
      messages.push({ role: "assistant", content: m.content });
    }

    const x = guard(await claude().messages.parse({
      model: extractModel, max_tokens: 4000,
      system: "Extract from the answer below exactly what it says, nothing more. Competitors: every product or company it names as an alternative, with the price it states in its own words (empty string if none) and a URL only if the answer gives one. verdict: buildIt if it says go build it, compete if crowded but worth it, useTheirs if something already does this well, cantTell if it says to go find out; null if it takes no position. riskiestAssumption and theTest: its words, shortened, never improved.",
      messages: [{ role: "user", content: answer || "(no answer)" }],
      output_config: { format: zodOutputFormat(Extracted) },
    }));
    spent += cost(x);
    const e = x.parsed_output;
    if (!e) throw new Error("the extractor returned nothing usable");
    return {
      system, ideaId: idea.id, verdict: e.verdict,
      competitors: e.competitors.map((c) => ({ ...c, supported: null })),
      riskiestAssumption: e.riskiestAssumption, theTest: e.theTest,
      costUSD: spent, latencyMs: Date.now() - started, models: [baselineModel], ranAt: new Date().toISOString(),
    };
  } catch (err) {
    return failed(system, idea.id, err, spent, started);
  }
}

export function failed(system: string, ideaId: string, err: unknown, spent: number, started: number): SystemOutput {
  return {
    system, ideaId, verdict: null, competitors: [], riskiestAssumption: "", theTest: "",
    costUSD: spent, latencyMs: Date.now() - started, models: [],
    refused: err instanceof Refused, error: err instanceof Error ? err.message : String(err), ranAt: new Date().toISOString(),
  };
}

// Metrics 4 and 5 (§6), graded by a separate model with the key visible. It is
// never told which system wrote what it grades.
import { z } from "zod";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { claude, cost, guard, judgeModel } from "./claude.js";
import type { AnswerKey, JudgeResult, SystemOutput } from "./types.js";

const Verdict = z.object({
  riskMatch: z.enum(["same", "related", "different"]),
  riskWhy: z.string(),
  step: z.object({
    onePerson: z.boolean(),
    withinAWeek: z.boolean(),
    underFifty: z.boolean(),
    concrete: z.boolean(),
    why: z.string(),
  }),
});

const rubric = `You grade one answer about a business idea against a hand-written answer key.

1. riskiestAssumption: compare the answer's riskiest assumption with the key's.
   same: the same belief, even in other words. related: overlaps (same area, a part of it, or a consequence of it). different: another belief, or none given.
2. theTest: the step the answer says to take. Judge it on its own:
   onePerson: one person can do it alone. withinAWeek: it can be finished in seven days. underFifty: it costs under $50. concrete: it says who to reach, what to do or ask, and what result would count.
Give a one-sentence reason for each part. Be strict: vague advice ("validate demand", "do market research") is not concrete.`;

export async function judge(key: AnswerKey, idea: string, out: SystemOutput): Promise<JudgeResult> {
  const m = guard(await claude().messages.parse({
    model: judgeModel, max_tokens: 4000,
    system: rubric,
    output_config: { effort: "high", format: zodOutputFormat(Verdict) },
    messages: [{
      role: "user",
      content: `THE IDEA\n${idea}\n\nTHE KEY\nRiskiest assumption: ${key.riskiestAssumption}\n${key.notes ? `Notes: ${key.notes}\n` : ""}\nTHE ANSWER\nRiskiest assumption: ${out.riskiestAssumption || "(none given)"}\nThe step: ${out.theTest || "(none given)"}`,
    }],
  }));
  const v = m.parsed_output;
  if (!v) throw new Error("the judge returned nothing usable");
  return { ...v, model: m.model, costUSD: cost(m) };
}

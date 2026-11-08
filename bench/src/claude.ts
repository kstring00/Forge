// One client for the baseline, the extractor and the judge. Credentials come
// from the environment (ANTHROPIC_API_KEY, or an `ant auth login` profile).
import Anthropic from "@anthropic-ai/sdk";
import { costUSD } from "../../proxy/lib/pricing.js";

let client: Anthropic | null = null;
export function claude(): Anthropic {
  client ??= new Anthropic({ timeout: 10 * 60_000, maxRetries: 2 });
  return client;
}

/// The plain chat model a person would paste the idea into.
export const baselineModel = process.env.BENCH_BASELINE_MODEL ?? "claude-opus-5-5";
/// Turns the baseline's prose into the bench's shape. Extracts only.
export const extractModel = process.env.BENCH_EXTRACT_MODEL ?? "claude-sonnet-5-5";
/// Grades the riskiest assumption and the test against the key. Never sees which system it grades.
export const judgeModel = process.env.BENCH_JUDGE_MODEL ?? "claude-opus-5-5";

export function textOf(m: Anthropic.Message): string {
  return m.content.filter((b): b is Anthropic.TextBlock => b.type === "text").map((b) => b.text).join("");
}

export function cost(m: Anthropic.Message): number {
  return costUSD(m.model, m.usage);
}

/// A refusal is a result, not something to retry on another model: the bench
/// measures the model it names.
export class Refused extends Error {}
export function guard<T extends Anthropic.Message>(m: T): T {
  if (m.stop_reason === "refusal") throw new Refused(`refused (${m.stop_details?.category ?? "no category"})`);
  if (m.stop_reason === "max_tokens") throw new Error("ran out of tokens before finishing");
  return m;
}

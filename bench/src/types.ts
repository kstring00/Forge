// The bench's shapes. An idea, its hand-written answer key, what a system said
// about it, what the judge made of that, and the scores.
import { z } from "zod";

export const KeyCompetitor = z.object({
  name: z.string().min(1),
  /// Other names it goes by ("Google One" for Google Drive's paid plan).
  aliases: z.array(z.string()).default([]),
  url: z.string().nullable().default(null),
  /// The real price range in USD for the plan a person in this idea would compare against.
  priceLow: z.number().nullable().default(null),
  priceHigh: z.number().nullable().default(null),
  priceNote: z.string().default(""),
});

export const AnswerKey = z.object({
  /// The true top 3 first; more may follow (they count as matches, not misses).
  competitors: z.array(KeyCompetitor).min(1),
  riskiestAssumption: z.string().min(1),
  notes: z.string().default(""),
  keyedBy: z.string().min(1),
  keyedAt: z.string().min(1),
  /// False until a person has checked every price and competitor against the live pages.
  verified: z.boolean(),
});

export const BenchIdea = z.object({
  id: z.string().regex(/^[a-z0-9-]+$/),
  kind: z.enum(["person", "friend", "classic"]),
  title: z.string().min(1),
  /// The idea as the person would say it. Never the answer key's words.
  text: z.string().min(1),
  lens: z.literal("business").default("business"),
  /// For classics: what actually happened.
  outcome: z.string().default(""),
  key: AnswerKey.nullable(),
});

export type KeyCompetitor = z.infer<typeof KeyCompetitor>;
export type AnswerKey = z.infer<typeof AnswerKey>;
export type BenchIdea = z.infer<typeof BenchIdea>;

export interface FoundCompetitor {
  name: string;
  url: string | null;
  pricing: string;
  /// Whether the cited page backs the name and every number (null: no page cited).
  supported: boolean | null;
}

export interface SystemOutput {
  system: string;
  ideaId: string;
  verdict: string | null;
  competitors: FoundCompetitor[];
  riskiestAssumption: string;
  theTest: string;
  costUSD: number;
  latencyMs: number;
  dropped?: Record<string, number>;
  /// The model declined; recorded, not retried on another model.
  refused?: boolean;
  error?: string;
  models: string[];
  ranAt: string;
}

export interface JudgeResult {
  riskMatch: "same" | "related" | "different";
  riskWhy: string;
  step: { onePerson: boolean; withinAWeek: boolean; underFifty: boolean; concrete: boolean; why: string };
  model: string;
  costUSD: number;
}

export interface IdeaScore {
  ideaId: string;
  system: string;
  recall: { hits: number; of: number; matched: string[] };
  sourceTruth: { supported: number; total: number };
  price: { accurate: number; checked: number };
  /// 1 same, 0.5 related, 0 different; null when not judged.
  risk: number | null;
  /// How many of the four step checks pass; null when not judged.
  step: number | null;
  costUSD: number;
  latencyMs: number;
  failed: boolean;
}

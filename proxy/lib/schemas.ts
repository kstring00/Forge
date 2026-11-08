// Typed JSON contracts, mirrored from Forge/Services/AI/AIContracts.swift.
// Structured outputs guarantee the shape; the clamps in `enforce.ts` guarantee
// the honesty rules (desk research never exceeds rung 2, no source → cantTell).
import { z } from "zod";

export const actions = [
  "expand", "summarize", "explainCriterion", "designExperiment", "nextStep", "plan",
  "compare", "pivot", "pitch", "runRound", "realityCheck", "prefill",
] as const;
export type Action = (typeof actions)[number];

/// Request side: the app sends real UUIDs, so validate them.
const uuid = z.string().uuid();
/// Output side: a plain string. A `format` on every ID field adds grammar the
/// structured-output compiler has to build, and `enforce.ts` already drops any
/// ID the app did not send, so the check lives there instead.
const sourceId = z.string();
const recommendation = z.enum(["exploreFurther", "testRiskiestAssumption", "buildSmallPrototype", "startBuilding", "revisitLater", "archive"]);
const verdictKind = z.enum(["onTrack", "offTrack", "cantTell"]);
const sphere = z.enum(["investor", "customer", "builder", "strategist", "skeptic", "steward"]);
const realityVerdict = z.enum(["buildIt", "compete", "useTheirs", "cantTell"]);
const pivotType = z.enum(["zoomIn", "zoomOut", "customerSegment", "customerNeed", "channel", "businessModel", "technology"]);
const cluster = z.enum(["fastCash", "recurring", "asset", "creative", "growth"]);

// Context as the app sends it (AIContext in Swift).
export const ChunkSnapshot = z.object({ id: uuid, index: z.number().int(), text: z.string() });
export const SourceSnapshot = z.object({
  id: uuid, title: z.string(),
  sourceClass: z.enum(["userVerified", "aiFound", "assumption"]),
  reviewed: z.boolean(),
  chunks: z.array(ChunkSnapshot),
});
export const AIContext = z.object({
  ideaID: uuid,
  originalText: z.string(),
  title: z.string(),
  lens: z.enum(["business", "growth", "creative"]).nullable().optional(),
  explorations: z.array(z.string()).default([]),
  scores: z.array(z.object({ key: z.string(), score: z.number().int(), evidenceLevel: z.number().int(), note: z.string() })).default([]),
  sources: z.array(SourceSnapshot).default([]),
  milestones: z.array(z.string()).default([]),
  decisions: z.array(z.string()).default([]),
  openQuestions: z.array(z.string()).default([]),
  advantages: z.array(z.string()).default([]),
  constraints: z.array(z.string()).default([]),
  stewardCharter: z.string().nullable().optional(),
  aboutUser: z.string().nullable().optional(),
  spheres: z.array(sphere).default([...["investor", "customer", "builder", "strategist", "skeptic"]] as z.infer<typeof sphere>[]),
});
export type AIContextT = z.infer<typeof AIContext>;

export const ActionRequest = z.object({
  action: z.enum(actions),
  context: AIContext,
  options: z.record(z.string(), z.unknown()).optional(),
});

// Payloads. Optional fields are nullable (structured outputs require every
// property to be present).
export const ExpandResult = z.object({
  proposedTitle: z.string().nullable(),
  proposedSummary: z.string().nullable(),
  clarifiedText: z.string(),
  openQuestions: z.array(z.string()),
});

export const SummarizeResult = z.object({
  notes: z.array(z.string()),
  decisions: z.array(z.string()),
  openQuestions: z.array(z.string()),
});

export const ExperimentCard = z.object({
  hypothesis: z.string(), test: z.string(), metric: z.string(), cost: z.string(),
  timeboxDays: z.number().int(), decisionRule: z.string(),
});

export const NextStepResult = z.object({ action: z.string(), why: z.string() });

export const ExplainCriterionResult = z.object({ primer: z.string(), rulesForThisIdea: z.array(z.string()) });

export const PlanResult = z.object({
  milestones: z.array(z.object({ title: z.string(), tasks: z.array(z.string()) })),
  firstDeliverable: z.string(),
});

export const CompareResult = z.object({
  lens: z.enum(["business", "growth", "creative"]),
  comparisons: z.array(z.object({ key: z.string(), leftNote: z.string(), rightNote: z.string(), edge: z.enum(["left", "right", "even"]) })),
  verdict: z.string(),
});

export const PivotResult = z.object({
  variants: z.array(z.object({
    pivotType, title: z.string(), body: z.string(), kept: z.string(), changed: z.string(),
    fixesCriterionKey: z.string(), newRiskiestAssumption: z.string(),
  })),
});

export const PitchResult = z.object({
  pitches: z.array(z.object({
    title: z.string(), body: z.string(), forWhom: z.string(), whyNow: z.string(), advantageUsed: z.string(),
    riskiestAssumption: z.string(), cluster, sphere: sphere.nullable(), groundedIn: z.array(sourceId),
  })),
});

export const VerdictDraft = z.object({
  sphere, verdict: verdictKind, criterionKey: z.string(), reason: z.string(),
  sourceIDs: z.array(sourceId), evidenceNeeded: z.string().nullable(),
});
export const CrossfireDraft = z.object({ from: sphere, to: sphere, text: z.string() });
export const RoundResult = z.object({ verdicts: z.array(VerdictDraft), crossfire: z.array(CrossfireDraft) });

export const CompetitorDraft = z.object({
  name: z.string(), url: z.string().nullable(), pricing: z.string(), positioning: z.string(),
  praises: z.array(z.string()), complaints: z.array(z.string()), tractionSignals: z.array(z.string()),
  sourceID: sourceId.nullable(),
});
export const DemandSignalDraft = z.object({ text: z.string(), url: z.string().nullable(), rung: z.number().int(), sourceID: sourceId.nullable() });

export const RealityCheckResult = z.object({
  verdict: realityVerdict,
  summary: z.string(),
  competitors: z.array(CompetitorDraft),
  demandSignals: z.array(DemandSignalDraft),
  gapMap: z.string(),
  fitNotes: z.string(),
  experiment: ExperimentCard.nullable(),
  costEstimate: z.string(),
});

/// One "What if…" pivot: the sentence, its type, the criterion it raises, why, and the first test.
export const PivotDraft = z.object({
  whatIf: z.string(),
  pivotType,
  fixes: z.string(),
  why: z.string(),
  firstTest: z.string(),
  sourceIDs: z.array(sourceId),
});

/// §0A. One typed object that pre-fills the whole Lab, every field carrying source IDs.
export const PrefillResult = z.object({
  /// The idea's name, 2 to 5 plain words. Null only if the idea gives nothing to name.
  title: z.string().nullable(),
  realityCheck: RealityCheckResult,
  explorations: z.array(z.object({ promptKey: z.string(), answer: z.string(), sourceIDs: z.array(sourceId) })),
  criteria: z.array(z.object({ key: z.string(), score: z.number().int(), evidenceLevel: z.number().int(), note: z.string(), sourceIDs: z.array(sourceId) })),
  projection: z.object({
    pricePerUnitLow: z.number(), pricePerUnitHigh: z.number(),
    unitsYearOneLow: z.number().int(), unitsYearOneHigh: z.number().int(),
    rationale: z.string(),
  }).nullable(),
  /// The Investor's estimated return: a monthly range in USD, and what it rests
  /// on in a few words ("competitor pricing", "three pricing pages"). Null when
  /// nothing in the Library supports a figure; the app then shows no number.
  projectionLow: z.number().nullable(),
  projectionHigh: z.number().nullable(),
  projectionBasis: z.string(),
  riskiestAssumption: z.object({ belief: z.string(), consequence: z.string(), sourceIDs: z.array(sourceId) }),
  nextMove: z.object({ recommendation, step: z.string(), experiment: ExperimentCard.nullable() }),
  draftedAssets: z.object({ kind: z.enum(["interviewQuestions", "outreachScript", "landingCopy"]), title: z.string(), body: z.string() }),
  panel: z.array(VerdictDraft),
  crossfire: z.array(CrossfireDraft),
  /// "What if…" pivots (decision 0024): two or three when the idea is weak, grounded in the Library; empty otherwise.
  pivots: z.array(PivotDraft),
});

export const payloadSchemas = {
  expand: ExpandResult,
  summarize: SummarizeResult,
  explainCriterion: ExplainCriterionResult,
  designExperiment: ExperimentCard,
  nextStep: NextStepResult,
  plan: PlanResult,
  compare: CompareResult,
  pivot: PivotResult,
  pitch: PitchResult,
  runRound: RoundResult,
  realityCheck: RealityCheckResult,
  prefill: PrefillResult,
} satisfies Record<Action, z.ZodTypeAny>;

/// What goes back to the app: the payload, a short rationale, and accounting.
export interface Envelope<T> {
  payload: T;
  rationale: string;
  model: string;
  /// List items the contract or the source rules removed, by list. Absent when none.
  dropped?: Record<string, number>;
  usage: { inputTokens: number; outputTokens: number; cacheReadTokens: number; cacheWriteTokens: number; webSearches: number };
  costUSD: number;
}

/// The model writes the payload and the rationale together.
export function withRationale<T extends z.ZodTypeAny>(payload: T) {
  return z.object({ payload, rationale: z.string() });
}

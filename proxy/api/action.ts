import type { VercelRequest, VercelResponse } from "@vercel/node";
import type { z } from "zod";
import { HttpError, rateLimit, readJSON, requireAuth, requireMethod, sendError } from "../lib/http.js";
import { costUSD, round4 } from "../lib/pricing.js";
import { ActionRequest, BriefResult, ScoreResult, payloadSchemas, withRationale, type Action, type Envelope } from "../lib/schemas.js";
import { actionInstruction, briefInstruction, panelSystem, scoreInstruction, userTurn } from "../lib/prompts.js";
import { enforceLaunchPlan, enforcePitch, enforcePrefill, enforceRealityCheck, enforceRound, enforceScore } from "../lib/enforce.js";
import { content, lens } from "../lib/content.js";
import { callStructured } from "../lib/structured.js";
import { effortFor, modelFor, type Role } from "../lib/config.js";

/// Which role (and so which model, from config/hunch.ts) runs each action.
/// A check's prefill runs two roles: scoring, then brief.
const roleFor: Record<Action, Role> = {
  expand: "fast", summarize: "fast", explainCriterion: "fast", nextStep: "fast",
  rescore: "scoring", runRound: "scoring",
  prefill: "brief",
  launchPlan: "plan", plan: "plan", designExperiment: "plan", compare: "plan", pivot: "plan", pitch: "plan", realityCheck: "plan",
};

/// Output budget per call. Thinking counts against it on models that think.
const maxTokensFor = (a: Action | "score" | "brief") =>
  a === "prefill" ? 24000 : a === "brief" ? 20000 : a === "runRound" || a === "realityCheck" ? 12000 : 8000;

/// One model call's accounting, for the app's cost meter (Settings → Developer).
export interface Stage {
  stage: "scoring" | "brief" | "followUp" | "other";
  model: string;
  costUSD: number;
  usage: Envelope<unknown>["usage"];
}

interface Run<T> { payload: T; rationale: string; stage: Stage; mode: string; dropped: Record<string, number> }

async function run<T extends z.ZodTypeAny>(role: Role, label: string, stage: Stage["stage"], lensType: string, instruction: string, user: string,
                                           schema: T, maxTokens: number): Promise<Run<z.infer<T>>> {
  const model = modelFor(role);
  const result = await callStructured({
    label, model, maxTokens,
    effort: effortFor(role),
    system: panelSystem(lensType, instruction),
    user,
    schema: withRationale(schema),
    // Under the function's maxDuration in vercel.json.
    timeoutMs: 270_000,
  });
  const u = result.response.usage;
  return {
    payload: (result.parsed as { payload: z.infer<T> }).payload,
    rationale: (result.parsed as { rationale: string }).rationale,
    mode: result.mode,
    dropped: result.dropped,
    stage: {
      stage, model: result.response.model,
      costUSD: round4(costUSD(model, u)),
      usage: {
        inputTokens: u.input_tokens,
        outputTokens: u.output_tokens,
        cacheReadTokens: u.cache_read_input_tokens ?? 0,
        cacheWriteTokens: u.cache_creation_input_tokens ?? 0,
        webSearches: 0,
      },
    },
  };
}

/// What the five panelists decided, for the Brief writer to read.
export function scoresText(s: z.infer<typeof ScoreResult>, lensType: string): string {
  const titles = new Map(lens(lensType).criteria.map((c) => [c.key, c.title]));
  const ids = (xs: string[]) => (xs.length ? ` [${xs.join(", ")}]` : " [no source]");
  const lines = ["PANEL SCORES (the five panelists, from the same packet; 1 to 5, evidence level 0 to 2 from a desk):"];
  for (const c of s.criteria) lines.push(`- ${c.key} ${titles.get(c.key) ?? ""}: score ${c.score}, evidence ${c.evidenceLevel}${ids(c.sourceIDs)}. ${c.note}`);
  lines.push("VERDICTS:");
  for (const v of s.panel) lines.push(`- ${v.sphere} on ${v.criterionKey}: ${v.verdict}. ${v.reason}${v.evidenceNeeded ? ` Needs: ${v.evidenceNeeded}` : ""}${ids(v.sourceIDs)}`);
  if (s.estimate) {
    const e = s.estimate;
    const f = (name: string, x: typeof e.price) => `${name} ${x.low}–${x.high} (${x.basis}; ${x.sourceID ? `source ${x.sourceID}` : "assumption"})`;
    lines.push(`ESTIMATE: ${f("price per month", e.price)}, ${f("reachable in year one", e.reachable)}, ${f("share who pay", e.conversion)}.`);
  }
  return lines.join("\n");
}

/// POST /api/action — one typed action, one typed envelope back.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    requireMethod(req, "POST");
    requireAuth(req);
    rateLimit();

    const parsed = ActionRequest.safeParse(readJSON(req));
    if (!parsed.success) {
      throw new HttpError(400, "bad_request", "Request did not match the contract: " + parsed.error.issues.map((i) => i.path.join(".") + " " + i.message).join("; "));
    }
    const { action, context, options } = parsed.data;
    const lensType = context.lens ?? "business";
    const known = new Set(context.sources.map((s) => s.id));
    const lensKeys = lens(lensType).criteria.map((c) => c.key);
    const user = userTurn(context, options);

    let payload: unknown;
    let rationale: string;
    let stages: Stage[];
    const dropped: Record<string, number> = {};
    const modes: string[] = [];

    if (action === "prefill") {
      ({ payload, rationale, stages } = await prefill(user, lensType, known, lensKeys, dropped, modes));
    } else {
      const role = roleFor[action];
      const r = await run(role, `action.${action}`, action === "rescore" ? "scoring" : action === "launchPlan" ? "followUp" : "other",
                          lensType, actionInstruction(action), user, payloadSchemas[action], maxTokensFor(action));
      Object.assign(dropped, r.dropped);
      modes.push(r.mode);
      payload = r.payload;
      rationale = r.rationale;
      stages = [r.stage];
      if (action === "runRound") payload = enforceRound(payload as never, known);
      if (action === "realityCheck") payload = enforceRealityCheck(payload as never, known, dropped);
      if (action === "pitch") payload = enforcePitch(payload as never, known);
      if (action === "launchPlan") payload = enforceLaunchPlan(payload as never, known, dropped);
      if (action === "rescore") payload = enforceScore(payload as never, known, lensKeys);
    }

    const sum = (k: keyof Stage["usage"]) => stages.reduce((a, s) => a + s.usage[k], 0);
    const envelope: Envelope<unknown> & { stages: Stage[] } = {
      payload,
      rationale,
      model: stages[stages.length - 1].model,
      usage: {
        inputTokens: sum("inputTokens"),
        outputTokens: sum("outputTokens"),
        cacheReadTokens: sum("cacheReadTokens"),
        cacheWriteTokens: sum("cacheWriteTokens"),
        webSearches: 0,
      },
      costUSD: round4(stages.reduce((a, s) => a + s.costUSD, 0)),
      dropped: Object.keys(dropped).length ? dropped : undefined,
      stages,
    };
    const fallback = modes.find((m) => m !== "structured");
    if (fallback) res.setHeader("X-Forge-Mode", fallback === "jsonRetry" ? "json-retry" : "json-fallback");
    if (Object.keys(dropped).length) console.warn(JSON.stringify({ at: `action.${action}`, dropped }));
    res.status(200).json(envelope);
  } catch (err) {
    sendError(res, err, "action");
  }
}

/// A check (decision 0042): the five panelists score on the scoring model,
/// then the brief model writes the panel's take from the same packet and
/// those scores. Merged into one PrefillResult, so the app is unchanged.
async function prefill(user: string, lensType: string, known: Set<string>, lensKeys: string[],
                       dropped: Record<string, number>, modes: string[]) {
  const score = await run("scoring", "action.prefill.score", "scoring", lensType, scoreInstruction, user, ScoreResult, maxTokensFor("score"));
  const scored = enforceScore(score.payload, known, lensKeys);
  const brief = await run("brief", "action.prefill.brief", "brief", lensType, briefInstruction, `${user}\n\n${scoresText(scored, lensType)}`, BriefResult, maxTokensFor("brief"));
  for (const r of [score, brief]) { Object.assign(dropped, r.dropped); modes.push(r.mode); }
  const merged = { ...brief.payload, ...scored };
  const payload = enforcePrefill(merged, known, lensKeys, content.explorePrompts.map((p) => p.key), dropped);
  return { payload, rationale: brief.rationale, stages: [score.stage, brief.stage] };
}

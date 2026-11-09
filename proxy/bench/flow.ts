// What the app does for one check, in this version of the code, step for
// step: RealityCheckRunner.run (research turns, saveResearch, the prefill) and
// the follow-ups. When the app's flow changes, this file changes with it, so
// a bench run at any commit measures that commit's pipeline.
import researchHandler from "../api/research.js";
import actionHandler from "../api/action.js";
import { call, source, type BenchSource, type StageCost } from "./harness.js";

export const flowVersion = "before: research turns + one prefill on the sphere model";

export interface Idea { slug: string; id: string; title: string; text: string }

export interface CheckRecord {
  flowVersion: string;
  idea: Idea;
  stages: StageCost[];
  research: { turns: number; notes: string; sources: { kind: string; url: string; title: string }[] };
  library: { id: string; title: string; url: string | null; kind: string }[];
  prefill: any;
  rationale: string;
  dropped?: Record<string, number>;
  followUps: { kind: string; payload: any; stage: StageCost }[];
  errors: string[];
}

const maxResearchTurns = 4;

function stageFrom(stage: string, body: any, ms: number): StageCost {
  const u = body.usage ?? {};
  return {
    stage, model: body.model ?? "", costUSD: body.costUSD ?? 0,
    inputTokens: u.inputTokens ?? 0, outputTokens: u.outputTokens ?? 0,
    cacheReadTokens: u.cacheReadTokens ?? 0, cacheWriteTokens: u.cacheWriteTokens ?? 0,
    webSearches: u.webSearches ?? 0, ms,
  };
}

/// AIContext.make(for:) for a fresh idea: no lens, no explorations, every Library source.
function context(idea: Idea, library: BenchSource[]) {
  return {
    ideaID: idea.id, originalText: idea.text, title: idea.title,
    sources: library.map((s) => ({ id: s.id, title: s.title, sourceClass: s.sourceClass, reviewed: s.reviewed, chunks: s.chunks })),
  };
}

export async function runCheck(idea: Idea, opts: { followUps: boolean }): Promise<CheckRecord> {
  const rec: CheckRecord = { flowVersion, idea, stages: [], research: { turns: 0, notes: "", sources: [] }, library: [], prefill: null, rationale: "", followUps: [], errors: [] };

  // 1. Research, one turn per call, while paused.
  let messages: unknown[] | undefined;
  const gathered: any[] = [];
  for (let turn = 1; turn <= maxResearchTurns; turn++) {
    const t0 = Date.now();
    const r = await call(researchHandler as never, { idea: { id: idea.id, title: idea.title, originalText: idea.text }, advantages: [], constraints: [], messages });
    if (r.status !== 200) { rec.errors.push(`research ${r.status}: ${JSON.stringify(r.body).slice(0, 300)}`); return rec; }
    rec.stages.push(stageFrom("research", r.body, Date.now() - t0));
    rec.research.turns = turn;
    gathered.push(...r.body.sources);
    if (r.body.notes) rec.research.notes = r.body.notes;
    if (r.body.status === "done") break;
    messages = r.body.messages;
  }
  rec.research.sources = gathered.map((s) => ({ kind: s.kind, url: s.url, title: s.title }));

  // 2. saveResearch: fetched and noted pages with text, once per URL, then the notes.
  const library: BenchSource[] = [];
  const seen = new Set<string>();
  for (const s of gathered) {
    if ((s.kind === "fetched" || s.kind === "noted") && s.text && !seen.has(s.url)) {
      seen.add(s.url);
      library.push(source(s.title || s.url, s.text, s.url, "web"));
    }
  }
  if (rec.research.notes.trim()) library.push(source("Research notes", rec.research.notes.trim(), null, "text"));
  rec.library = library.map((s) => ({ id: s.id, title: s.title, url: s.url, kind: s.kind }));

  // 3. The prefill: one call writes the panel, the scores and the Brief.
  const t0 = Date.now();
  const p = await call(actionHandler as never, { action: "prefill", context: context(idea, library) });
  if (p.status !== 200) { rec.errors.push(`prefill ${p.status}: ${JSON.stringify(p.body).slice(0, 300)}`); return rec; }
  rec.stages.push(stageFrom("prefill", p.body, Date.now() - t0));
  rec.prefill = p.body.payload;
  rec.rationale = p.body.rationale;
  rec.dropped = p.body.dropped;

  if (!opts.followUps) return rec;

  // 4. Follow-ups on the checked idea: a launch plan, and a re-score after a logged conversation.
  const t1 = Date.now();
  const plan = await call(actionHandler as never, { action: "launchPlan", context: context(idea, library), options: { paid: "No one has paid yet." } });
  if (plan.status === 200) rec.followUps.push({ kind: "launchPlan", payload: plan.body.payload, stage: stageFrom("followUp", plan.body, Date.now() - t1) });
  else rec.errors.push(`launchPlan ${plan.status}: ${JSON.stringify(plan.body).slice(0, 300)}`);

  const talk = source("Conversation · bench", "A potential customer said this is a real weekly problem and asked what it would cost. They agreed to a follow-up call next week.", null, "note", "userVerified");
  talk.reviewed = true;
  const t2 = Date.now();
  const re = await call(actionHandler as never, { action: "prefill", context: context(idea, [...library, talk]) });
  if (re.status === 200) rec.followUps.push({ kind: "rescore", payload: { criteria: re.body.payload.criteria }, stage: stageFrom("followUp", re.body, Date.now() - t2) });
  else rec.errors.push(`rescore ${re.status}: ${JSON.stringify(re.body).slice(0, 300)}`);
  return rec;
}

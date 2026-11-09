// What the app does for one check, in this version of the code, step for
// step: RealityCheckRunner.run (research turns, saveResearch, the prefill) and
// the follow-ups. When the app's flow changes, this file changes with it, so
// a bench run at any commit measures that commit's pipeline.
import researchHandler from "../api/research.js";
import actionHandler from "../api/action.js";
import { call, source, type BenchSource, type StageCost } from "./harness.js";

export const flowVersion = "B: packet → scoring model scores, brief model writes the Brief; re-score is scoring only";

export interface Idea { slug: string; id: string; title: string; text: string }

export interface CheckRecord {
  flowVersion: string;
  idea: Idea;
  stages: StageCost[];
  research: { turns: number; notes: string; sources: { kind: string; url: string; title: string }[]; packet?: any };
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

/// AIContext.make(for:packet:) for a fresh idea: with a packet, web pages go by
/// title only and the person's own sources in full; findings carry the id of
/// the source with their page's address.
function context(idea: Idea, library: BenchSource[], packet?: any, researchedAt?: string) {
  const lean = (s: BenchSource) => packet && s.sourceClass !== "userVerified";
  const byURL = new Map<string, string>();
  for (const s of library) if (s.url && !byURL.has(s.url)) byURL.set(s.url, s.id);
  return {
    ideaID: idea.id, originalText: idea.text, title: idea.title,
    sources: library.map((s) => ({ id: s.id, title: s.title, sourceClass: s.sourceClass, reviewed: s.reviewed, chunks: lean(s) ? [] : s.chunks })),
    packet: packet ? {
      researchedAt: researchedAt ?? null,
      findings: packet.findings.map((f: any) => ({ section: f.section, text: f.text, url: f.url, sourceID: [f.url, ...f.alsoURLs].map((u: string) => byURL.get(u)).find(Boolean) ?? null })),
      gaps: packet.gaps,
    } : null,
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
    if (r.body.packet) rec.research.packet = r.body.packet;
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

  const researchedAt = new Date().toISOString();
  // 3. The prefill reads the packet.
  const t0 = Date.now();
  const p = await call(actionHandler as never, { action: "prefill", context: context(idea, library, rec.research.packet, researchedAt) });
  if (p.status !== 200) { rec.errors.push(`prefill ${p.status}: ${JSON.stringify(p.body).slice(0, 300)}`); return rec; }
  const ms = Date.now() - t0;
  if (Array.isArray(p.body.stages)) {
    for (const st of p.body.stages) rec.stages.push(stageFrom(st.stage, st, ms / p.body.stages.length));
  } else {
    rec.stages.push(stageFrom("prefill", p.body, ms));
  }
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
  const re = await call(actionHandler as never, { action: "rescore", context: context(idea, [...library, talk]) });
  if (re.status === 200) rec.followUps.push({ kind: "rescore", payload: { criteria: re.body.payload.criteria }, stage: stageFrom("followUp", re.body, Date.now() - t2) });
  else rec.errors.push(`rescore ${re.status}: ${JSON.stringify(re.body).slice(0, 300)}`);
  return rec;
}

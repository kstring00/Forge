// The engine as the app runs it: desk research one turn per call through the
// proxy, then the Spheres' prefill over the Library. Same endpoints, same
// shapes, a developer token instead of App Attest.
import { randomUUID } from "node:crypto";
import type { BenchIdea, FoundCompetitor, SystemOutput } from "./types.js";
import { sourceSupports } from "./score.js";

export interface ProxyConfig { url: string; token: string }

export function proxyConfig(): ProxyConfig {
  const url = process.env.PROXY_URL?.replace(/\/$/, "");
  const token = process.env.PROXY_TOKEN;
  if (!url || !token) throw new Error("Set PROXY_URL (your Vercel URL) and PROXY_TOKEN (a developer token from FORGE_DEV_TOKENS or FORGE_PROXY_TOKEN).");
  return { url, token };
}

interface ResearchSource { url: string; title: string; text: string; kind: "fetched" | "searchHit" }
interface ResearchResponse { status: "done" | "paused"; messages: unknown[]; sources: ResearchSource[]; notes: string; model: string; costUSD: number }
interface Envelope { payload: any; rationale: string; model: string; costUSD?: number; dropped?: Record<string, number> }

async function post<T>(cfg: ProxyConfig, path: string, body: unknown, timeoutMs: number): Promise<T> {
  const res = await fetch(`${cfg.url}/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${cfg.token}` },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${path} answered ${res.status}: ${text.slice(0, 400)}`);
  return JSON.parse(text) as T;
}

/// The app's chunker (PrefillApplier.chunks): paragraphs packed to about 1,200 characters.
export function chunks(text: string, target = 1200): string[] {
  const out: string[] = [];
  let current = "";
  for (const raw of text.split("\n\n")) {
    const p = raw.trim();
    if (!p) continue;
    if (current.length + p.length + 2 > target && current) { out.push(current); current = ""; }
    if (p.length > target * 2) {
      for (let i = 0; i < p.length; i += target) out.push(p.slice(i, i + target));
      continue;
    }
    current = current ? `${current}\n\n${p}` : p;
  }
  if (current) out.push(current);
  return out;
}

export interface EngineRun { output: SystemOutput; pages: Record<string, { url: string; title: string; text: string }> }

export async function runEngine(idea: BenchIdea, cfg: ProxyConfig, maxTurns = 4): Promise<EngineRun> {
  const started = Date.now();
  const ideaID = randomUUID();
  let spent = 0;
  const models = new Set<string>();

  // 1. Research, one turn per call, as RealityCheckRunner does.
  let messages: unknown[] | undefined;
  const gathered: ResearchSource[] = [];
  let notes = "";
  for (let turn = 1; turn <= maxTurns; turn++) {
    const r = await post<ResearchResponse>(cfg, "api/research", {
      idea: { id: ideaID, title: idea.title, originalText: idea.text }, advantages: [], constraints: [], messages,
    }, 130_000);
    spent += r.costUSD ?? 0;
    models.add(r.model);
    gathered.push(...r.sources);
    if (r.notes) notes = r.notes;
    if (r.status === "done") break;
    messages = r.messages;
  }

  // 2. The Library the Spheres read: fetched pages and the research notes.
  const pages: EngineRun["pages"] = {};
  const seen = new Set<string>();
  const sources = [];
  for (const s of gathered) {
    if (s.kind !== "fetched" || !s.text || seen.has(s.url)) continue;
    seen.add(s.url);
    const id = randomUUID();
    pages[id] = { url: s.url, title: s.title || s.url, text: s.text };
    sources.push({ id, title: s.title || s.url, sourceClass: "aiFound", reviewed: false,
                   chunks: chunks(s.text).map((text, index) => ({ id: randomUUID(), index, text })) });
  }
  if (notes.trim()) {
    const id = randomUUID();
    pages[id] = { url: "", title: "Research notes", text: notes };
    sources.push({ id, title: "Research notes", sourceClass: "aiFound", reviewed: false,
                   chunks: chunks(notes).map((text, index) => ({ id: randomUUID(), index, text })) });
  }

  // 3. The prefill: verdict, competitors, riskiest assumption, next move.
  const env = await post<Envelope>(cfg, "api/action", {
    action: "prefill",
    context: { ideaID, originalText: idea.text, title: idea.title, lens: "business", sources },
  }, 290_000);
  spent += env.costUSD ?? 0;
  models.add(env.model);

  const p = env.payload ?? {};
  const competitors: FoundCompetitor[] = (p.realityCheck?.competitors ?? []).map((c: any) => {
    const page = c.sourceID ? pages[c.sourceID] : undefined;
    return { name: String(c.name ?? ""), url: c.url ?? page?.url ?? null, pricing: String(c.pricing ?? ""),
             supported: page ? sourceSupports(c.name ?? "", c.pricing ?? "", page.text) : false };
  });
  const step = [p.nextMove?.step, p.nextMove?.experiment?.test, p.nextMove?.experiment?.decisionRule].filter(Boolean).join(" · ");
  return {
    output: {
      system: "engine", ideaId: idea.id, verdict: p.realityCheck?.verdict ?? null, competitors,
      riskiestAssumption: p.riskiestAssumption?.belief ?? "", theTest: step,
      costUSD: spent, latencyMs: Date.now() - started, dropped: env.dropped, models: [...models], ranAt: new Date().toISOString(),
    },
    pages,
  };
}

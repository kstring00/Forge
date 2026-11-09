// Calls the proxy's own handlers in-process, exactly as Vercel would, so a
// bench run exercises the real prompts, models, schemas and enforcement.
// Nothing here talks to the app; `flow.ts` mirrors what the app does between
// calls (saving sources, building the context).
import { randomUUID } from "node:crypto";

type Handler = (req: unknown, res: unknown) => Promise<void> | void;

export interface Reply<T = any> { status: number; body: T; headers: Record<string, string> }

export function prepareEnv(): void {
  if (!process.env.ANTHROPIC_API_KEY) {
    throw new Error("No API key. In this Terminal window run:  set -a; source .env; set +a  (then try again). The bench calls the real Claude API.");
  }
  process.env.FORGE_PROXY_TOKEN ||= "bench-token";
  process.env.FORGE_REQUESTS_PER_MINUTE ||= "1000";
}

export function call<T = any>(handler: Handler, body: unknown, method = "POST"): Promise<Reply<T>> {
  return new Promise((resolve, reject) => {
    const res = {
      statusCode: 200,
      headers: {} as Record<string, string>,
      status(c: number) { this.statusCode = c; return this; },
      setHeader(k: string, v: string) { this.headers[k] = v; },
      json(b: T) { resolve({ status: this.statusCode, body: b, headers: this.headers }); },
    };
    const req = { method, headers: { authorization: `Bearer ${process.env.FORGE_PROXY_TOKEN}` }, body };
    Promise.resolve(handler(req, res)).catch(reject);
  });
}

/// The app's Source, as AIContext sends it.
export interface BenchSource {
  id: string;
  title: string;
  url: string | null;
  sourceClass: "userVerified" | "aiFound" | "assumption";
  reviewed: boolean;
  kind: string;
  fullText: string;
  chunks: { id: string; index: number; text: string }[];
}

/// PrefillApplier.chunks: paragraph-aware chunks of roughly 1,200 characters.
export function chunks(text: string, target = 1200): string[] {
  const out: string[] = [];
  let current = "";
  for (const para of text.split("\n\n")) {
    const p = para.trim();
    if (!p) continue;
    if (current.length + p.length + 2 > target && current) { out.push(current); current = ""; }
    if (p.length > target * 2) {
      if (current) { out.push(current); current = ""; }
      for (let i = 0; i < p.length; i += target) out.push(p.slice(i, i + target));
      continue;
    }
    current = current ? `${current}\n\n${p}` : p;
  }
  if (current) out.push(current);
  return out;
}

export function source(title: string, text: string, url: string | null, kind: string, cls: BenchSource["sourceClass"] = "aiFound"): BenchSource {
  return {
    id: randomUUID(), title, url, sourceClass: cls, reviewed: false, kind, fullText: text,
    chunks: chunks(text).map((t, i) => ({ id: randomUUID(), index: i, text: t })),
  };
}

export interface StageCost {
  stage: string;
  model: string;
  costUSD: number;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  webSearches: number;
  ms: number;
}

export function sumStages(stages: StageCost[]) {
  const by = (s: string) => stages.filter((x) => x.stage === s).reduce((a, x) => a + x.costUSD, 0);
  const total = stages.reduce((a, x) => a + x.costUSD, 0);
  const read = stages.reduce((a, x) => a + x.cacheReadTokens, 0);
  const promptTokens = stages.reduce((a, x) => a + x.inputTokens + x.cacheReadTokens + x.cacheWriteTokens, 0);
  return {
    totalUSD: total,
    researchUSD: by("research"),
    scoringUSD: by("scoring"),
    briefUSD: by("brief") + by("prefill"),
    followUpUSD: by("followUp"),
    cacheHitRate: promptTokens ? read / promptTokens : 0,
    searches: stages.reduce((a, x) => a + x.webSearches, 0),
  };
}

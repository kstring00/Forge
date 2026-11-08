// Pure scoring (docs/ENGINE.md §6). No network, no model. Tested in test/score.test.ts.
import type { AnswerKey, FoundCompetitor, IdeaScore, JudgeResult, KeyCompetitor, SystemOutput } from "./types.js";

const filler = new Set(["the", "inc", "llc", "ltd", "co", "app", "com", "io", "hq", "by", "and"]);

/// "Dropbox, Inc." → "dropbox"; "Google One (Drive)" → "google one drive".
export function normalize(name: string): string {
  return name
    .toLowerCase()
    .replace(/\.(com|io|co|app|ai|net|org)\b/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .split(" ")
    .filter((w) => w && !filler.has(w))
    .join(" ")
    .trim();
}

function host(url: string | null | undefined): string | null {
  if (!url) return null;
  try { return new URL(url).hostname.replace(/^www\./, ""); } catch { return null; }
}

/// Same company: equal names, one name containing the other (whole words), an
/// alias, or the same website.
export function sameCompetitor(key: KeyCompetitor, found: Pick<FoundCompetitor, "name" | "url">): boolean {
  const f = normalize(found.name);
  if (!f) return false;
  for (const n of [key.name, ...key.aliases].map(normalize).filter(Boolean)) {
    if (n === f) return true;
    const [short, long] = n.length <= f.length ? [n, f] : [f, n];
    if (short.length >= 4 && ` ${long} `.includes(` ${short} `)) return true;
  }
  const kh = host(key.url), fh = host(found.url);
  return Boolean(kh && fh && (kh === fh || fh.endsWith("." + kh)));
}

/// Metric 1: of the key's true top 3, how many the system named.
export function competitorRecall(key: AnswerKey, found: FoundCompetitor[]): IdeaScore["recall"] {
  const top = key.competitors.slice(0, 3);
  const matched = top.filter((k) => found.some((f) => sameCompetitor(k, f))).map((k) => k.name);
  return { hits: matched.length, of: top.length, matched };
}

/// Every dollar figure in a string: "$9.99/mo", "$1,299", "USD 19", "$1.2k", "149 dollars".
export function parsePrices(text: string): number[] {
  const out: number[] = [];
  const num = (s: string, k?: string) => {
    const n = Number(s.replace(/,/g, ""));
    if (Number.isFinite(n)) out.push(k ? n * 1000 : n);
  };
  for (const m of text.matchAll(/(?:US\$|\$|USD\s?)\s?(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s?([kK])?\b/g)) num(m[1], m[2]);
  for (const m of text.matchAll(/\b(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s?(?:USD|dollars)\b/g)) num(m[1]);
  return out;
}

/// Metric 3 for one competitor: any stated price within 15% of the real range.
export function priceAccurate(key: KeyCompetitor, pricing: string): boolean | null {
  if (key.priceLow == null && key.priceHigh == null) return null;
  const lo = key.priceLow ?? key.priceHigh!, hi = key.priceHigh ?? key.priceLow!;
  const stated = parsePrices(pricing);
  if (stated.length === 0) return null;
  return stated.some((p) => p >= lo * 0.85 && p <= hi * 1.15);
}

export function priceScore(key: AnswerKey, found: FoundCompetitor[]): IdeaScore["price"] {
  let accurate = 0, checked = 0;
  for (const k of key.competitors) {
    const f = found.find((x) => sameCompetitor(k, x));
    if (!f) continue;
    const ok = priceAccurate(k, f.pricing);
    if (ok == null) continue;
    checked++;
    if (ok) accurate++;
  }
  return { accurate, checked };
}

/// Bench v0's stand-in for metric 2 until the verification gate gives every
/// claim a quoted passage: the cited page must contain the competitor's name
/// and every dollar figure the system states for it. No page, not supported.
export function sourceSupports(name: string, pricing: string, pageText: string | null): boolean {
  if (!pageText) return false;
  const page = ` ${normalize(pageText)} `;
  const n = normalize(name);
  if (!n || !page.includes(` ${n} `)) {
    // Allow the first two words of a long name ("Google One storage plans" → "google one").
    const head = n.split(" ").slice(0, 2).join(" ");
    if (head.length < 4 || !page.includes(` ${head} `)) return false;
  }
  const raw = pageText.replace(/,/g, "");
  return parsePrices(pricing).every((p) => {
    const forms = [String(p), p.toFixed(2), Number.isInteger(p) ? `${p}.00` : null].filter(Boolean) as string[];
    return forms.some((f) => new RegExp(`(^|[^0-9.])${f.replace(".", "\\.")}([^0-9]|$)`).test(raw));
  });
}

export function sourceTruth(found: FoundCompetitor[]): IdeaScore["sourceTruth"] {
  return { supported: found.filter((f) => f.supported === true).length, total: found.length };
}

export function riskScore(j: JudgeResult | null): number | null {
  if (!j) return null;
  return j.riskMatch === "same" ? 1 : j.riskMatch === "related" ? 0.5 : 0;
}

export function stepScore(j: JudgeResult | null): number | null {
  if (!j) return null;
  const s = j.step;
  return [s.onePerson, s.withinAWeek, s.underFifty, s.concrete].filter(Boolean).length;
}

export function scoreIdea(key: AnswerKey, out: SystemOutput, judge: JudgeResult | null): IdeaScore {
  const failed = Boolean(out.error || out.refused);
  return {
    ideaId: out.ideaId,
    system: out.system,
    recall: failed ? { hits: 0, of: Math.min(3, key.competitors.length), matched: [] } : competitorRecall(key, out.competitors),
    sourceTruth: sourceTruth(out.competitors),
    price: priceScore(key, out.competitors),
    risk: failed ? 0 : riskScore(judge),
    step: failed ? 0 : stepScore(judge),
    costUSD: out.costUSD,   // the judge's cost is the bench's, not the system's
    latencyMs: out.latencyMs,
    failed,
  };
}

export interface SystemTotals {
  system: string;
  ideas: number;
  recall: { hits: number; of: number };
  sourceTruthPct: number | null;
  price: { accurate: number; checked: number };
  riskAvg: number | null;
  stepPass: { pass: number; judged: number };
  meanCostUSD: number;
  meanLatencyMs: number;
  failed: number;
}

export function totals(scores: IdeaScore[]): SystemTotals[] {
  const bySystem = new Map<string, IdeaScore[]>();
  for (const s of scores) bySystem.set(s.system, [...(bySystem.get(s.system) ?? []), s]);
  return [...bySystem.entries()].map(([system, ss]) => {
    const claims = ss.reduce((a, s) => a + s.sourceTruth.total, 0);
    const risks = ss.map((s) => s.risk).filter((r): r is number => r != null);
    const steps = ss.map((s) => s.step).filter((r): r is number => r != null);
    return {
      system,
      ideas: ss.length,
      recall: { hits: ss.reduce((a, s) => a + s.recall.hits, 0), of: ss.reduce((a, s) => a + s.recall.of, 0) },
      sourceTruthPct: claims ? (100 * ss.reduce((a, s) => a + s.sourceTruth.supported, 0)) / claims : null,
      price: { accurate: ss.reduce((a, s) => a + s.price.accurate, 0), checked: ss.reduce((a, s) => a + s.price.checked, 0) },
      riskAvg: risks.length ? risks.reduce((a, b) => a + b, 0) / risks.length : null,
      stepPass: { pass: steps.filter((n) => n === 4).length, judged: steps.length },
      meanCostUSD: ss.reduce((a, s) => a + s.costUSD, 0) / ss.length,
      meanLatencyMs: ss.reduce((a, s) => a + s.latencyMs, 0) / ss.length,
      failed: ss.filter((s) => s.failed).length,
    };
  });
}

export interface Gate {
  verdict: "ship" | "hold" | "incomplete";
  lines: string[];
}

/// §6: ship engine v2 only if it beats both baselines on competitor recall,
/// source truth and riskiest-assumption match, and source truth is 100%.
export function gate(t: SystemTotals[], baselines = ["baseline", "ideaproof"]): Gate {
  const engine = t.find((x) => x.system === "engine");
  const missing = baselines.filter((b) => !t.some((x) => x.system === b));
  const lines: string[] = [];
  if (!engine) return { verdict: "incomplete", lines: ["The engine did not run."] };
  if (missing.length) lines.push(`Missing baseline${missing.length > 1 ? "s" : ""}: ${missing.join(", ")}.`);
  let beatsAll = true;
  for (const b of t.filter((x) => baselines.includes(x.system))) {
    const recall = rate(engine.recall) > rate(b.recall);
    const truth = (engine.sourceTruthPct ?? 0) > (b.sourceTruthPct ?? 0);
    const risk = (engine.riskAvg ?? 0) > (b.riskAvg ?? 0);
    lines.push(`Against ${b.system}: recall ${mark(recall)}, source truth ${mark(truth)}, riskiest assumption ${mark(risk)}.`);
    beatsAll &&= recall && truth && risk;
  }
  const perfect = engine.sourceTruthPct === 100;
  lines.push(`Source truth ${engine.sourceTruthPct == null ? "not measured" : engine.sourceTruthPct.toFixed(0) + "%"}${perfect ? "" : " (must be 100% to ship)"}.`);
  if (missing.length) return { verdict: "incomplete", lines };
  return { verdict: beatsAll && perfect ? "ship" : "hold", lines };
}

const rate = (r: { hits: number; of: number }) => (r.of ? r.hits / r.of : 0);
const mark = (b: boolean) => (b ? "beats" : "does not beat");

// The report every engine PR carries: totals per system, the ship gate, then
// every idea. Re-rendered from saved files with `npm run report -- <label>`.
import { join } from "node:path";
import { existsSync, readdirSync, writeFileSync } from "node:fs";
import { gate, scoreIdea, totals, type SystemTotals } from "./score.js";
import { loadIdeas, readJSON, resultsDir, writeJSON } from "./io.js";
import type { IdeaScore, JudgeResult, SystemOutput } from "./types.js";

export const target = 15;

export function render(label: string): string {
  const dir = join(resultsDir, label);
  const ideas = loadIdeas();
  const keyed = ideas.filter((i) => i.key);
  const scores: IdeaScore[] = [];
  const outDir = join(dir, "outputs");
  for (const idea of keyed) {
    if (!existsSync(outDir)) continue;
    for (const f of readdirSync(outDir).filter((name) => name.startsWith(`${idea.id}.`))) {
      const out = readJSON<SystemOutput>(join(outDir, f))!;
      const j = readJSON<JudgeResult>(join(dir, "judge", f));
      scores.push(scoreIdea(idea.key!, out, j));
    }
  }
  const t = totals(scores);
  const g = gate(t);
  writeJSON(join(dir, "summary.json"), { label, keyed: keyed.length, ideas: ideas.length, totals: t, gate: g, scores });

  const lines: string[] = [];
  lines.push(`# Bench · ${label}`, "");
  lines.push(`Keyed ideas: **${keyed.length} of ${target}** (${ideas.length} idea files; unkeyed ones are not scored).`);
  const unverified = keyed.filter((i) => !i.key!.verified).map((i) => i.id);
  if (unverified.length) lines.push(`Unverified keys: ${unverified.join(", ")}. Prices and competitors in these are drafts until a person checks them.`);
  lines.push("", `**Gate: ${g.verdict.toUpperCase()}.** ${g.lines.join(" ")}`, "");
  lines.push("| System | Ideas | 1 · Competitor recall | 2 · Source truth | 3 · Price within 15% | 4 · Riskiest assumption | 5 · Step usable | 6 · Cost / run | 6 · Latency | Failed |");
  lines.push("|---|---|---|---|---|---|---|---|---|---|");
  for (const s of t) lines.push(row(s));
  lines.push("", "Source truth in Bench v0: a claim counts when the page it cites contains the competitor's name and every dollar figure stated for it. A claim with no cited page does not count. The verification gate (engine step 2) replaces this with quoted passages.");
  lines.push("", "## By idea", "", "| Idea | System | Recall | Matched | Source truth | Price | Risk | Step | Cost | Note |", "|---|---|---|---|---|---|---|---|---|---|");
  for (const s of [...scores].sort((a, b) => a.ideaId.localeCompare(b.ideaId) || a.system.localeCompare(b.system))) {
    const out = readJSON<SystemOutput>(join(outDir, `${s.ideaId}.${s.system}.json`))!;
    lines.push(`| ${s.ideaId} | ${s.system} | ${s.recall.hits}/${s.recall.of} | ${s.recall.matched.join(", ") || "–"} | ${s.sourceTruth.supported}/${s.sourceTruth.total} | ${s.price.accurate}/${s.price.checked} | ${s.risk ?? "–"} | ${s.step ?? "–"}/4 | $${s.costUSD.toFixed(3)} | ${note(out)} |`);
  }
  const md = lines.join("\n") + "\n";
  writeFileSync(join(dir, "report.md"), md);
  return md;
}

function row(s: SystemTotals): string {
  const pct = (a: number, b: number) => (b ? `${a}/${b} (${Math.round((100 * a) / b)}%)` : "–");
  return `| ${s.system} | ${s.ideas} | ${pct(s.recall.hits, s.recall.of)} | ${s.sourceTruthPct == null ? "–" : s.sourceTruthPct.toFixed(0) + "%"} | ${pct(s.price.accurate, s.price.checked)} | ${s.riskAvg == null ? "–" : s.riskAvg.toFixed(2)} | ${pct(s.stepPass.pass, s.stepPass.judged)} | $${s.meanCostUSD.toFixed(3)} | ${(s.meanLatencyMs / 1000).toFixed(0)} s | ${s.failed} |`;
}

function note(out: SystemOutput): string {
  if (out.refused) return `refused: ${out.error}`;
  if (out.error) return `error: ${out.error.slice(0, 80).replace(/\|/g, "/")}`;
  const d = out.dropped ? Object.values(out.dropped).reduce((a, b) => a + b, 0) : 0;
  return [out.verdict ?? "", d ? `${d} dropped` : ""].filter(Boolean).join(" · ");
}

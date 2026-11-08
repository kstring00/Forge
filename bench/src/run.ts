// npm run bench -- [--systems engine,baseline,baseline-web,ideaproof] [--ideas a,b] [--label name] [--rerun] [--include-unkeyed] --yes
//
// Runs each system on each keyed idea, saves what it said, has the judge grade
// it, and writes results/<label>/report.md. Re-running a label reuses saved
// outputs unless --rerun. Every model call costs money: the plan prints first
// and nothing runs without --yes.
import { join } from "node:path";
import { runEngine, proxyConfig } from "./engine.js";
import { failed, runBaseline } from "./baseline.js";
import { judge } from "./judge.js";
import { loadIdeaProof } from "./ideaproof.js";
import { ideaproofDir, loadIdeas, readJSON, resultsDir, writeJSON } from "./io.js";
import { render } from "./report.js";
import type { JudgeResult, SystemOutput } from "./types.js";

const args = process.argv.slice(2);
const opt = (name: string) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
const flag = (name: string) => args.includes(`--${name}`);

const systems = (opt("systems") ?? "engine,baseline,ideaproof").split(",").map((s) => s.trim());
const only = opt("ideas")?.split(",").map((s) => s.trim());
const label = opt("label") ?? new Date().toISOString().slice(0, 16).replace(/[:T]/g, "-");
const dir = join(resultsDir, label);

const all = loadIdeas();
const ideas = all.filter((i) => (!only || only.includes(i.id)) && (i.key || flag("include-unkeyed")));
const paid = systems.filter((s) => s !== "ideaproof");
console.log(`Bench ${label}: ${ideas.length} ideas × ${systems.join(", ")}. ${all.filter((i) => i.key).length} of ${all.length} idea files are keyed.`);
console.log(`Paid runs: ${ideas.length * paid.length} (engine about $0.15–0.30 each, baseline about $0.05–0.20) plus one judge call per scored output.`);
if (!flag("yes")) {
  console.log("Nothing has run. Add --yes to spend.");
  process.exit(0);
}

for (const idea of ideas) {
  for (const system of systems) {
    const outPath = join(dir, "outputs", `${idea.id}.${system}.json`);
    let out = flag("rerun") ? null : readJSON<SystemOutput>(outPath);
    if (!out) {
      const started = Date.now();
      process.stdout.write(`${idea.id} · ${system} … `);
      try {
        if (system === "engine") {
          const r = await runEngine(idea, proxyConfig());
          out = r.output;
          writeJSON(join(dir, "raw", `${idea.id}.engine.pages.json`), r.pages);
        } else if (system === "baseline" || system === "baseline-web") {
          out = await runBaseline(idea, system === "baseline-web");
        } else if (system === "ideaproof") {
          out = loadIdeaProof(ideaproofDir, idea.id);
          if (!out) { console.log("not captured (see baselines/ideaproof/README.md)"); continue; }
        } else {
          throw new Error(`unknown system ${system}`);
        }
      } catch (err) {
        out = failed(system, idea.id, err, 0, started);
      }
      writeJSON(outPath, out);
      console.log(out.error ? `failed: ${out.error}` : `${out.competitors.length} competitors · $${out.costUSD.toFixed(3)} · ${(out.latencyMs / 1000).toFixed(0)} s`);
    }
    const judgePath = join(dir, "judge", `${idea.id}.${system}.json`);
    if (idea.key && !out.error && (flag("rerun") || !readJSON<JudgeResult>(judgePath))) {
      try { writeJSON(judgePath, await judge(idea.key, idea.text, out)); }
      catch (err) { console.log(`  judge failed on ${idea.id}.${system}: ${err instanceof Error ? err.message : err}`); }
    }
  }
}

console.log("\n" + render(label));
console.log(`Saved: results/${label}/report.md`);

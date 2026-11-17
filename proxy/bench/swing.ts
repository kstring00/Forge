// How steady is Potential? Researches each sample idea more than once and
// scores each research more than once, on the real Claude API, then reports
// how far the same idea's Potential moves. This is the ruler for the Potential
// fix: run it before the change and after, then compare.
//
//   npm run bench:swing -- --label potential-before
//   npm run bench:swing -- --label potential-after
//   npm run bench:swing-report -- potential-before potential-after
//
// Options: --research 2 (fresh research passes per idea), --scores 3
// (scorings per pass), --only rv-park-sites (one idea), --mock (a stand-in
// API, wiring only). Results land in bench/results/<label>/swing/.
//
// Cost with the defaults, five ideas: about $1.25 (research is about 11¢ a
// pass; a scoring is under 1¢). No Brief, launch plan or re-score is run.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { prepareEnv, type StageCost } from "./harness.js";
import { potential, report, type IdeaRuns } from "./swing-stats.js";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const flag = (name: string) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
const label = flag("label") ?? "swing";
const only = flag("only");
const passes = Math.max(1, Number(flag("research") ?? 2));
const scoringsPerPass = Math.max(1, Number(flag("scores") ?? 3));

const mock = args.includes("--mock") ? await (await import("./mock-anthropic.js")).startMock() : null;
if (mock) {
  process.env.ANTHROPIC_BASE_URL = mock.url;
  process.env.ANTHROPIC_API_KEY = "mock";
}
prepareEnv();

// The proxy logs one JSON line per call. Keep them in the results folder, not on screen.
const logLines: string[] = [];
for (const level of ["log", "warn", "error"] as const) {
  const original = console[level].bind(console);
  console[level] = (...a: unknown[]) => {
    if (typeof a[0] === "string" && a[0].startsWith('{"at":')) logLines.push(a[0]);
    else original(...a);
  };
}
const { research, score, flowVersion } = await import("./flow.js");

const ideas = (JSON.parse(readFileSync(join(here, "ideas.json"), "utf8")) as { slug: string; id: string; title: string; text: string }[])
  .filter((i) => !only || i.slug === only);
const out = join(here, "results", label, "swing");
mkdirSync(out, { recursive: true });

console.log(`${ideas.length} ideas × ${passes} research passes × ${scoringsPerPass} scorings. This takes a while; each line is one idea.\n`);
const runs: IdeaRuns[] = [];
let spent = 0;
for (const idea of ideas) {
  process.stdout.write(`${idea.slug} … `);
  const record: any = { flowVersion, idea, passes: [] as any[], errors: [] as string[] };
  for (let p = 0; p < passes; p++) {
    const rec = { stages: [] as StageCost[], research: { turns: 0, notes: "", sources: [] as any[], packet: undefined as any }, library: [] as any[], errors: [] as string[] };
    const researched = await research(idea, rec);
    spent += rec.stages.reduce((a, s) => a + s.costUSD, 0);
    if (!researched) { record.errors.push(...rec.errors); continue; }
    const pass: any = { researchUSD: rec.stages.reduce((a, s) => a + s.costUSD, 0), findings: researched.packet?.findings?.length ?? 0, pages: researched.library.filter((s) => s.url).length, scorings: [] };
    // One at a time: the second and later scorings then read the first one's cached prompt, as in the app.
    for (let s = 0; s < scoringsPerPass; s++) {
      const r = await score(idea, researched);
      if ("error" in r) { record.errors.push(r.error); continue; }
      spent += r.stage.costUSD;
      const criteria = r.criteria.map((c: any) => ({ key: c.key, score: c.score, evidenceLevel: c.evidenceLevel, note: c.note }));
      pass.scorings.push({ potential: potential(criteria), criteria, verdicts: r.panel.map((v: any) => `${v.sphere}:${v.verdict}`), costUSD: r.stage.costUSD });
    }
    record.passes.push(pass);
  }
  writeFileSync(join(out, `${idea.slug}.json`), JSON.stringify(record, null, 2));
  runs.push({ slug: idea.slug, title: idea.title, passes: record.passes });
  const shown = record.passes.map((p: any) => p.scorings.map((s: any) => s.potential).join(", ")).join(" · ");
  console.log(`${shown || "no scores"}${record.errors.length ? ` · errors: ${record.errors.join(" | ")}` : ""}`);
}
writeFileSync(join(out, "log.jsonl"), logLines.join("\n") + "\n");
const text = report([label], [runs]);
writeFileSync(join(out, "report.md"), text);
console.log(`\n${text}\nSpent about $${spent.toFixed(2)}. Saved to bench/results/${label}/swing/ (report.md is the table above).`);
mock?.server.close();

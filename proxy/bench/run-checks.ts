// Runs the five sample ideas through this commit's check pipeline against the
// real Claude API and saves every output, so two commits can be compared.
//
//   ANTHROPIC_API_KEY=sk-... npm run bench:checks -- --label before
//   ANTHROPIC_API_KEY=sk-... npm run bench:checks -- --label after
//   npm run bench:compare -- before after
//
// Options: --only rv-park-sites (one idea), --no-follow-ups (skip the launch
// plan and re-score), --mock (a stand-in API, wiring only). Results land in
// bench/results/<label>/.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { prepareEnv, sumStages } from "./harness.js";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const flag = (name: string) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
const label = flag("label") ?? "run";
const only = flag("only");
const followUps = !args.includes("--no-follow-ups");

// --mock: a stand-in Claude API (bench/mock-anthropic.ts) to check the wiring
// without a key. Its numbers say nothing about real cost or quality.
const mock = args.includes("--mock") ? await (await import("./mock-anthropic.js")).startMock() : null;
if (mock) {
  process.env.ANTHROPIC_BASE_URL = mock.url;
  process.env.ANTHROPIC_API_KEY = "mock";
}
prepareEnv();
// Imported after the environment is ready: the handlers read it on use.
const { runCheck, flowVersion } = await import("./flow.js");

const ideas = (JSON.parse(readFileSync(join(here, "ideas.json"), "utf8")) as { slug: string; id: string; title: string; text: string }[])
  .filter((i) => !only || i.slug === only);
const out = join(here, "results", label);
mkdirSync(out, { recursive: true });

const summary: any[] = [];
for (const idea of ideas) {
  process.stdout.write(`${idea.slug} … `);
  const started = Date.now();
  try {
    const rec = await runCheck(idea, { followUps });
    writeFileSync(join(out, `${idea.slug}.json`), JSON.stringify(rec, null, 2));
    const check = sumStages(rec.stages);
    const fu = rec.followUps.map((f) => f.stage.costUSD);
    summary.push({ slug: idea.slug, ...check, followUpAvgUSD: fu.length ? fu.reduce((a, b) => a + b, 0) / fu.length : 0, seconds: (Date.now() - started) / 1000, errors: rec.errors });
    console.log(`$${check.totalUSD.toFixed(4)} · ${rec.errors.length ? `errors: ${rec.errors.join(" | ")}` : "ok"}`);
  } catch (e) {
    console.log(`failed: ${(e as Error).message}`);
    summary.push({ slug: idea.slug, failed: (e as Error).message });
  }
}
writeFileSync(join(out, "summary.json"), JSON.stringify({ label, flowVersion, at: new Date().toISOString(), ideas: summary }, null, 2));
console.log(`\nSaved to bench/results/${label}/`);
mock?.server.close();

// The Potential steadiness table from saved swing runs, for one label or a
// before/after pair. Calls nothing; reads bench/results/<label>/swing/.
//
//   npm run bench:swing-report -- potential-before
//   npm run bench:swing-report -- potential-before potential-after
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { report, type IdeaRuns } from "./swing-stats.js";

const here = dirname(fileURLToPath(import.meta.url));
const labels = process.argv.slice(2).filter((a) => !a.startsWith("--"));
if (!labels.length || labels.length > 2) { console.error("Usage: npm run bench:swing-report -- <label> [<label-after>]"); process.exit(1); }

const ideas = JSON.parse(readFileSync(join(here, "ideas.json"), "utf8")) as { slug: string; title: string }[];
const load = (label: string): IdeaRuns[] => ideas.flatMap((i) => {
  const p = join(here, "results", label, "swing", `${i.slug}.json`);
  if (!existsSync(p)) return [];
  const rec = JSON.parse(readFileSync(p, "utf8"));
  return [{ slug: i.slug, title: i.title, passes: rec.passes ?? [] }];
});
const runs = labels.map(load);
runs.forEach((r, k) => { if (!r.length) { console.error(`No swing results for "${labels[k]}". Run: npm run bench:swing -- --label ${labels[k]}`); process.exit(1); } });
console.log("\n" + report(labels, runs));

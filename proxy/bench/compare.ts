// Before/after table from two bench runs: cost per check by stage, and the
// quality signals that can be counted (scores, what the claims cite, what
// kind of pages). The words (Brief, next step, What-ifs) are printed side by
// side for a person to read; counting can't judge them.
//
//   npm run bench:compare -- before after
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { sumStages } from "./harness.js";

const here = dirname(fileURLToPath(import.meta.url));
const [a, b] = process.argv.slice(2);
if (!a || !b) { console.error("Usage: npm run bench:compare -- <label-a> <label-b>"); process.exit(1); }

const ideas = JSON.parse(readFileSync(join(here, "ideas.json"), "utf8")) as { slug: string; title: string }[];
const load = (label: string, slug: string) => {
  const p = join(here, "results", label, `${slug}.json`);
  return existsSync(p) ? JSON.parse(readFileSync(p, "utf8")) : null;
};

const reviewHosts = ["g2.com", "capterra.com", "trustpilot.com", "yelp.com", "tripadvisor.com", "apps.apple.com", "play.google.com", "producthunt.com", "getapp.com", "softwareadvice.com", "bbb.org", "glassdoor.com", "consumerreports.org", "sitejabber.com", "reviews.io"];
const discussionHosts = ["reddit.com", "quora.com", "news.ycombinator.com", "twitter.com", "x.com", "facebook.com", "tiktok.com", "youtube.com", "medium.com", "substack.com", "stackexchange.com", "stackoverflow.com", "discord.com", "linkedin.com", "threads.net", "instagram.com"];
/// EvidenceRank.classify, as in ForgeCore.
function rank(url: string | null): string {
  if (!url) return "opinion";
  let host = "";
  try { host = new URL(url).hostname.toLowerCase().replace(/^www\./, ""); } catch { return "opinion"; }
  const path = url.toLowerCase();
  if (reviewHosts.some((h) => host === h || host.endsWith("." + h) || path.includes(h)) || path.includes("/reviews")) return "reviewed";
  if (discussionHosts.some((h) => host === h || host.endsWith("." + h)) || host.startsWith("forum") || host.startsWith("community") || path.includes("/forum") || path.includes("/community/") || path.includes("/threads/") || path.includes("/discussion")) return "discussed";
  return "published";
}
const weight: Record<string, number> = { published: 0.4, reviewed: 0.35, discussed: 0.2, opinion: 0 };

function quality(rec: any) {
  const p = rec?.prefill;
  if (!p) return null;
  const lib = new Map<string, any>(rec.library.map((s: any) => [s.id, s]));
  const crit = p.criteria ?? [];
  const potential = crit.length ? Math.round(((crit.reduce((s: number, c: any) => s + c.score, 0) / crit.length - 1) / 4) * 100) : 0;
  // DeskGrade.level: 1 + the best weight per site, capped at 2, per criterion.
  const desk = crit.map((c: any) => {
    const best = new Map<string, number>();
    for (const id of c.sourceIDs ?? []) {
      const s = lib.get(id);
      if (!s) continue;
      const w = weight[rank(s.url)];
      if (!w) continue;
      let site = "unknown";
      try { site = new URL(s.url).hostname.replace(/^www\./, ""); } catch { /* keep */ }
      best.set(site, Math.max(best.get(site) ?? 0, w));
    }
    return best.size ? Math.min(2, 1 + [...best.values()].reduce((x, y) => x + y, 0)) : Math.min(Math.max(c.evidenceLevel, 0), 1);
  });
  const confidence = desk.length ? Math.round((desk.reduce((x: number, y: number) => x + y, 0) / desk.length / 5) * 100) : 0;
  const cited = new Set<string>();
  const add = (ids: string[] | undefined) => (ids ?? []).forEach((i) => cited.add(i));
  crit.forEach((c: any) => add(c.sourceIDs));
  (p.panel ?? []).forEach((v: any) => add(v.sourceIDs));
  (p.realityCheck?.competitors ?? []).forEach((c: any) => c.sourceID && cited.add(c.sourceID));
  (p.realityCheck?.demandSignals ?? []).forEach((d: any) => d.sourceID && cited.add(d.sourceID));
  (p.pivots ?? []).forEach((x: any) => add(x.sourceIDs));
  const citedSources = [...cited].map((id) => lib.get(id)).filter(Boolean);
  const notesOnly = citedSources.filter((s: any) => s.title === "Research notes").length;
  const pages = citedSources.filter((s: any) => s.url);
  return {
    verdict: p.realityCheck?.verdict,
    potential, confidence,
    criteriaWithPage: crit.filter((c: any) => (c.sourceIDs ?? []).some((id: string) => lib.get(id)?.url)).length,
    criteria: crit.length,
    citedPages: pages.length,
    citedNotesOnly: notesOnly,
    reviewOrPublished: pages.filter((s: any) => ["reviewed", "published"].includes(rank(s.url))).length,
    competitors: (p.realityCheck?.competitors ?? []).length,
    competitorsSourced: (p.realityCheck?.competitors ?? []).filter((c: any) => c.sourceID).length,
    demandSignals: (p.realityCheck?.demandSignals ?? []).length,
    cantTell: (p.panel ?? []).filter((v: any) => v.verdict === "cantTell").length,
    pivots: (p.pivots ?? []).length,
    next: p.nextMove?.step ?? "",
    risk: p.riskiestAssumption?.belief ?? "",
    summary: p.realityCheck?.summary ?? "",
    whatIfs: (p.pivots ?? []).map((x: any) => x.whatIf),
    dropped: rec.dropped ?? {},
  };
}

const money = (n: number) => `$${n.toFixed(3)}`;
const pct = (n: number) => `${Math.round(n * 100)}%`;

console.log(`\n## Cost per check: ${a} → ${b}\n`);
console.log("| Idea | Total | Research | Scoring | Brief | Searches | Cache hits | Follow-up avg |");
console.log("| --- | --- | --- | --- | --- | --- | --- | --- |");
const totals: Record<string, number[]> = { [a]: [], [b]: [] };
for (const idea of ideas) {
  for (const label of [a, b]) {
    const rec = load(label, idea.slug);
    if (!rec) { console.log(`| ${idea.title} (${label}) | missing | | | | | | |`); continue; }
    const s = sumStages(rec.stages);
    const fu = rec.followUps.map((f: any) => f.stage.costUSD);
    totals[label].push(s.totalUSD);
    console.log(`| ${idea.title} (${label}) | ${money(s.totalUSD)} | ${money(s.researchUSD)} | ${money(s.scoringUSD)} | ${money(s.briefUSD)} | ${s.searches} | ${pct(s.cacheHitRate)} | ${fu.length ? money(fu.reduce((x: number, y: number) => x + y, 0) / fu.length) : "–"} |`);
  }
}
const avg = (xs: number[]) => (xs.length ? xs.reduce((x, y) => x + y, 0) / xs.length : 0);
console.log(`\nAverage per check: ${a} ${money(avg(totals[a]))} · ${b} ${money(avg(totals[b]))}` +
  (avg(totals[a]) ? ` (${Math.round((1 - avg(totals[b]) / avg(totals[a])) * 100)}% cheaper)` : ""));

console.log(`\n## Quality signals\n`);
console.log("| Idea | Run | Verdict | Potential | Confidence | Criteria citing a page | Pages cited | Reviews/published | Notes-only cites | Competitors (sourced) | Can't tell | What-ifs |");
console.log("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |");
for (const idea of ideas) {
  for (const label of [a, b]) {
    const q = quality(load(label, idea.slug));
    if (!q) { console.log(`| ${idea.title} | ${label} | missing | | | | | | | | | |`); continue; }
    console.log(`| ${idea.title} | ${label} | ${q.verdict} | ${q.potential} | ${q.confidence} | ${q.criteriaWithPage} of ${q.criteria} | ${q.citedPages} | ${q.reviewOrPublished} | ${q.citedNotesOnly} | ${q.competitors} (${q.competitorsSourced}) | ${q.cantTell} | ${q.pivots} |`);
  }
}

console.log(`\n## Words, side by side (read these)\n`);
for (const idea of ideas) {
  console.log(`### ${idea.title}`);
  for (const label of [a, b]) {
    const q = quality(load(label, idea.slug));
    if (!q) continue;
    console.log(`**${label}** — ${q.summary}\n- Riskiest: ${q.risk}\n- Next step: ${q.next}\n- What-ifs: ${q.whatIfs.join(" / ")}\n- Dropped by the server: ${JSON.stringify(q.dropped)}\n`);
  }
}

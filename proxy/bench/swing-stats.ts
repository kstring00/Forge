// How steady Potential is, from repeated scoring of the same ideas. Pure
// functions over saved runs, so they are tested without calling anything.
//
// One idea is researched more than once ("passes"), and each pass is scored
// more than once. That separates the two places a score can move:
// - within a pass: the same research, scored again (the scoring's own noise)
// - between passes: different research on the same idea

export interface Criterion { key: string; score: number; evidenceLevel?: number }
export interface Scoring { potential: number; criteria: Criterion[] }
export interface Pass { scorings: Scoring[] }
export interface IdeaRuns { slug: string; title: string; passes: Pass[] }

/// Scoring.potential in ForgeCore: the mean of the 1-to-5 scores, on 0 to 100.
export function potential(criteria: Criterion[]): number {
  if (!criteria.length) return 0;
  const mean = criteria.reduce((s, c) => s + Math.min(5, Math.max(1, c.score)), 0) / criteria.length;
  return Math.round(((mean - 1) / 4) * 100);
}

/// PotentialBand.word in ForgeCore.
export function band(p: number): string {
  return p < 20 ? "Unproven" : p < 40 ? "Modest" : p < 60 ? "Promising" : p < 80 ? "Strong" : "Big";
}

const mean = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
const range = (xs: number[]) => (xs.length ? Math.max(...xs) - Math.min(...xs) : 0);
const round1 = (n: number) => Math.round(n * 10) / 10;

export interface IdeaStats {
  slug: string;
  title: string;
  /// Every Potential, pass by pass.
  potentials: number[][];
  mean: number;
  /// Highest minus lowest over every scoring of this idea.
  swing: number;
  /// The largest highest-minus-lowest inside one pass: the scoring's own noise.
  swingSameResearch: number;
  /// Highest minus lowest of the passes' averages: what fresh research moves.
  swingBetweenResearch: number;
  /// How many different words ("Unproven", "Modest", …) the same idea got.
  bands: string[];
}

export function ideaStats(idea: IdeaRuns): IdeaStats {
  const potentials = idea.passes.map((p) => p.scorings.map((s) => s.potential)).filter((p) => p.length);
  const all = potentials.flat();
  return {
    slug: idea.slug,
    title: idea.title,
    potentials,
    mean: round1(mean(all)),
    swing: range(all),
    swingSameResearch: potentials.length ? Math.max(...potentials.map(range)) : 0,
    swingBetweenResearch: round1(range(potentials.map(mean))),
    bands: [...new Set(all.map(band))],
  };
}

export interface CriterionStats {
  key: string;
  mean: number;
  /// Share of all scorings that gave this criterion a 1, from 0 to 1.
  shareAtOne: number;
  /// Average, over ideas, of highest minus lowest for this criterion.
  averageSwing: number;
}

export function criterionStats(ideas: IdeaRuns[]): CriterionStats[] {
  const keys = [...new Set(ideas.flatMap((i) => i.passes.flatMap((p) => p.scorings.flatMap((s) => s.criteria.map((c) => c.key)))))].sort();
  return keys.map((key) => {
    const perIdea = ideas.map((i) => i.passes.flatMap((p) => p.scorings.flatMap((s) => s.criteria.filter((c) => c.key === key).map((c) => c.score)))).filter((xs) => xs.length);
    const all = perIdea.flat();
    return {
      key,
      mean: round1(mean(all)),
      shareAtOne: all.length ? all.filter((x) => x <= 1).length / all.length : 0,
      averageSwing: round1(mean(perIdea.map(range))),
    };
  });
}

export interface Overall {
  ideas: number;
  scorings: number;
  /// The headline: the average, over ideas, of highest minus lowest.
  averageSwing: number;
  worstSwing: number;
  averageSwingSameResearch: number;
  averageSwingBetweenResearch: number;
  /// Ideas whose runs landed on more than one word.
  ideasChangingBand: number;
  /// Across ideas: the highest idea average minus the lowest. Different ideas should differ.
  spreadBetweenIdeas: number;
  meanPotential: number;
  /// Share of all scorings under 20 ("Unproven"), from 0 to 1.
  shareInLowestBand: number;
}

export function overall(ideas: IdeaRuns[]): Overall {
  const stats = ideas.map(ideaStats).filter((s) => s.potentials.length);
  const all = stats.flatMap((s) => s.potentials.flat());
  return {
    ideas: stats.length,
    scorings: all.length,
    averageSwing: round1(mean(stats.map((s) => s.swing))),
    worstSwing: stats.length ? Math.max(...stats.map((s) => s.swing)) : 0,
    averageSwingSameResearch: round1(mean(stats.map((s) => s.swingSameResearch))),
    averageSwingBetweenResearch: round1(mean(stats.map((s) => s.swingBetweenResearch))),
    ideasChangingBand: stats.filter((s) => s.bands.length > 1).length,
    spreadBetweenIdeas: round1(range(stats.map((s) => s.mean))),
    meanPotential: round1(mean(all)),
    shareInLowestBand: all.length ? all.filter((p) => p < 20).length / all.length : 0,
  };
}

/// The target for the Potential fix (decision 0045): the same idea should land
/// within `maxSwing` points however often it is checked, and never on two
/// different words from the same research.
export const target = { maxSwing: 8, maxSwingSameResearch: 5 };

export function meetsTarget(o: Overall): boolean {
  return o.ideas > 0 && o.worstSwing <= target.maxSwing && o.averageSwingSameResearch <= target.maxSwingSameResearch;
}

/// The report, as Markdown. `labels` and `runs` go together; one or two runs.
export function report(labels: string[], runs: IdeaRuns[][]): string {
  const out: string[] = [];
  const pct = (n: number) => `${Math.round(n * 100)}%`;
  const os = runs.map(overall);
  out.push(`## How steady Potential is: ${labels.join(" → ")}\n`);
  out.push(`| | ${labels.join(" | ")} |`);
  out.push(`| --- | ${labels.map(() => "---").join(" | ")} |`);
  const row = (name: string, f: (o: Overall) => string) => out.push(`| ${name} | ${os.map(f).join(" | ")} |`);
  row("Ideas, scorings", (o) => `${o.ideas}, ${o.scorings}`);
  row("**Average swing on the same idea** (points)", (o) => `**${o.averageSwing}**`);
  row("Worst swing on one idea", (o) => `${o.worstSwing}`);
  row("Swing with the same research (scoring only)", (o) => `${o.averageSwingSameResearch}`);
  row("Swing from fresh research", (o) => `${o.averageSwingBetweenResearch}`);
  row("Ideas that got two different words", (o) => `${o.ideasChangingBand} of ${o.ideas}`);
  row("Average Potential", (o) => `${o.meanPotential}`);
  row("Scorings under 20 (\"Unproven\")", (o) => pct(o.shareInLowestBand));
  row("Gap between the highest and lowest idea", (o) => `${o.spreadBetweenIdeas}`);
  row(`Meets the target (worst swing ≤ ${target.maxSwing}, same-research ≤ ${target.maxSwingSameResearch})`, (o) => (meetsTarget(o) ? "yes" : "no"));

  out.push(`\n## Each idea\n`);
  out.push("| Idea | Run | Potential, each scoring (one group per research) | Average | Swing | Words |");
  out.push("| --- | --- | --- | --- | --- | --- |");
  const slugs = [...new Set(runs.flatMap((r) => r.map((i) => i.slug)))];
  for (const slug of slugs) {
    runs.forEach((r, k) => {
      const idea = r.find((i) => i.slug === slug);
      if (!idea) { out.push(`| ${slug} | ${labels[k]} | missing | | | |`); return; }
      const s = ideaStats(idea);
      out.push(`| ${s.title} | ${labels[k]} | ${s.potentials.map((p) => p.join(", ")).join(" · ")} | ${s.mean} | ${s.swing} | ${s.bands.join(", ")} |`);
    });
  }

  out.push(`\n## Each criterion (1 to 5)\n`);
  out.push(`| Criterion | ${labels.map((l) => `${l}: average | ${l}: scored 1 | ${l}: swing`).join(" | ")} |`);
  out.push(`| --- | ${labels.map(() => "--- | --- | ---").join(" | ")} |`);
  const cs = runs.map(criterionStats);
  for (const key of [...new Set(cs.flatMap((c) => c.map((x) => x.key)))].sort()) {
    const cells = cs.map((c) => { const x = c.find((y) => y.key === key); return x ? `${x.mean} | ${pct(x.shareAtOne)} | ${x.averageSwing}` : "– | – | –"; });
    out.push(`| ${key} | ${cells.join(" | ")} |`);
  }
  return out.join("\n") + "\n";
}

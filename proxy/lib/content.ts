// The lens content, Sphere profiles and Explore prompts, generated from
// ForgeCore by `swift run forge-lens-export`. Never edited by hand here.
import raw from "./content.json" with { type: "json" };

export interface Rung { level: number; label: string; description: string; worth: string }
export interface Step { title: string; body: string; reachesRung: number; effort: string }
export interface Criterion {
  key: string; title: string; alias: string | null; frameworks: string[]; definition: string;
  rubric: Record<string, string>; ladder: Rung[]; doesNotCount: string[]; playbook: Step[];
  aiBoundary: string; scoreEqualsLadder: boolean;
}
export interface Lens { type: string; name: string; tagline: string; frameworks: string[]; criteria: Criterion[]; confidenceNote: string }
export interface SphereProfile { sphere: string; judges: string; frameworks: string[]; willNotDo: string; criteriaKeys: Record<string, string[]>; availableFromPhase: number }
export interface ExplorePrompt { key: string; question: string; hint: string; sphere: string | null }
export interface Content {
  version: number; lenses: Lens[]; spheres: SphereProfile[]; sphereRules: string[];
  explorePrompts: ExplorePrompt[]; recommendations: string[]; deskResearchRungCeiling: number;
}

export const content = raw as unknown as Content;

export function lens(type: string): Lens {
  const found = content.lenses.find((l) => l.type === type);
  if (!found) throw new Error(`unknown lens ${type}`);
  return found;
}

export const phase3Spheres = ["investor", "customer", "builder", "strategist", "skeptic"] as const;

/// The lens rendered as text for a system prompt. Deterministic, so it caches.
export function lensText(type: string): string {
  const l = lens(type);
  const lines: string[] = [`LENS: ${l.name}. ${l.tagline}`, `Frameworks: ${l.frameworks.join(", ")}.`, `Confidence here: ${l.confidenceNote}`, ""];
  for (const c of l.criteria) {
    lines.push(`## ${c.key} — ${c.title}${c.alias ? ` (${c.alias})` : ""} [${c.frameworks.join(", ")}]`);
    lines.push(c.definition.trim());
    lines.push("Rubric:");
    for (const k of Object.keys(c.rubric).sort()) lines.push(`  ${k}: ${c.rubric[k]}`);
    lines.push("Evidence ladder:");
    for (const r of c.ladder) lines.push(`  ${r.level}: ${r.label}. ${r.description} (${r.worth})`);
    lines.push("Does not count: " + c.doesNotCount.join(" | "));
    lines.push("Playbook: " + c.playbook.map((s) => `${s.title} [rung ${s.reachesRung}, ${s.effort}]`).join(" | "));
    lines.push("");
  }
  return lines.join("\n");
}

export function spheresText(): string {
  const lines: string[] = ["THE PANEL (Spheres). Each argues only from its frameworks and only from the Library sources provided.", ""];
  for (const s of content.spheres) {
    lines.push(`- ${s.sphere}: judges ${s.judges} Frameworks: ${s.frameworks.join(", ")}. Will not: ${s.willNotDo} Criteria: ${JSON.stringify(s.criteriaKeys)}`);
  }
  lines.push("", "Rules for every Sphere:");
  for (const r of content.sphereRules) lines.push(`- ${r}`);
  return lines.join("\n");
}

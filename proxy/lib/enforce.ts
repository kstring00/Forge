// The honesty rules, enforced on the server regardless of what the model wrote.
import { content } from "./content.js";
import type { z } from "zod";
import type { PrefillResult, RoundResult, RealityCheckResult } from "./schemas.js";

const ceiling = content.deskResearchRungCeiling;

export function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, Math.round(n)));
}

/// Keep only source IDs the app actually sent.
export function knownOnly(ids: string[], known: Set<string>): string[] {
  return [...new Set(ids.filter((id) => known.has(id)))];
}

export function enforceRound(r: z.infer<typeof RoundResult>, known: Set<string>): z.infer<typeof RoundResult> {
  const seenPairs = new Set<string>();
  return {
    verdicts: r.verdicts.map((v) => {
      const sourceIDs = knownOnly(v.sourceIDs, known);
      const verdict = sourceIDs.length === 0 ? "cantTell" : v.verdict;
      return { ...v, sourceIDs, verdict, evidenceNeeded: verdict === "cantTell" ? (v.evidenceNeeded ?? "What evidence would change this is not stated.") : v.evidenceNeeded };
    }),
    // One exchange per pair, never a reply to oneself.
    crossfire: r.crossfire.filter((c) => {
      if (c.from === c.to) return false;
      const key = [c.from, c.to].sort().join("|");
      if (seenPairs.has(key)) return false;
      seenPairs.add(key);
      return true;
    }),
  };
}

export function enforceRealityCheck(r: z.infer<typeof RealityCheckResult>, known: Set<string>): z.infer<typeof RealityCheckResult> {
  return {
    ...r,
    competitors: r.competitors.map((c) => ({ ...c, sourceID: c.sourceID && known.has(c.sourceID) ? c.sourceID : null })),
    demandSignals: r.demandSignals.map((d) => ({
      ...d,
      rung: clamp(d.rung, 0, ceiling),
      sourceID: d.sourceID && known.has(d.sourceID) ? d.sourceID : null,
    })),
  };
}

export function enforcePrefill(p: z.infer<typeof PrefillResult>, known: Set<string>, lensKeys: string[], promptKeys: string[]): z.infer<typeof PrefillResult> {
  const round = enforceRound({ verdicts: p.panel, crossfire: p.crossfire }, known);
  return {
    ...p,
    realityCheck: enforceRealityCheck(p.realityCheck, known),
    explorations: p.explorations.filter((e) => promptKeys.includes(e.promptKey)).map((e) => ({ ...e, sourceIDs: knownOnly(e.sourceIDs, known) })),
    criteria: p.criteria
      .filter((c) => lensKeys.includes(c.key))
      .map((c) => {
        const sourceIDs = knownOnly(c.sourceIDs, known);
        // Desk research proves the market exists at most; no source means an assumption.
        const evidenceLevel = sourceIDs.length === 0 ? Math.min(1, clamp(c.evidenceLevel, 0, ceiling)) : clamp(c.evidenceLevel, 0, ceiling);
        return { ...c, score: clamp(c.score, 1, 5), evidenceLevel, sourceIDs };
      }),
    riskiestAssumption: { ...p.riskiestAssumption, sourceIDs: knownOnly(p.riskiestAssumption.sourceIDs, known) },
    panel: round.verdicts,
    crossfire: round.crossfire,
  };
}

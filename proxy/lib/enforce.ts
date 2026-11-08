// The honesty rules, enforced on the server regardless of what the model wrote.
import { content } from "./content.js";
import type { z } from "zod";
import type { PitchResult, PivotDraft, PrefillResult, RoundResult, RealityCheckResult } from "./schemas.js";

const ceiling = content.deskResearchRungCeiling;

export function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, Math.round(n)));
}

/// Keep only source IDs the app actually sent.
export function knownOnly(ids: string[], known: Set<string>): string[] {
  return [...new Set(ids.filter((id) => known.has(id)))];
}

export function enforceRound(r: z.infer<typeof RoundResult>, known: Set<string>): z.infer<typeof RoundResult> {
  const verdicts = r.verdicts.map((v) => {
    const sourceIDs = knownOnly(v.sourceIDs, known);
    const verdict = sourceIDs.length === 0 ? "cantTell" : v.verdict;
    return { ...v, sourceIDs, verdict, evidenceNeeded: verdict === "cantTell" ? (v.evidenceNeeded ?? "What evidence would change this is not stated.") : v.evidenceNeeded };
  });
  // Crossfire only where two Spheres' verdicts conflict (on track against off
  // track, after the no-source rule above). "Can't tell" argues with nobody.
  const kind = new Map<string, string>();
  for (const v of verdicts) if (!kind.has(v.sphere)) kind.set(v.sphere, v.verdict);
  const conflicts = (a: string, b: string) => {
    const x = kind.get(a), y = kind.get(b);
    return (x === "onTrack" && y === "offTrack") || (x === "offTrack" && y === "onTrack");
  };
  const seenPairs = new Set<string>();
  return {
    verdicts,
    // One exchange per pair, never a reply to oneself.
    crossfire: r.crossfire.filter((c) => {
      if (c.from === c.to || !conflicts(c.from, c.to)) return false;
      const key = [c.from, c.to].sort().join("|");
      if (seenPairs.has(key)) return false;
      seenPairs.add(key);
      return true;
    }),
  };
}

/// Items without a saved source are not findings. They are dropped and counted
/// (the app shows the count, never the item), so one unsourced competitor can
/// never sink a run or pass as fact.
export function enforceRealityCheck(r: z.infer<typeof RealityCheckResult>, known: Set<string>, dropped: Record<string, number> = {}): z.infer<typeof RealityCheckResult> {
  const competitors = r.competitors.filter((c) => c.sourceID && known.has(c.sourceID));
  const demandSignals = r.demandSignals.filter((d) => d.sourceID && known.has(d.sourceID));
  if (competitors.length < r.competitors.length) dropped["realityCheck.competitors"] = (dropped["realityCheck.competitors"] ?? 0) + r.competitors.length - competitors.length;
  if (demandSignals.length < r.demandSignals.length) dropped["realityCheck.demandSignals"] = (dropped["realityCheck.demandSignals"] ?? 0) + r.demandSignals.length - demandSignals.length;
  return {
    ...r,
    competitors,
    demandSignals: demandSignals.map((d) => ({ ...d, rung: clamp(d.rung, 0, ceiling) })),
  };
}

export function enforcePrefill(p: z.infer<typeof PrefillResult>, known: Set<string>, lensKeys: string[], promptKeys: string[], dropped: Record<string, number> = {}): z.infer<typeof PrefillResult> {
  const round = enforceRound({ verdicts: p.panel, crossfire: p.crossfire }, known);
  return {
    ...p,
    realityCheck: enforceRealityCheck(p.realityCheck, known, dropped),
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
    // A range is low to high, never negative, and never one-sided.
    projectionLow: p.projectionLow != null && p.projectionHigh != null ? Math.max(0, Math.min(p.projectionLow, p.projectionHigh)) : null,
    projectionHigh: p.projectionLow != null && p.projectionHigh != null ? Math.max(0, Math.max(p.projectionLow, p.projectionHigh)) : null,
    panel: round.verdicts,
    crossfire: round.crossfire,
    pivots: enforcePivots(p.pivots ?? [], known, lensKeys),
  };
}

/// Decision 0024: at most three pivots, each raising a real criterion of the
/// lens, phrased as a "What if…", citing only known sources.
export function enforcePivots(pivots: z.infer<typeof PivotDraft>[], known: Set<string>, lensKeys: string[]): z.infer<typeof PivotDraft>[] {
  return pivots
    .filter((x) => lensKeys.includes(x.fixes) && x.whatIf.trim().length > 0)
    .slice(0, 3)
    .map((x) => {
      const t = x.whatIf.trim();
      const whatIf = /^what if/i.test(t) ? t : `What if ${t.charAt(0).toLowerCase()}${t.slice(1)}`;
      return { ...x, whatIf: whatIf.endsWith("?") || whatIf.endsWith(".") ? whatIf : whatIf + "?", sourceIDs: knownOnly(x.sourceIDs, known) };
    });
}

/// A pitch may only claim evidence it can point at.
export function enforcePitch(p: z.infer<typeof PitchResult>, known: Set<string>): z.infer<typeof PitchResult> {
  return { pitches: p.pitches.map((x) => ({ ...x, groundedIn: knownOnly(x.groundedIn, known) })) };
}

// Salvage, don't reject. When the model's answer fails the contract on one
// item in a list (a competitor with no source id, a demand signal with a bad
// rung), that item is dropped and counted; the run goes on. The run fails only
// when a required top-level field is missing or wrong.
import type { z } from "zod";

export interface Salvaged<T> {
  data: T | null;
  /// Items removed, keyed by their list ("realityCheck.competitors": 1).
  dropped: Record<string, number>;
  /// What was still wrong when salvage gave up, for the retry prompt and the log.
  issues: string[];
}

/// Missing nullable fields arrive as absent keys; the contract wants null.
/// Only `sourceID`-shaped and `url`-shaped omissions are filled; nothing else is invented.
export function fillOmittedNulls(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(fillOmittedNulls);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) out[k] = fillOmittedNulls(v);
    for (const k of ["sourceID", "url", "evidenceNeeded", "experiment", "sphere"]) {
      if (k in out === false && looksLikeItemWith(k, out)) out[k] = null;
    }
    return out;
  }
  return value;
}

/// Heuristics for which objects may omit which nullable field.
function looksLikeItemWith(field: string, obj: Record<string, unknown>): boolean {
  switch (field) {
    case "sourceID": return "name" in obj || ("text" in obj && "rung" in obj);
    case "url": return "name" in obj || ("text" in obj && "rung" in obj);
    case "evidenceNeeded": return "verdict" in obj && "criterionKey" in obj;
    case "experiment": return "verdict" in obj && "competitors" in obj;
    case "sphere": return "cluster" in obj;
    default: return false;
  }
}

/// Parses; on failure removes the offending list items (deepest list on each
/// issue's path) and parses again, up to a few rounds.
export function salvage<T extends z.ZodType>(candidate: unknown, schema: T): Salvaged<z.infer<T>> {
  let current = fillOmittedNulls(candidate);
  const dropped: Record<string, number> = {};
  let issues: string[] = [];
  for (let round = 0; round < 6; round++) {
    const result = schema.safeParse(current);
    if (result.success) return { data: result.data, dropped, issues: [] };
    issues = result.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`);
    const removals = new Map<string, Set<number>>();
    for (const issue of result.error.issues) {
      const path = issue.path as (string | number)[];
      // The deepest array index on the path names the item to drop.
      let idx = -1;
      for (let i = path.length - 1; i >= 0; i--) if (typeof path[i] === "number") { idx = i; break; }
      if (idx < 0) continue;
      const listPath = path.slice(0, idx).map(String).join(".");
      if (!removals.has(listPath)) removals.set(listPath, new Set());
      removals.get(listPath)!.add(path[idx] as number);
    }
    if (removals.size === 0) break;   // a top-level field is wrong; nothing to drop
    for (const [listPath, indices] of removals) {
      const list = getAt(current, listPath);
      if (!Array.isArray(list)) continue;
      for (const i of [...indices].sort((a, b) => b - a)) list.splice(i, 1);
      dropped[listPath] = (dropped[listPath] ?? 0) + indices.size;
    }
  }
  return { data: null, dropped, issues };
}

function getAt(root: unknown, dotted: string): unknown {
  if (!dotted) return root;
  let node: unknown = root;
  for (const part of dotted.split(".")) {
    if (node && typeof node === "object") node = (node as Record<string, unknown>)[part];
    else return undefined;
  }
  return node;
}

export function totalDropped(d: Record<string, number>): number {
  return Object.values(d).reduce((a, b) => a + b, 0);
}

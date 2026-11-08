import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { BenchIdea } from "./types.js";

export const root = join(dirname(fileURLToPath(import.meta.url)), "..");
export const ideasDir = join(root, "ideas");
export const resultsDir = join(root, "results");
export const ideaproofDir = join(root, "baselines", "ideaproof");

export function loadIdeas(): BenchIdea[] {
  return readdirSync(ideasDir)
    .filter((f) => f.endsWith(".json") && !f.startsWith("_"))
    .sort()
    .map((f) => {
      const parsed = BenchIdea.safeParse(JSON.parse(readFileSync(join(ideasDir, f), "utf8")));
      if (!parsed.success) throw new Error(`ideas/${f}: ${parsed.error.issues.map((i) => `${i.path.join(".")} ${i.message}`).join("; ")}`);
      if (`${parsed.data.id}.json` !== f) throw new Error(`ideas/${f}: id "${parsed.data.id}" must match the file name`);
      return parsed.data;
    });
}

export function readJSON<T>(path: string): T | null {
  return existsSync(path) ? (JSON.parse(readFileSync(path, "utf8")) as T) : null;
}

export function writeJSON(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 2) + "\n");
}

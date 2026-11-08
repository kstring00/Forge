// npm run import-vault -- <path to vault.json> [words to match in the title]
// Turns ideas from the app's export (Settings → Export Vault) into unkeyed
// bench ideas, in your own words. Write each key by hand afterwards.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { ideasDir, writeJSON } from "./io.js";

const [path, ...filter] = process.argv.slice(2);
if (!path) {
  console.error("Usage: npm run import-vault -- <vault.json> [words to match in the title]");
  process.exit(1);
}
const vault = JSON.parse(readFileSync(path, "utf8")) as { ideas: { title: string; originalText: string; archivedAt?: string | null }[] };
const words = filter.map((w) => w.toLowerCase());
let added = 0;
for (const i of vault.ideas) {
  if (i.archivedAt) continue;
  if (words.length && !words.every((w) => i.title.toLowerCase().includes(w))) continue;
  const id = "person-" + i.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40);
  const file = join(ideasDir, `${id}.json`);
  if (existsSync(file)) {
    console.log(`skip ${id} (exists)`);
    continue;
  }
  writeJSON(file, { id, kind: "person", title: i.title, text: i.originalText, lens: "business", outcome: "", key: null });
  console.log(`added ideas/${id}.json`);
  added++;
}
console.log(`${added} added. Each needs a key: the true top 3 competitors with real prices, and the real riskiest assumption.`);

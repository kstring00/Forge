// The research packet: what one check's research found, as findings that each
// carry the URL they came from. Built here from the research notes (which the
// research prompt asks for in fixed sections, one finding per line, each ending
// with its URL), so it costs no extra model call. Every panelist and the Brief
// read this packet; nobody searches again.
import type { ResearchSource } from "../api/research.js";

export const packetSections = ["competitors", "prices", "complaints", "demand", "other"] as const;
export type PacketSection = (typeof packetSections)[number];

export interface PacketFinding {
  section: PacketSection;
  text: string;
  /// The page it came from. Always present: a line without one is not a finding.
  url: string;
  /// Further pages the same line cites.
  alsoURLs: string[];
  title: string;
}

export interface ResearchPacket {
  version: 1;
  findings: PacketFinding[];
  /// Lines the research wrote with no URL. Kept for the record, never shown as facts.
  unsourced: string[];
  /// What the research says it could not find.
  gaps: string[];
}

const urlPattern = /https?:\/\/[^\s)\]>"']+/g;

/// "COMPETITORS", "## Prices", "**Complaints:**" → the section, else null.
function heading(line: string): PacketSection | null {
  const bare = line.replace(/[#*_:]/g, " ").trim().toLowerCase();
  if (/^-/.test(line.trim())) return null;
  for (const s of packetSections) {
    if (bare === s || bare.startsWith(s + " ")) return s;
  }
  if (/^(pricing|price)\b/.test(bare)) return "prices";
  if (/^(alternatives|who already does this)\b/.test(bare)) return "competitors";
  if (/^(demand signals?)\b/.test(bare)) return "demand";
  return null;
}

/// The claim without its URLs, bullet, empty brackets or trailing punctuation.
export function cleanClaim(line: string): string {
  return line
    .replace(urlPattern, "")
    .replace(/^(?:[-*•]|\d+[.)])\s+/, "")
    .replace(/\(\s*\)|\[\s*\]/g, "")
    .replace(/\s+([.,;:])/g, "$1")
    .replace(/\s{2,}/g, " ")
    .replace(/[\s([\-–—:,;]+$/, "")
    .trim();
}

export function urlsIn(line: string): string[] {
  return [...new Set([...line.matchAll(urlPattern)].map((m) => m[0].replace(/[.,;:!?]+$/, "")))];
}

function host(url: string): string | null {
  try { return new URL(url).hostname.replace(/^www\./, ""); } catch { return null; }
}

export function buildPacket(notes: string, found: ResearchSource[]): ResearchPacket {
  const titles = new Map(found.map((f) => [f.url, f.title]));
  const packet: ResearchPacket = { version: 1, findings: [], unsourced: [], gaps: [] };
  let section: PacketSection = "other";
  for (const raw of notes.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    const h = heading(line);
    if (h) { section = h; continue; }
    const claim = cleanClaim(line);
    if (claim.length < 12) continue;
    if (/could not find|couldn't find|no (public )?(data|information) found/i.test(claim)) {
      packet.gaps.push(claim);
      continue;
    }
    const urls = urlsIn(line).filter((u) => host(u));
    if (!urls.length) {
      // Prose around the list ("RESEARCH NOTES", a closing sentence) is not a finding either.
      if (/^(?:[-*•]|\d+[.)])\s+/.test(line)) packet.unsourced.push(claim);
      continue;
    }
    const [url, ...alsoURLs] = urls;
    packet.findings.push({ section, text: claim, url, alsoURLs, title: titles.get(url) || host(url) || url });
  }
  return packet;
}

/// The research prompt's closing instruction: the shape `buildPacket` reads.
export const notesFormat = `When you are done, write RESEARCH NOTES in exactly these sections, each heading on a line of its own: COMPETITORS, PRICES, COMPLAINTS, DEMAND, OTHER.
Under each heading, one finding per line, starting with "- " and ending with the full URL of the page it came from (and the date, if the page shows one). One claim per line; no line without a URL.
If you could not find something a section needs, write "- Could not find …" under it, saying what. No verdict, no recommendation, no praise.`;

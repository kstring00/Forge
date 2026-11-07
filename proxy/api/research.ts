import type { VercelRequest, VercelResponse } from "@vercel/node";
import type Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import { anthropic } from "../lib/anthropic.js";
import { config } from "../lib/env.js";
import { HttpError, rateLimit, readJSON, requireAuth, requireMethod, sendError } from "../lib/http.js";
import { costUSD, round4 } from "../lib/pricing.js";
import { researchSystem } from "../lib/prompts.js";

/// Desk research for a Reality Check, one model turn per HTTP call so each
/// call stays inside the function time limit. The app loops while `status`
/// is "paused", passing `messages` back unchanged. Pages the model fetched
/// come back as sources for the Library, class ai-found.
const ResearchRequest = z.object({
  idea: z.object({ id: z.string().uuid(), title: z.string(), originalText: z.string() }),
  advantages: z.array(z.string()).default([]),
  constraints: z.array(z.string()).default([]),
  messages: z.array(z.any()).optional(),
});

export interface ResearchSource {
  url: string;
  title: string;
  text: string;
  kind: "fetched" | "searchHit";
  retrievedAt: string | null;
}

export interface ResearchResponse {
  status: "done" | "paused";
  messages: Anthropic.MessageParam[];
  sources: ResearchSource[];
  notes: string;
  model: string;
  usage: { inputTokens: number; outputTokens: number; cacheReadTokens: number; cacheWriteTokens: number; webSearches: number };
  costUSD: number;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    requireMethod(req, "POST");
    requireAuth(req);
    rateLimit();

    const parsed = ResearchRequest.safeParse(readJSON(req));
    if (!parsed.success) throw new HttpError(400, "bad_request", "Request did not match the contract.");
    const { idea, advantages, constraints } = parsed.data;

    const messages: Anthropic.MessageParam[] = parsed.data.messages?.length
      ? (parsed.data.messages as Anthropic.MessageParam[])
      : [{ role: "user", content: openingTurn(idea, advantages, constraints) }];

    const response = await anthropic().messages.create({
      model: config.researchModel,
      max_tokens: 12000,
      system: [{ type: "text", text: researchSystem, cache_control: { type: "ephemeral" } }],
      tools: [
        { type: "web_search_20260209", name: "web_search", max_uses: config.maxSearchesPerResearchCall },
        { type: "web_fetch_20260209", name: "web_fetch", max_uses: config.maxFetchesPerResearchCall, max_content_tokens: 8000 },
      ],
      output_config: { effort: "medium" },
      messages,
    });

    if (response.stop_reason === "refusal") throw new HttpError(502, "refused", "The model declined this request.");

    const sources = extractSources(response.content);
    const notes = response.content.filter((b): b is Anthropic.TextBlock => b.type === "text").map((b) => b.text).join("\n\n").trim();
    const u = response.usage;
    const out: ResearchResponse = {
      status: response.stop_reason === "pause_turn" ? "paused" : "done",
      messages: [...messages, { role: "assistant", content: response.content }],
      sources,
      notes,
      model: response.model,
      usage: {
        inputTokens: u.input_tokens,
        outputTokens: u.output_tokens,
        cacheReadTokens: u.cache_read_input_tokens ?? 0,
        cacheWriteTokens: u.cache_creation_input_tokens ?? 0,
        webSearches: u.server_tool_use?.web_search_requests ?? 0,
      },
      costUSD: round4(costUSD(config.researchModel, u)),
    };
    res.status(200).json(out);
  } catch (err) {
    sendError(res, err);
  }
}

function openingTurn(idea: { id: string; title: string; originalText: string }, advantages: string[], constraints: string[]): string {
  const parts = [
    `IDEA ${idea.id}\nTitle: ${idea.title}\nThe user's own words:\n"""${idea.originalText}"""`,
    advantages.length ? "The user's stated advantages:\n" + advantages.map((a) => `- ${a}`).join("\n") : "",
    constraints.length ? "Standing constraints:\n" + constraints.map((c) => `- ${c}`).join("\n") : "",
    "Research this idea's market from the desk and write the RESEARCH NOTES.",
  ].filter(Boolean);
  return parts.join("\n\n");
}

/// Fetched pages become full-text sources; search hits become title-only
/// sources (their content is encrypted for replay, not readable here).
export function extractSources(blocks: Anthropic.ContentBlock[]): ResearchSource[] {
  const out: ResearchSource[] = [];
  const seen = new Set<string>();
  for (const block of blocks) {
    if (block.type === "web_fetch_tool_result") {
      const c = block.content;
      if (c && typeof c === "object" && "type" in c && c.type === "web_fetch_result") {
        const doc = c.content;
        const src = doc?.source;
        // Fetched pages arrive as plain text; PDFs arrive base64 and are skipped here.
        const text = src && src.type === "text" && typeof src.data === "string" ? src.data : "";
        if (!seen.has(c.url)) {
          seen.add(c.url);
          out.push({ url: c.url, title: doc?.title ?? c.url, text: text.slice(0, 60_000), kind: "fetched", retrievedAt: c.retrieved_at ?? null });
        }
      }
    } else if (block.type === "web_search_tool_result") {
      const c = block.content;
      if (Array.isArray(c)) {
        for (const hit of c) {
          if (hit.type === "web_search_result" && !seen.has(hit.url)) {
            seen.add(hit.url);
            out.push({ url: hit.url, title: hit.title, text: "", kind: "searchHit", retrievedAt: hit.page_age ?? null });
          }
        }
      }
    }
  }
  return out;
}

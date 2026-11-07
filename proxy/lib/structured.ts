import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import type { z } from "zod";
import { anthropic } from "./anthropic.js";
import { HttpError } from "./http.js";
import { logUpstream, upstreamMessage } from "./upstream.js";

export interface StructuredCall<T extends z.ZodType> {
  label: string;
  model: string;
  maxTokens: number;
  effort: "low" | "medium" | "high";
  system: Anthropic.TextBlockParam[];
  user: string;
  schema: T;
  timeoutMs: number;
}

export interface StructuredResult<T> {
  parsed: T;
  response: Anthropic.Message;
  mode: "structured" | "jsonFallback";
}

/// Structured outputs first. If the API rejects the request with a 400 (for
/// example "Schema is too complex for compilation"), log Anthropic's message
/// and retry once with the schema in the prompt, validating with zod here.
/// Either way the app only ever receives a schema-valid payload.
export async function callStructured<T extends z.ZodType>(c: StructuredCall<T>): Promise<StructuredResult<z.infer<T>>> {
  const format = zodOutputFormat(c.schema);
  try {
    const response = await anthropic().messages.parse(
      {
        model: c.model,
        max_tokens: c.maxTokens,
        system: c.system,
        messages: [{ role: "user", content: c.user }],
        output_config: { format, effort: c.effort },
      },
      { timeout: c.timeoutMs, maxRetries: 1 },
    );
    guardStop(response, c.label);
    if (response.parsed_output == null) {
      throw new HttpError(502, "invalid_response", "The model's answer did not match the contract.");
    }
    return { parsed: response.parsed_output as z.infer<T>, response, mode: "structured" };
  } catch (err) {
    if (!(err instanceof Anthropic.BadRequestError)) {
      if (err instanceof Anthropic.APIError) logUpstream(`${c.label}.structured`, err);
      throw err;
    }
    logUpstream(`${c.label}.structured`, err);
    console.error(JSON.stringify({ at: c.label, note: "retrying without output_config.format", schemaBytes: JSON.stringify(format.schema).length }));
    return await jsonFallback(c, format.schema, upstreamMessage(err));
  }
}

async function jsonFallback<T extends z.ZodType>(c: StructuredCall<T>, jsonSchema: unknown, firstError: string | null): Promise<StructuredResult<z.infer<T>>> {
  let response: Anthropic.Message;
  try {
    response = await anthropic().messages.create(
      {
        model: c.model,
        max_tokens: c.maxTokens,
        system: [
          ...c.system,
          {
            type: "text",
            text: "Respond with exactly one JSON object and nothing else: no prose before or after, no code fences. It must validate against this JSON Schema:\n" + JSON.stringify(jsonSchema),
          },
        ],
        messages: [{ role: "user", content: c.user }],
        output_config: { effort: c.effort },
      },
      { timeout: c.timeoutMs, maxRetries: 1 },
    );
  } catch (err) {
    logUpstream(`${c.label}.jsonFallback`, err);
    const second = upstreamMessage(err);
    throw new HttpError(502, "upstream_rejected", `Claude API rejected the request. First: ${firstError ?? "unknown"}. Retry: ${second ?? "unknown"}.`);
  }
  guardStop(response, c.label);
  const text = response.content.filter((b): b is Anthropic.TextBlock => b.type === "text").map((b) => b.text).join("");
  const candidate = extractJSON(text);
  if (candidate === undefined) {
    console.error(JSON.stringify({ at: `${c.label}.jsonFallback`, error: "no JSON object in reply", head: text.slice(0, 300) }));
    throw new HttpError(502, "invalid_response", "The model's answer was not JSON.");
  }
  const result = c.schema.safeParse(candidate);
  if (!result.success) {
    const issues = result.error.issues.slice(0, 5).map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
    console.error(JSON.stringify({ at: `${c.label}.jsonFallback`, error: "schema mismatch", issues }));
    throw new HttpError(502, "invalid_response", `The model's answer did not match the contract: ${issues}`);
  }
  return { parsed: result.data, response, mode: "jsonFallback" };
}

function guardStop(response: Anthropic.Message, label: string): void {
  if (response.stop_reason === "refusal") {
    console.error(JSON.stringify({ at: label, stop: "refusal", details: (response as { stop_details?: unknown }).stop_details ?? null }));
    throw new HttpError(502, "refused", "The model declined this request.");
  }
  if (response.stop_reason === "max_tokens") {
    console.error(JSON.stringify({ at: label, stop: "max_tokens", outputTokens: response.usage.output_tokens }));
    throw new HttpError(502, "truncated", "The model ran out of room before finishing. Try again; if it repeats, the proxy's max_tokens needs raising.");
  }
}

/// The first balanced top-level JSON object in a reply, tolerating code fences
/// or a stray sentence around it. Undefined if there is none.
export function extractJSON(text: string): unknown {
  const start = text.indexOf("{");
  if (start < 0) return undefined;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) {
        try { return JSON.parse(text.slice(start, i + 1)); } catch { return undefined; }
      }
    }
  }
  return undefined;
}

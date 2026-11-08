import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import type { z } from "zod";
import { anthropic } from "./anthropic.js";
import { HttpError } from "./http.js";
import { logUpstream, upstreamMessage } from "./upstream.js";
import { salvage, totalDropped } from "./salvage.js";

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
  mode: "structured" | "jsonFallback" | "jsonRetry";
  /// List items the contract rejected and salvage removed, by list.
  dropped: Record<string, number>;
}

/// Structured outputs first. If the API rejects the request with a 400 (for
/// example "Schema is too complex for compilation"), log Anthropic's message
/// and retry with the schema in the prompt, validating here. A list item that
/// fails the contract is dropped and counted, never fatal; if the object is
/// still wrong, the model is asked once more with the errors; only then does
/// the run fail. Either way the app only ever receives a schema-valid payload.
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
    if (response.parsed_output != null) {
      return { parsed: response.parsed_output as z.infer<T>, response, mode: "structured", dropped: {} };
    }
    // The SDK could not parse what came back; salvage the text ourselves.
    const text = textOf(response);
    const candidate = extractJSON(text);
    const s = candidate === undefined ? null : salvage(candidate, c.schema);
    if (s?.data) {
      logDropped(c.label, s.dropped);
      return { parsed: s.data, response, mode: "structured", dropped: s.dropped };
    }
    return await retryWithIssues(c, format.schema, s?.issues ?? ["The answer was not a JSON object."]);
  } catch (err) {
    if (err instanceof HttpError) throw err;
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
  const response = await plainJSONCall(c, jsonSchema, null, firstError);
  const text = textOf(response);
  const candidate = extractJSON(text);
  if (candidate === undefined) {
    console.error(JSON.stringify({ at: `${c.label}.jsonFallback`, error: "no JSON object in reply", head: text.slice(0, 300) }));
    return await retryWithIssues(c, jsonSchema, ["The answer was not a JSON object."]);
  }
  const s = salvage(candidate, c.schema);
  if (s.data) {
    logDropped(c.label, s.dropped);
    return { parsed: s.data, response, mode: "jsonFallback", dropped: s.dropped };
  }
  console.error(JSON.stringify({ at: `${c.label}.jsonFallback`, error: "schema mismatch", issues: s.issues.slice(0, 8) }));
  return await retryWithIssues(c, jsonSchema, s.issues);
}

/// One more try, with what was wrong spelled out. Then the run fails, with
/// the technical detail in the log and the error body.
async function retryWithIssues<T extends z.ZodType>(c: StructuredCall<T>, jsonSchema: unknown, issues: string[]): Promise<StructuredResult<z.infer<T>>> {
  const response = await plainJSONCall(c, jsonSchema, issues, null);
  const text = textOf(response);
  const candidate = extractJSON(text);
  const s = candidate === undefined ? null : salvage(candidate, c.schema);
  if (s?.data) {
    logDropped(c.label, s.dropped);
    return { parsed: s.data, response, mode: "jsonRetry", dropped: s.dropped };
  }
  const detail = (s?.issues ?? ["The answer was not a JSON object."]).slice(0, 5).join("; ");
  console.error(JSON.stringify({ at: `${c.label}.jsonRetry`, error: "schema mismatch after retry", issues: detail }));
  throw new HttpError(502, "invalid_response", `The model's answer did not match the contract after a retry: ${detail}`);
}

async function plainJSONCall<T extends z.ZodType>(c: StructuredCall<T>, jsonSchema: unknown, issues: string[] | null, firstError: string | null): Promise<Anthropic.Message> {
  const system: Anthropic.TextBlockParam[] = [
    ...c.system,
    {
      type: "text",
      text: "Respond with exactly one JSON object and nothing else: no prose before or after, no code fences. Every property in the schema must be present; use null where the schema allows it and you have nothing. It must validate against this JSON Schema:\n" + JSON.stringify(jsonSchema),
    },
  ];
  if (issues?.length) {
    system.push({
      type: "text",
      text: "Your previous answer failed validation. Fix these and return the whole object again:\n- " + issues.slice(0, 12).join("\n- "),
    });
  }
  try {
    return await anthropic().messages.create(
      {
        model: c.model,
        max_tokens: c.maxTokens,
        system,
        messages: [{ role: "user", content: c.user }],
        output_config: { effort: c.effort },
      },
      { timeout: c.timeoutMs, maxRetries: 1 },
    );
  } catch (err) {
    logUpstream(`${c.label}.${issues ? "jsonRetry" : "jsonFallback"}`, err);
    const second = upstreamMessage(err);
    throw new HttpError(502, "upstream_rejected", `Claude API rejected the request. First: ${firstError ?? "unknown"}. Retry: ${second ?? "unknown"}.`);
  }
}

function logDropped(label: string, dropped: Record<string, number>): void {
  if (totalDropped(dropped) > 0) console.warn(JSON.stringify({ at: label, note: "salvaged: dropped items that failed the contract", dropped }));
}

function textOf(response: Anthropic.Message): string {
  return response.content.filter((b): b is Anthropic.TextBlock => b.type === "text").map((b) => b.text).join("");
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

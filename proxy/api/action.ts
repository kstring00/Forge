import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config } from "../lib/env.js";
import { HttpError, rateLimit, readJSON, requireAuth, requireMethod, sendError } from "../lib/http.js";
import { costUSD, round4 } from "../lib/pricing.js";
import { ActionRequest, payloadSchemas, withRationale, type Action, type Envelope } from "../lib/schemas.js";
import { actionInstruction, stableSystem, userTurn } from "../lib/prompts.js";
import { enforcePitch, enforcePrefill, enforceRealityCheck, enforceRound } from "../lib/enforce.js";
import { content, lens } from "../lib/content.js";
import { callStructured } from "../lib/structured.js";

/// Which actions run on the fast model. Everything with a Sphere or a verdict runs on the Sphere model (Sonnet).
const fastActions: Action[] = ["expand", "summarize", "explainCriterion", "nextStep"];

/// Output budget per action. Prefill writes the whole Lab in one object.
const maxTokensFor = (a: Action) => (a === "prefill" ? 24000 : a === "runRound" || a === "realityCheck" ? 12000 : 8000);

/// POST /api/action — one typed action, one typed envelope back.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    requireMethod(req, "POST");
    requireAuth(req);
    rateLimit();

    const parsed = ActionRequest.safeParse(readJSON(req));
    if (!parsed.success) {
      throw new HttpError(400, "bad_request", "Request did not match the contract: " + parsed.error.issues.map((i) => i.path.join(".") + " " + i.message).join("; "));
    }
    const { action, context, options } = parsed.data;
    const lensType = context.lens ?? "business";
    const model = fastActions.includes(action) ? config.fastModel : config.sphereModel;

    const result = await callStructured({
      label: `action.${action}`,
      model,
      maxTokens: maxTokensFor(action),
      effort: "medium",
      system: [
        { type: "text", text: stableSystem(lensType), cache_control: { type: "ephemeral" } },
        { type: "text", text: actionInstruction(action) },
      ],
      user: userTurn(context, options),
      schema: withRationale(payloadSchemas[action]),
      // Under the function's maxDuration in vercel.json.
      timeoutMs: 270_000,
    });

    const known = new Set(context.sources.map((s) => s.id));
    const dropped: Record<string, number> = { ...result.dropped };
    let payload: unknown = result.parsed.payload;
    if (action === "runRound") payload = enforceRound(payload as never, known);
    if (action === "realityCheck") payload = enforceRealityCheck(payload as never, known, dropped);
    if (action === "pitch") payload = enforcePitch(payload as never, known);
    if (action === "prefill") {
      payload = enforcePrefill(payload as never, known, lens(lensType).criteria.map((c) => c.key), content.explorePrompts.map((p) => p.key), dropped);
    }

    const u = result.response.usage;
    const envelope: Envelope<unknown> = {
      payload,
      rationale: result.parsed.rationale,
      model: result.response.model,
      usage: {
        inputTokens: u.input_tokens,
        outputTokens: u.output_tokens,
        cacheReadTokens: u.cache_read_input_tokens ?? 0,
        cacheWriteTokens: u.cache_creation_input_tokens ?? 0,
        webSearches: 0,
      },
      costUSD: round4(costUSD(model, u)),
      dropped: Object.keys(dropped).length ? dropped : undefined,
    };
    if (result.mode !== "structured") res.setHeader("X-Forge-Mode", result.mode === "jsonRetry" ? "json-retry" : "json-fallback");
    if (Object.keys(dropped).length) console.warn(JSON.stringify({ at: `action.${action}`, dropped }));
    res.status(200).json(envelope);
  } catch (err) {
    sendError(res, err, "action");
  }
}

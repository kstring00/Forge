import type { VercelRequest, VercelResponse } from "@vercel/node";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { anthropic } from "../lib/anthropic.js";
import { config } from "../lib/env.js";
import { HttpError, rateLimit, readJSON, requireAuth, requireMethod, sendError } from "../lib/http.js";
import { costUSD, round4 } from "../lib/pricing.js";
import { ActionRequest, payloadSchemas, withRationale, type Action, type Envelope } from "../lib/schemas.js";
import { actionInstruction, stableSystem, userTurn } from "../lib/prompts.js";
import { enforcePrefill, enforceRealityCheck, enforceRound } from "../lib/enforce.js";
import { content, lens } from "../lib/content.js";

/// Which actions run on the fast model. Everything with a Sphere or a verdict runs on the research model.
const fastActions: Action[] = ["expand", "summarize", "explainCriterion", "nextStep"];

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
    const model = fastActions.includes(action) ? config.fastModel : config.researchModel;
    const schema = withRationale(payloadSchemas[action]);

    const response = await anthropic().messages.parse({
      model,
      max_tokens: action === "prefill" ? 16000 : 8000,
      system: [
        { type: "text", text: stableSystem(lensType), cache_control: { type: "ephemeral" } },
        { type: "text", text: actionInstruction(action) },
      ],
      messages: [{ role: "user", content: userTurn(context, options) }],
      output_config: { format: zodOutputFormat(schema), effort: action === "prefill" || action === "runRound" ? "high" : "medium" },
    });

    if (response.stop_reason === "refusal") {
      throw new HttpError(502, "refused", "The model declined this request.");
    }
    if (!response.parsed_output) {
      throw new HttpError(502, "invalid_response", "The model's answer did not match the contract.");
    }

    const known = new Set(context.sources.map((s) => s.id));
    let payload: unknown = response.parsed_output.payload;
    if (action === "runRound") payload = enforceRound(payload as never, known);
    if (action === "realityCheck") payload = enforceRealityCheck(payload as never, known);
    if (action === "prefill") {
      payload = enforcePrefill(payload as never, known, lens(lensType).criteria.map((c) => c.key), content.explorePrompts.map((p) => p.key));
    }

    const u = response.usage;
    const envelope: Envelope<unknown> = {
      payload,
      rationale: response.parsed_output.rationale,
      model: response.model,
      usage: {
        inputTokens: u.input_tokens,
        outputTokens: u.output_tokens,
        cacheReadTokens: u.cache_read_input_tokens ?? 0,
        cacheWriteTokens: u.cache_creation_input_tokens ?? 0,
        webSearches: 0,
      },
      costUSD: round4(costUSD(model, u)),
    };
    res.status(200).json(envelope);
  } catch (err) {
    sendError(res, err);
  }
}

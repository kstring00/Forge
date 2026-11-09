// Hunch's server-side settings: the one file to edit. Change a value, push to
// main (Vercel redeploys the proxy) and every app picks it up on its next
// request, with no app update. FORGE_MODEL_<ROLE> environment variables on
// Vercel override a model for a quick test.
export default {
  /// The model for each role in a check and after it.
  models: {
    /// Desk research: web search and fetch, then the notes the packet is built from.
    research: "claude-haiku-5-5",
    /// The five panelists' scores and verdicts, from the packet.
    scoring: "claude-haiku-5-5",
    /// The Brief, the next step and the What-ifs: where quality shows.
    brief: "claude-opus-5-5",
    /// Launch plans (new and brought up to date).
    plan: "claude-sonnet-5-5",
    /// The Tank, when it is built (ENGINE.md §3.4).
    tank: "claude-sonnet-5-5",
    /// Expand, summarize, explain a criterion, next step.
    fast: "claude-haiku-5-5",
  },
  /// How hard each role thinks (output_config.effort).
  effort: {
    research: "medium",
    scoring: "medium",
    brief: "medium",
    plan: "medium",
    tank: "medium",
    fast: "low",
  },
} as const;

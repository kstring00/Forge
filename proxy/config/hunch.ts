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
  /// Every number behind checks (decision 0042). The app loads these on
  /// launch from /api/health and keeps the last ones it saw; its built-in
  /// defaults (ForgeCore PlanRules) are these same numbers. App Store prices
  /// and product names are set in App Store Connect, not here.
  rules: {
    /// Checks a month on each plan.
    monthlyChecks: { free: 1, plus: 15, pro: 60 },
    /// Plus's 7-day trial is capped at this many checks.
    trialChecks: 5,
    /// Checks in one $2.99 top-up.
    topUpChecks: 5,
    /// Unused monthly checks carry into the next cycle, up to capMonths of allowance.
    rollover: { enabled: true, capMonths: 1 },
    /// What each thing costs, in checks. Only research costs.
    costs: { check: 1, freshRecheck: 1, launchPlan: 0, launchPlanUpdate: 0, rescore: 0, tank: 0 },
    /// Quiet daily limits on included follow-ups, per idea. Reaching one shows a friendly line, never the paywall.
    fairUse: { launchPlansPerIdeaPerDay: 3, rescoresPerIdeaPerDay: 10, tankRunsPerIdeaPerDay: 3 },
  },
} as const;

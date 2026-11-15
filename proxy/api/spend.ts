import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config } from "../lib/env.js";
import { requireMethod, sendError } from "../lib/http.js";
import { requireOwner } from "../lib/owner.js";
import { spendSummary } from "../lib/ledger.js";
import { panelState } from "../lib/limits.js";
import { dayKey, dayTimeZone, store } from "../lib/store.js";

/// GET /api/spend — the owner's view of what the proxy has spent: today, this
/// week (from Monday) and this month, from actual token usage, and where today
/// stands against the ceiling. Needs FORGE_OWNER_SECRET as a bearer token.
/// The app's Settings → Spend reads this.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    requireMethod(req, "GET");
    requireOwner(req);
    const day = dayKey();
    const summary = await spendSummary(day);
    const ceiling = config.dailySpendUSD;
    res.status(200).json({
      day,
      timeZone: dayTimeZone(),
      ceilingUSD: ceiling,
      freeTierStopsAtUSD: Math.round(ceiling * config.freeTierShare * 100) / 100,
      /// "open": everyone is served. "paidOnly": free-tier checks are resting. "resting": everything is.
      state: panelState(summary.today.usd),
      ...summary,
      store: store().kind,
    });
  } catch (err) {
    sendError(res, err, "spend");
  }
}

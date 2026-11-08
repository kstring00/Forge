# 0032 — Memberships built against a StoreKit file, enforced locally behind one interface

Recorded 2026-11-08. Builds `docs/PRICING.md` (decision 0031) before enrollment.

- **`Hunch.storekit`** holds every product: the group *Hunch Membership* with Pro monthly
  and yearly (level 1), Plus monthly, yearly with a 1-week free trial, and founding yearly
  (level 2), and the consumable `hunch.topup.5`. The scheme's Run action uses it, so the
  whole flow runs in the simulator today. `docs/RELEASE.md` has the exact App Store Connect
  steps to create the same products.
- **The rules are pure, in ForgeCore** (`Membership.swift`): plans and what they include,
  product ids, the trial cap (5), periods (Free resets on the 1st; paid on the monthly
  anniversary of the original purchase, Jan 31 → Feb 28), and `CheckLedger`: a check counts
  only when its Brief arrives, the device's free first check (or one the proxy marked free)
  costs nothing, monthly checks go before bought ones, bought ones never reset, a top-up is
  credited once per transaction, and running checks hold their place.
- **`EntitlementService`** is the one interface the app asks: `state`, `balance`,
  `has(feature)`, `canStartCheck(inFlight:)`, `commitCheck(wasFreeOnProxy:)`,
  `apply(state, jws:)`, `creditTopUp(transactionID:jws:)`. `LocalEntitlements` keeps the
  ledger in UserDefaults today; a `ProxyEntitlements` will send the same calls with the
  App Store's signed transactions to the proxy ledger (#16). The check center is the one
  gate (refuses past the allowance) and the one commit (on `.done` only).
- **`MembershipStore`** (StoreKit 2): products, purchase, restore (`AppStore.sync`),
  `Transaction.updates` and unfinished transactions, the highest active subscription as the
  plan, intro-offer eligibility, top-ups credited and finished.
- **Screens.** The Membership screen from the artboard (status card, Monthly/Yearly, Plus
  with the trial or the founding price, Pro, Free, the top-up, the three promises, the
  required disclosures, Terms and Privacy, Restore, Manage). Reached from the checks pill on
  Home ("3 of 15 checks left · resets Dec 1"), Settings → Membership, and the out-of-checks
  state on the Reality check button. The confirm sheet carries the same line. Never on
  launch, during capture or after a failed run.
- **What-if ideas are Plus.** On Free the Brief shows that the panel has N of them, with
  the way to Plus. Your own work is never gated.
- Terms links to Apple's standard licence until Hunch has its own; Privacy opens what is and
  isn't sent until the policy URL exists (TestFlight item 4).
- Tests: ForgeCore `MembershipTests`; app `EntitlementsTests`.

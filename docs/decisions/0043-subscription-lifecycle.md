# 0043 · Subscription lifecycle: one source of truth, checks through every event

Date: 2026-11-09. Builds on 0032 (membership) and 0042 (rollover). Prices and allowances are unchanged; they stay in `proxy/config/hunch.ts`.

## The bug: "I downgraded Pro → Plus and still got charged"

Apple never charged twice. `Hunch.storekit` was set up right: every plan is in one group, "Hunch Membership", with Pro (monthly and yearly) at level 1 and Plus (monthly and yearly) at level 2. Per Apple, a downgrade creates **no transaction** until renewal. Apple only books the switch in the subscription's renewal info (`autoRenewPreference`). The app got two things wrong:

1. **The app couldn't see a booked downgrade** (causes c and d). It read only `Transaction.currentEntitlements`, which correctly says "Pro" until renewal, and never read the renewal info.
   - So after the person picked Plus, the screen still showed Pro with a "buy Plus" button, and said nothing about the switch.
   - Each tap opened Apple's payment sheet again, showing Plus's price. That looks like a second charge.
   - The app also never re-read the plan on returning from Settings or Apple's sheet. A downgrade or cancel made there stayed invisible.
2. **When the downgrade landed, checks dropped to zero** (a ledger bug). Check cycles were pinned to `originalPurchaseDate`, which Apple never changes within a group.
   - After an upgrade, the billing date moves, so the renewal where the downgrade lands falls in the middle of an old check cycle.
   - Plus then started inside Pro's cycle with Pro's usage: "0 of 15 left" for a month just paid for. `testADowngradeAtRenewalStartsPlusWithFreshChecks` reproduces it.

Not the cause: (a) levels wrong or tied, and (b) a product in another group. Both were checked and are correct in `Hunch.storekit` and in `RELEASE.md` §2. Use the same levels in App Store Connect.

## Apple's rules, checked against current documentation (Nov 2026)

- **Upgrade** (to a higher level): takes effect immediately. Apple refunds the unused part of the old plan to the original payment method and charges the new one; a new billing date starts.
  - Source: App Store Connect Help, "Auto-renewable subscription information".
- **Downgrade:** takes effect at the next renewal date, and the lower plan is charged then. No transaction exists until then (Apple staff, forum 721594); `purchase()` returns the existing transaction.
- **Crossgrade** (same level, the brief's "same plan, different length"):
  - Different duration (monthly ↔ yearly): takes effect at the next renewal.
  - **Same duration: takes effect immediately, with proration.** This was the one difference from the brief. It only applied to Plus yearly ↔ Plus founding yearly; with the founding product gone (§4), every same-level switch is monthly ↔ yearly, at renewal. The app no longer has a "Switch now" case.
- **Level 1 is the highest.**
- **`currentEntitlements`** includes subscriptions that are subscribed or in the billing grace period. It excludes subscriptions in billing retry without grace, and anything refunded or revoked.

## 1–2. One source of truth

- **The plan** is `MembershipState(entitlement:)` (ForgeCore), built from the entitled transaction plus that subscription's status and renewal info. It records:
  - what the subscription renews to (a booked switch)
  - whether it will renew (a cancel)
  - grace period or billing retry
  - family sharing
- **Listening:** `MembershipStore` listens to `Transaction.updates` and `Product.SubscriptionInfo.Status.updates` from launch, and re-reads the plan whenever the app comes to the foreground.
- **Transactions:**
  - Every verified transaction is finished after it's handled.
  - A top-up is credited once per transaction ID.
  - A refund removes its checks once.
- **Undoing a booked switch or a cancel:** the app re-buys the current product.
  - This works in Xcode testing and the sandbox. One developer reports that the live App Store refuses it (forum 816113).
  - On failure, the app opens Apple's Manage sheet, where it always works.

## 3. The plan screen

- **Each card's label:** "Current", "Upgrade now", "Switches on Dec 9", "Starts Dec 9" (already booked), or "Ends Dec 9" (cancelled).
- **Status lines:**
  - Booked: "You're on Pro until Dec 9, then Plus · monthly." with **Keep Pro**.
  - Cancelled: "Pro ends Dec 9. You'll move to Free." with **Resubscribe**.
- **Before any change, an alert says what happens.** Wording is in `PlanOption.confirmation`.
  - Upgrade: "Apple charges $X today and gives back the unused part of …"
  - Downgrade or switch: "… starts then at $X. Nothing is charged today."
- **Billing problem:**
  - A banner on Home and on the plan screen links to Apple's payment page (`https://apps.apple.com/account/billing`).
  - During the grace period the plan stays on. Past it, the plan is paused (Free) until the payment goes through.

## 4. The founding price: first year at the founding price (decided)

**Decided (Nov 9):**
- **No founding product.** `hunch.plus.founding.yearly` is removed from `Hunch.storekit` and the app, and is never created in App Store Connect.
- **Testers get an offer code on Plus yearly:** $39.99 for the first year, then $59.99. The promise is "first year at the founding price".
- **Redeeming:** testers use **Redeem a code** at the bottom of the plan screen, or Apple's redemption link.
- **Display:** the app shows "founding member" while the first, discounted year runs: Plus yearly bought with an offer code.
- **Setup:** steps are in `RELEASE.md` §4.

The analysis behind it:

Apple's Edit Subscription sheet lists every product in the group, and there is no way to hide one. Two facts make this harder than it looks:

- **TestFlight purchases are sandbox.** A tester's founding subscription in TestFlight never becomes a real App Store subscription. Founders would have to subscribe again after launch, at whatever is offered then.
- **Removing a product from sale also stops renewals for the people already on it**, after at least 31 days. (`RELEASE.md` §4 said the opposite and is corrected.) So taking the founding product off sale after the beta would end every founder's price.

Options:

| Option | Founders keep $39.99 | Others can't get it | Cost to build |
|---|---|---|---|
| A. Keep `hunch.plus.founding.yearly` on sale | For as long as they stay | **No:** any Plus subscriber can pick it in Apple's sheet | None |
| B. Offer codes on Plus yearly (custom code for testers, or one-time codes) | **First year only** (Apple's maximum for a yearly offer), then $59.99 | Yes | App Store Connect only; the app already handles redemptions as ordinary transactions |
| C. Promotional offers, signed by the proxy | One year per offer; could be re-offered each year | Yes | Server signing (after #16/#22) |
| D. Never create the founding product in App Store Connect | n/a | Yes | None |

Chosen: **B with D**. C (server-signed offers renewed each year) stays possible later, after #16/#22, if a lifetime price is wanted.

## 5. Yearly plans get monthly checks

A check cycle is a monthly slice of the billing period (`CheckPeriod.cycle`), anchored on the current transaction's purchase date.

- **Yearly plans** get twelve cycles on the purchase day. Bought on the 31st, a cycle starts on the last day of shorter months.
- **Monthly plans** get one cycle, from purchase to renewal.
- **StoreKit's test clock** shrinks a year to six minutes; that year is split into twelve 30-second "months" so it can be watched in the simulator.
- **Past the renewal date** (grace period, or before the App Store has said it renewed), no new allowance is granted.

## 6. Rollover through every event

The approved rules apply throughout: carried checks are spent first, then this month's, then bought ones; carry is capped at one month's allowance; carried checks expire when the cycle they rolled into ends. Each case has a test in `ForgeCore/Tests/ForgeCoreTests/SubscriptionLifecycleTests.swift`:

1. **New subscription:** a fresh cycle from the purchase; Free's unused check carries (Free's cap is 1).
2. **Renewal:** the new transaction starts a cycle; unused checks carry.
3. **Upgrade** (immediate, Plus → Pro; decided Nov 9): carried-over and unused checks move over **together**, capped at the old plan's allowance (× the carry setting), and expire at the end of the new cycle like any carried check. The new allowance starts now; cycles follow the new billing date. At a renewal, carried checks still expire as usual.
   - Carried checks are spent before this month's. So whenever some carried checks are left, none of this month's have been used, and this month's unused ones already fill a one-month cap.
   - With today's setting (`capMonths: 1`), the result is therefore the same as before. The rule changes the outcome only if the carry cap is raised.
   - Tested both ways: `testCarriedChecksMoveWithAnUpgrade`.
4. **Downgrade** (booked): nothing changes until renewal. At renewal, up to the new plan's allowance carries.
5. **Undo a booked downgrade:** nothing changes, and no events are recorded.
6. **Monthly ↔ yearly:** at the switch date the anchor moves; rollover works as at a renewal.
7. **Cancel:** runs to the end of the paid period with its checks. At expiry, 1 carries into Free.
8. **Resubscribe before expiry:** as if never cancelled.
9. **Resubscribe after Free:** fresh allowance; carry by the same rules.
10. **Grace period:** plan and checks kept. If it lapses into billing retry, it's an expiry. Payment recovering starts a new cycle.
11. **Refund or revocation:** an expiry at that moment. Balances never go below zero, including for a check that was already running.
12. **Trial:** 5 checks that never carry. Trial → paid starts the full allowance; trial cancelled → Free.
13. **Founding:** it *is* Plus yearly, bought with the founding offer code. Its second year is a regular year.
14. **Top-ups:** kept per purchase, spent oldest first, never touched by plan changes. A refund removes only that purchase's unused checks.
15. **Family Sharing:** off for every product in `Hunch.storekit`, and `RELEASE.md` says to leave it off. If it were on, a shared plan would act like the person's own (tested); each member would get a full allowance on their own phone. Apple never shares consumables, so top-ups stay with the buyer.


## 7. Recovering checks

- **Restore Purchases** (`AppStore.sync`) brings back the plan and cycle dates. They are always rebuilt from Apple: the current transaction's purchase date and renewal date.
- **Top-ups in Apple's history:**
  - On iOS 17, finished consumables aren't in `Transaction.all`; refunded ones are.
  - From iOS 18, they are, with `SKIncludeConsumableInAppPurchaseHistory` (now in Info.plist).
  - Even then, the history shows a purchase, not how many of its checks were spent. Giving them back on every reinstall would let one $2.99 purchase be replayed forever, so Restore only records them as known.
  - Apple's position is the same: the app is responsible for consumable balances.
- **Interim fix, built: the ledger in iCloud key-value storage** (`LedgerCloud`).
  - It survives deleting the app and follows the Apple ID to a new phone.
  - The two copies merge without ever adding checks: the later cycle wins; within a cycle the higher spend wins; each top-up keeps the lower balance; a refund on either copy stands.
- **The free-check leak gets smaller, not worse.** The free first check stays used across reinstalls on the same Apple ID. A different iCloud account, or none, behaves as today.
- **It's off until signing is set up.** It needs the iCloud key-value entitlement, which needs a development team. Turn it on with one line in `Local.xcconfig`; see `Local.xcconfig.example`. Without it, nothing changes.
- **Events:** every grant, carry, expiry, spend, top-up and refund is recorded with its transaction ID (`CheckLedger.events`, the latest 1,000). With them, #22's server can rebuild a balance and then follow App Store Server Notifications.

## 8. Tests

- **ForgeCore:** 126 tests, including 26 lifecycle tests.
- **Proxy:** 39 tests.
- **App** (`ForgeTests/MembershipStoreKitTests.swift`, StoreKitTest; run with Cmd+U on the Mac): buy, trial cap, upgrade, downgrade with no new transaction then renewal into Plus, undo, monthly → yearly, accelerated renewal with carry, yearly plan getting monthly checks, cancel and resubscribe, expiry, refund, top-up refund, billing retry with and without grace, interrupted purchase, Ask to Buy.
- **Manual:** the simulator checklist is in the PR description.

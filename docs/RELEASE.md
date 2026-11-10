# Releasing Hunch

The archive, App Store Connect and TestFlight steps arrive with TestFlight item 5. This
file starts with the part that has to match the code exactly: the in-app products.

## In-app purchases (decision 0032)

The app's products are defined twice and must agree: in `Hunch.storekit` (what the
simulator sells today) and in App Store Connect (what TestFlight and the App Store sell).
The ids, prices, periods, levels and the trial below are the contract. Do these once
enrollment as the LLC is approved.

### 0. Before any product can be sold

1. App Store Connect → **Business** (Agreements, Tax, and Banking): accept the **Paid Apps**
   agreement, add the LLC's bank account, and complete the US tax forms (W-9). Until the
   Paid Apps agreement shows *Active*, products stay *Missing Metadata* in sandbox.
2. Apply to the **App Store Small Business Program** (developer.apple.com → Programs). The
   pricing doc's margins assume Apple's 15%.
3. Certificates, Identifiers & Profiles → the App ID `com.stringhamwebdesign.hunch`
   (or whatever `APP_BUNDLE_ID` ships as) → enable **In-App Purchase** (on by default) and
   **App Attest** (#16).
4. App Store Connect → **Apps** → **+** → New App: platform iOS, name **Hunch**, primary
   language English (U.S.), the bundle id from step 3, SKU `hunch-ios`.

### 1. The subscription group

App → **Monetization** → **Subscriptions** → **Create** subscription group.

- Reference name: `Hunch Membership`
- Group localization (English U.S.): display name **Hunch Membership**, app name display
  **Use App Name**.

### 2. The four subscriptions

In the group, **Create** each one. For every subscription:

- **Availability:** all countries and regions.
- **Price:** choose the US price below as the base; let App Store Connect fill the rest.
- **Localization (English U.S.):** display name and description below.
- **Review information:** a screenshot of the Membership screen (simulator, iPhone 6.7"),
  and the review note: *"Hunch Membership. Checks are AI research on an idea the user
  wrote. Free plan: 1 check a month. Founding members get the first year of Plus yearly
  at $39.99 with an offer code."*
- **Family Sharing:** off.

| Reference name | Product ID | Duration | US price | Level | Display name | Description |
|---|---|---|---|---|---|---|
| Pro · monthly | `hunch.pro.monthly` | 1 month | $24.99 | 1 | Hunch Pro | 50 checks a month, faster answers, deeper research and exportable reports. |
| Pro · yearly | `hunch.pro.yearly` | 1 year | $179.99 | 1 | Hunch Pro (yearly) | 50 checks a month, faster answers, deeper research and exportable reports. |
| Plus · monthly | `hunch.plus.monthly` | 1 month | $9.99 | 2 | Hunch Plus | 15 checks a month, unused ones carry over, and Your patterns. |
| Plus · yearly | `hunch.plus.yearly` | 1 year | $59.99 | 2 | Hunch Plus (yearly) | 15 checks a month, unused ones carry over, and Your patterns. |

Then in the group's **Subscription Levels**, drag so Pro (both) is level 1 and Plus (both)
is level 2. Same level = crossgrade; Plus → Pro = upgrade, immediate; Pro → Plus =
downgrade, at the next renewal. The app already handles all three.

### 3. The free trial on Plus yearly

`hunch.plus.yearly` → **Subscription Prices** → **View all subscription pricing** →
**Introductory offers** → **Create**: all countries, start today, no end date, type
**Free**, duration **1 week**. Eligibility is App Store-managed: new subscribers to the
group only. The app caps trial users at 5 checks (`MembershipState.trialChecks`).

No introductory offer on any other product.

### 4. The founding offer: first year at the founding price

Decision 0043 §4. **Don't create a founding product.** Apple's Edit Subscription sheet
lists every product in the group to every subscriber, so anyone could pick it; and taking
a product off sale later would also stop founders' renewals. Founders get an **offer code**
on Plus yearly instead: **$39.99 for the first year, then $59.99.**

`hunch.plus.yearly` → **Subscription Prices** → **Offer Codes** → **Create**:

- Reference name: exactly `Founding`. The app shows "founding member" only when the
  purchase carries this name (StoreKit reports an offer code by its reference name, not by
  the code typed). The name the app looks for is `foundingOfferID` in
  `proxy/config/hunch.ts`; change both together.
- Customer eligibility: **New**, **Expired** and **Existing** subscribers.
- Offer: **Pay up front**, duration **1 year**, price **$39.99** (let App Store Connect fill
  the other countries).
- Codes: a **custom code** (for example `FOUNDERS`) with a redemption limit about the size
  of the tester list, or **one-time codes**, one per tester (valid up to six months).

Send each tester the code with: open Hunch → the plan screen → **Redeem a code**. (Or the
App Store's redemption link.) Codes can only be redeemed once the app is **Ready for
Sale**, and TestFlight purchases are test purchases, so testers redeem after the App Store
launch. To try the flow before launch, App Store Connect makes one-time **sandbox codes**
(redeemed from the Sandbox Apple Account settings, iOS 16.3 or later). The app shows "founding member" for that first year; the
renewal after it is a regular year of Plus.

### 4b. Billing Grace Period (turn it on)

Off by default. Without it, a failed renewal pauses the plan at once; with it, the person
keeps the plan while Apple retries the payment, and the app shows its "update payment"
banner (decision 0043). It is one setting for the whole app, not per product.

App → **Subscriptions** (sidebar) → **Billing Grace Period** → **Set Up Billing Grace
Period**:

- Duration: **16 days** (the choices are 3, 16 or 28).
- Eligible subscribers: **All Renewals** (so a trial turning paid is covered too).
- Environment: **Sandbox** first; switch to **Production and Sandbox** before launch.

### 5. The top-up

App → **Monetization** → **In-App Purchases** → **Create**:

- Type **Consumable**, reference name `Top-up · 5 checks`, product id `hunch.topup.5`.
- Price $2.99. Availability: all.
- Localization: display name **5 extra checks**, description *"Five more checks. They
  never expire and are used after your monthly ones."*
- Review screenshot: the Membership screen's top-up row. Family Sharing: not available for
  consumables.

### 6. Check the two definitions agree

1. In Xcode, select `Hunch.storekit` → **Editor** → **Sync with App Store Connect** (sign
   in with the developer account, pick the Hunch app). Xcode pulls the products down; any
   difference from the table above shows as a change in the file. There should be none
   apart from internal ids.
2. Commit the synced `Hunch.storekit` so the simulator keeps matching the store.

### 7. Sandbox testing on a device

1. App Store Connect → **Users and Access** → **Sandbox** → **Test Accounts** → **+**: one
   new account per test (a fresh email each; trials are once per account).
2. On the iPhone: Settings → **Developer** → **Sandbox Apple Account** → sign in with it.
3. Run a Release-like build from Xcode with the scheme's StoreKit configuration set to
   **None** (Product → Scheme → Edit Scheme → Run → Options), so purchases go to the
   sandbox instead of `Hunch.storekit`. Sandbox renewals are accelerated: a month is five
   minutes, a year an hour.
4. Buy Plus yearly (trial), then Pro monthly (upgrade), then the top-up; Restore after
   deleting and reinstalling; Settings → Manage subscription to cancel.

### 8. Ship the products with a build

The first subscriptions must be submitted for review **together with an app version**:
on the version page, **In-App Purchases and Subscriptions** → **+** → select all five (four subscriptions and the top-up).
After that, prices can change in App Store Connect without an app update.

### Later (with the proxy ledger, #16)

- App → **App Information** → **App Store Server Notifications**: production and sandbox
  URLs `https://<proxy>/api/notifications` (Version 2). The proxy verifies each signed
  notification and updates the per-user ledger.
- An **In-App Purchase key** (Users and Access → Integrations → In-App Purchase) for the
  App Store Server API, as `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_PRIVATE_KEY`
  on Vercel.
- Sign in with Apple, so a plan follows the person across devices.
- Then replace `LocalEntitlements` with a `ProxyEntitlements` that sends the `jws` it is
  already given; nothing that calls `EntitlementService` changes.

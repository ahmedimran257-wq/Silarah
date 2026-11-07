# RevenueCat pre-release QA

Silarah uses two deliberately separate billing environments:

- Debug QA uses `REVENUECAT_TEST_KEY` (`test_`) and RevenueCat Test Store.
- Release builds use `REVENUECAT_ANDROID_KEY` (`goog_`) and Google Play Billing.

The app and build scripts reject a Test Store key in release mode. Never upload a
debug/Test Store build to a Play testing track.

## Automated Android Test Store scenarios

Start an Android emulator, then run each scenario from the repository root. When
the RevenueCat dialog appears, press the button named by the script.

```powershell
.\tool\test_revenuecat_android.ps1 -Action valid
.\tool\test_revenuecat_android.ps1 -Action cancel
.\tool\test_revenuecat_android.ps1 -Action failed
```

The valid scenario requires the `premium` entitlement after purchase and restore.
The other scenarios require the expected native error and prove that Premium was
not granted. The remote verifier also requires the current offering to contain
monthly and three-month packages before a device test may start.

Verified on 10 August 2026 with Android emulator `emulator-5554`:

- Monthly Test Store purchase and active `premium` entitlement: passed.
- Restore while Premium is active: passed.
- User cancellation without entitlement: passed.
- Forced billing failure without entitlement: passed.
- Accelerated monthly renewal and final expiry visible in RevenueCat customer
  state: passed.

## Google Play sandbox sign-off

### Configuration evidence — 23 September 2026

- Both Play base plans are active: `silarah_monthly:monthly` and
  `silarah_three_month:three-month`. The three-month plan was activated on
  22 September for India only at exactly INR 749 (Play initially rounded the
  price to INR 750; it was corrected before saving).
- Both products are imported into RevenueCat and attached to `premium`.
- The current `default` offering maps `$rc_monthly` and `$rc_three_month` to
  the matching Play products and base plans. Existing Test Store mappings
  remain unchanged.
- The public SDK API returned both expected Play product/base-plan pairs with
  the production Google Play key. Re-run
  `tool/verify_revenuecat_play_offering.ps1` to check for configuration drift;
  the script never prints keys or performs a purchase.
- Test Store offering verification also passed. The device purchase results
  above remain historical August evidence, not a fresh September test.
- On 23 September, a fresh RevenueCat credential check could read both
  catalogs but still reported the package as not found for subscription-purchase
  validation. Play Console showed the internal track **Inactive**, with only
  draft `Silarah 1.0.0 (42042) - Internal QA` and no delivered test release.
  Catalog setup is not payment sign-off. Prepare and verify a fresh signed
  candidate before requesting internal-release publication approval; do not
  publish the older draft simply to clear this error.
- Google real-time developer notifications are not connected yet. Configure and
  verify delivery before sign-off on renewals, grace/hold and expiry handling.
- No Play release was published and no real-money transaction was performed
  during this configuration work.

Test Store proves the SDK, offering and app entitlement flow. It does not replace
Google Play sandbox testing. Before an internal-testing release is approved:

1. Create and activate `silarah_monthly` and `silarah_three_month` base plans in
   Play at INR 299/month and INR 749/3 months.
2. Import both products into RevenueCat and attach them to entitlement `premium`
   and the current offering.
3. Upload the signed release AAB to the internal track and add license testers.
4. Install from the Play opt-in link; do not sideload the release artifact.
5. Verify purchase, cancellation, renewal, grace/billing issue, restore and expiry
   with two tester accounts and confirm each server event exactly once.

The production webhook intentionally rejects Test Store events. Webhook mutation,
notification and transactional-email testing must use an isolated Supabase staging
project or the Google Play sandbox with a real Supabase UUID as RevenueCat app user
ID; Test Store events must never grant production entitlements.

## Google Play sandbox runbook (build 42045)

The production webhook rejects `SANDBOX` events unless the purchaser's
Supabase user ID is listed in the `REVENUECAT_SANDBOX_TESTER_IDS` Edge
Function secret (comma-separated). Delete the secret when QA ends.

### Before testing (owner)

1. Deploy the webhook from `release/42045`:
   `npx supabase functions deploy revenuecat-webhook --project-ref jukpscfxzwttgtxvrbmj`
   (`supabase/config.toml` keeps JWT verification off for it).
2. Play Console → Setup → License testing: add the Gmail accounts used on
   the test phones; set the response to `RESPOND_NORMALLY`.
3. Play Console → Monetization setup: connect Real-time developer
   notifications to the Pub/Sub topic shown in RevenueCat → Project
   settings → Google Play. Send a test notification from RevenueCat.
4. Upload the 42045 AAB to Internal testing, add the testers, and install
   from the opt-in link on each phone (uninstall any sideloaded copy first).
5. Sign in to Silarah on each phone, then add those users' Supabase IDs to
   `REVENUECAT_SANDBOX_TESTER_IDS` (Dashboard → Edge Functions → Secrets).

### Scenarios

Sandbox subscriptions renew quickly: a monthly plan renews every 5 minutes
and a three-month plan every 10 minutes, up to six renewals.

| # | Scenario | How | Expected server result |
|---|---|---|---|
| 1 | Monthly purchase | Buy monthly with the test card that always approves | `INITIAL_PURCHASE` once; `subscription_status = active`; Premium features unlock; one confirmation email |
| 2 | Renewal | Wait 5 minutes | `RENEWAL` events; expiry moves forward; no duplicate emails per event |
| 3 | Cancellation | Cancel in Play Subscriptions | `CANCELLATION`; access continues to expiry, then `EXPIRATION` and `subscription_status = none` |
| 4 | Restore | Reinstall, sign in, tap Restore | Premium returns without a new purchase |
| 5 | Three-month purchase | Second tester buys three-month | Same as 1 with `silarah_three_month` |
| 6 | Billing issue | Test card "Slow test card, declines after a few minutes" | `BILLING_ISSUE`; `subscription_status = grace` with grace expiry; payment email |
| 7 | Refund | Play Console → Order management → refund an **active** order with "Remove entitlement" | RevenueCat sends `CANCELLATION` (`UNSUBSCRIBE`, already-ended expiry) plus `EXPIRATION`; recorded as `REVOCATION` + `EXPIRATION`; status `none`; only the "ended" notification and email. A `CUSTOMER_SUPPORT` cancellation is recorded as `REFUND` |
| 8 | Non-tester rejection | Remove a tester from the secret and repeat 1 | Webhook logs "Rejected non-production event: environment"; no state change |

### Server check after each scenario

```sql
select u.id, u.subscription_status, u.subscription_expires_at,
  (select json_agg(json_build_object('type', e.event_type, 'at', e.event_timestamp_ms)
     order by e.event_timestamp_ms)
   from public.subscription_events e where e.user_id = u.id) as events,
  (select count(*) from public.transactional_email_outbox o
   where o.user_id = u.id and o.status = 'sent') as emails_sent
from public.users u where u.id = '<tester supabase id>';
```

Sign-off needs every row to show each event exactly once.

### Results — 24 October 2026 (build 42045, production backend)

Tester `3a9a91ec-…` on OnePlus 8, Google Play sandbox, "Test card, always approves":

| Scenario | Result |
|---|---|
| Monthly purchase | Play confirmed the test purchase (no charge) |
| Renewals ×3 | `RENEWAL` recorded once each; status `active`; one email and one in-app notification each |
| Cancellation | `CANCELLATION` recorded once; access kept until period end; email sent |
| Expiry | `EXPIRATION` recorded once; status `none`; email sent |
| Three-month purchase | `INITIAL_PURCHASE` (`silarah_three_month:three-month`) recorded once; status `active`; one email and one in-app notification |
| Billing issue | "Slow test card, declines after a few minutes": `BILLING_ISSUE` recorded once; status `grace` until 08:25:05Z; the `BILLING_ERROR` cancellation was correctly deferred; one email and one notification. Grace then ended with `EXPIRATION` (status `none`, one email) |
| Restore | Premium persisted after an app restart; no new purchase. A full reinstall was not repeated |
| Refund | First try refunded an already-expired order (`GPA.3374-…`); RevenueCat sent nothing. Retest on an active monthly order (`GPA.3371-7716-7959-24655`): `REVOCATION` and `EXPIRATION` recorded once, status `none`, one "ended" notification and email, no "access continues" message |

Findings fixed during the run:

- The production RevenueCat webhook was set to "Production only", so sandbox
  events went to the staging webhook. For QA it is temporarily set to "Both
  Production and Sandbox"; production still accepts only allowlisted testers.
- RevenueCat sends Play products as `subscriptionId:basePlanId`
  (`silarah_monthly:monthly`). The webhook rejected them as unknown products,
  which would also have rejected real purchases. Fixed in `58bf270` and
  deployed (function version 47).
- Real-time developer notifications were already connected (last received
  29 September); the earlier note saying otherwise was out of date.
- `REVENUECAT_ALLOWED_PRODUCT_IDS` listed only the monthly product, so the
  three-month purchase was rejected as an unknown product until the secret
  was set to `silarah_monthly,silarah_three_month`.
- RevenueCat has no `REFUND` event: store refunds arrive as `CANCELLATION`
  with `cancel_reason = CUSTOMER_SUPPORT`, which the webhook treated as a
  renewal cancellation (member left `active`, told access continues). Fixed in
  `570f123`; **not yet deployed**.

Resolved: three-month receipts were titled "Silarah Premium Monthly"
(`planName()` matched "month"); fixed in `c6fc805` and deployed.

- A Play Console refund that removes entitlement arrives as an `UNSUBSCRIBE`
  cancellation whose expiry already passed. The webhook sent "Premium remains
  available" next to the "ended" message. Fixed in `b61a377` (recorded as
  `REVOCATION`, no message of its own); refund events with a negative price
  are no longer rejected. Deployed with `570f123` and `c6fc805`.

After QA: the production RevenueCat webhook is back on "Production only"
(24 October). Still to do by the owner: delete `REVENUECAT_SANDBOX_TESTER_IDS`.

### Results — 7 November 2026 (build 42047, production backend)

Tester Khatun (`3a9a91ec-…`, ahmedimran257, license tester) on the OnePlus 8
with `1.0.0 (44047)`, Google Play sandbox, "Test card, always approves".

| Scenario | Result |
|---|---|
| Monthly purchase | Premium unlocked in the app at 07:14 UTC; RevenueCat recorded New Sub |
| Server state | The production webhook was on "Production only", so the sandbox purchase went to staging (`user_not_found`). With the user's OK it was set to "Both" and `REVENUECAT_SANDBOX_TESTER_IDS` was set to this one ID for the test |
| Renewals | Each 5-minute `RENEWAL` recorded once; status `active`; expiry kept 10 min of slack (migration 291); one email and one in-app notice each. A retried older renewal arrived out of order and neither shortened the expiry nor sent a second email |
| Restore | Signed out and back in: Premium returned without a purchase |
| Cancellation | `CANCELLATION` once at 07:37; access kept until period end; one email, one notice |
| Expiry | `EXPIRATION` once at 07:39; status `none`; one email, one notice; the app dropped Premium |
| Non-tester rejection | Before the secret was set, production rejected the sandbox renewal (`Rejected non-production event: environment`) |

After the test the webhook was set back to "Production only" and
`REVENUECAT_SANDBOX_TESTER_IDS` was deleted (7 Nov).

Found and fixed in 42048: a woman who pays saw no Premium status card and no
Manage Subscription link (the card was hidden for all women).

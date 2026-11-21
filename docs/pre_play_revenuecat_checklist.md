# Pre-Play RevenueCat checklist

Saved: 14 September 2026

## Release checkpoint — 28 September 2026

- All four CI jobs passed on `4759546` (run `36312527810`). This includes
  the CI-key Android bundle, not a real upload-key release artifact.
- The MFA follow-up reuses the shared staff-session expiry guard, removes
  the unused replacement-password field, and clears the signed pending-factor
  cookie at its actual `/mfa` path. Local regression tests, lint, typecheck,
  production build and secret scan pass. Its new commit needs fresh CI.
- The live admin security-header verifier passes. This does not mean the
  pending admin source changes have been deployed.
- Database review found client write grants on the platform-owned PostGIS
  reference table in both projects. A zero-row staging check reproduced the
  permission; a rolled-back revoke attempt did not remove the grants. Owner
  support remediation and staging readback are required; no records changed.
- Wider review, production deployment, fresh signed 42044 artifacts, device
  installation and actual Play sandbox payments remain unfinished.

## Next signed candidate — 27 September 2026

- Play Console still shows uploaded code `42042` and the inactive old draft.
- Reserve `1.0.0+42044` for the cleanup/security candidate, distinct from the
  historical local 42043 bundle. Do not publish 42042 or reuse its artifact.
- Source `f65e398` passed all four CI jobs (`36295228405`), including the
  CI-key Android bundle. Its clean Windows Flutter run passed all 644 tests.
  The subsequent admin error-redaction change needs its own exact-head CI.
- Build/device installation is held pending those fixes and checks. The phone
  remains on 42042; no new signed 42044 artifact has been built or installed.
- Staging now has migration 265 and the JPEG validation guard. Live upload,
  replay and rollback-only privacy/billing checks pass. Production migration
  and deployment are still pending; these are not Play purchase results.
- The 87-table app-owned backup restore drill passed in an ephemeral staging
  database; managed Auth/Storage/Vault and full-service recovery remain separate.
- Keep the candidate off Play until the remaining release gates and bundle
  identity/signature checks are complete. Internal publication requires approval.

## Expanded release gate — 25 September 2026

Use [the pre-launch app checklist](pre_launch_app_checklist.md) alongside this
billing/release sequence. It tracks all 22 requested security, reliability and
operational checks plus safe test-data removal. Cleanup and incremental security
fixes are still isolated; the historical 42043 AAB does not include them.

## Current candidate — 23 September 2026

- Play Console's latest releases/bundles page shows uploaded code `42042`
  and an inactive internal track with that older draft. Do not publish it.
- The new candidate is permanently versioned `1.0.0+42043` in `pubspec.yaml`.
- Both Play products are now imported, attached to `premium`, and mapped to
  the current offering. The production-key offering verifier passes.
- Freeze this updated source, run CI on that exact commit, build with the real
  upload key, and record the new AAB certificate/hash before replacing the draft.
- Production database was checked at migration 259; staging at 264. The five
  pending backend migrations must be backed up, deployed and verified before
  the new app is delivered. Never run a clean reset against production.
- Actual Google Play purchase validation, real-time notifications, license
  testing and Play-delivered payment lifecycle evidence remain required.

The original checklist below records the September 14 baseline; its statements
about an empty Play draft and reserved code 42042 are historical, not current.

## Before the first Internal Testing AAB

1. Freeze and commit the complete release source, including the latest app,
   legal, pricing, localization, website and asset changes.
2. Play Console was checked on 14 September 2026. Silarah has an empty Internal
   Testing draft and no uploaded app bundles, so there is no existing Play-side
   version code. The release source reserves `1.0.0+42042`, above the 42039
   release baseline and the locally installed 42041 ARM64 split APK.
3. Run the final release gate on that exact commit:
   - Dart formatting, Flutter analysis and the complete Flutter test suite.
   - Secret scan and Supabase migration validation.
   - Admin lint, type-check, production build and dependency audit.
   - Supabase Edge Function formatting, linting and tests.
   - Website, legal and pricing contract tests.
4. Build a production AAB for `com.silarah.app` with the Silarah upload key and
   the RevenueCat Google Play public SDK key (`goog_`), never the Test Store
   key. Validate its bundle metadata, certificate, version code and SHA-256.
5. Upload only to Google Play Internal Testing.

## After uploading, before public production

1. Create and activate the India subscription plans: monthly at INR 299 and
   three months at INR 749.
2. Import the Play subscription/base plans into RevenueCat and connect them to
   the `premium` entitlement, the `$rc_monthly` and `$rc_three_month` packages,
   and the current production offering.
3. Confirm RevenueCat Play service credentials, production webhook
   authorization and idempotent server synchronization.
4. Add Internal Testing and license testers, opt in on both physical devices,
   and install the Play-delivered build.
5. Test monthly and three-month purchases, displayed prices, approval,
   decline, pending purchase, restore, renewal, cancellation, expiry, grace
   period, account hold, refund, entitlement revocation and webhook replay.
6. Verify referral Premium interaction and every paid entitlement: browsing,
   interests, messaging rules, advanced filters, profile viewers and boosts.

## Issuing a refund (verified 21 November 2026)

Refund only in Play Console → Order management → the order → **Refund**, and
always tick **Remove entitlement**.

- With the box ticked, Google ends the subscription at once: RevenueCat sends a
  cancellation and an expiry within a minute, Silarah records `REVOCATION` and
  `EXPIRATION`, Premium ends, and the member gets "Your Silarah subscription has
  ended". The refund itself reaches RevenueCat later (about 2 hours in the
  test) and is recorded as `REFUND`.
- Without the box, Google returns the money but keeps the subscription. Google
  then leaves the order out of its voided-purchase feed and RevenueCat never
  learns of the refund, so Silarah keeps Premium to the end of the period and
  has no refund record. (Test of 21 Nov: a refund without the box was still
  missing from RevenueCat hours later.)
- A refund of an earlier, already-ended period changes nothing in the app;
  RevenueCat reports refunds of the latest period only.
- While the member has the app open, the billing notification makes the app
  re-read Premium, so the change shows without restarting.

## Later production gates

- Complete Google merchant/payment verification before accepting real paid
  subscriptions.
- Decide Play Integrity App Check enforcement after release-device metrics are
  verified.
- Classify the remaining Supabase Security Advisor findings.
- Complete the final backup restore drill, Play listing, Data safety and policy
  declarations, and exact-release-candidate QA.

# First production release checklist

## Latest checkpoint — 7 November 2026 (closed-testing gate)

Candidate: `1.0.0+42048`, published to Internal testing on 7 Nov (42047
went out earlier the same day; 42048 adds the fixes found during this gate).
Branch `release/42045`.

| Gate | Result | Evidence |
|---|---|---|
| `flutter analyze` | PASS | no issues (42047 and 42048) |
| Full Flutter suite | PASS | 841/841 on 42047; 850/850 on 42048 |
| Release AAB 42047 | PASS | upload-key signed, 112.7 MB, no `[perf]` / `SILARAH_PERF_LOG` in any `libapp.so`, symbols uploaded |
| Internal testing release | PASS | 42047, then 42048 active on Internal testing with en-US / hi-IN / ur notes |
| 42048 fixes on device | PASS | 44048 on the OnePlus: a woman with Premium sees "Silarah Premium · Active" and Manage Subscription, which opens Google Play Subscriptions to cancel |
| Upgrade on OnePlus (44046 to 44047) | PASS | session and data kept |
| Payment lifecycle (test card) | PASS | see `revenuecat-qa.md`, results 7 Nov |
| Two-account flow | PASS with fixes | profile-menu Block did nothing (fixed in 42048); see `device-qa.md` |
| New-user path | PASS | one sign-up code email; 5 steps saved; resume after force-stop; photo uploaded |
| Crashlytics | PASS | controlled non-fatal `uncaught:network_unreachable` from 46047 (42047 source); 0 crashes in 24 h |
| Android 9 (API 28 emulator) | PASS | launch, sign-in, Discover, paywall render (plans need Play, absent on emulator) |
| Delete account | PASS | `pending_deletion`, signed out, 30-day recovery shown |
| Payments profile | BLOCKED (owner) | see "Requires the Google Play developer account" |

Fixed in 42048:

- Profile → ⋮ → Block confirmed but never called `block_member` (the
  sheet's context was gone after it closed). Covered by
  `test/profile_block_flow_test.dart`.
- Women who pay for Premium saw no Premium status card and no Manage
  Subscription (Google Play cancel) link; the card was hidden for all women.
- After a report, a member who cannot open the chat (men without Premium)
  had no way to block; the report confirmation now offers "Block {name}".
- Push notifications showed a grey disc as the status-bar icon; a
  monochrome `ic_stat_silarah` icon is now the FCM default.
- "Messages" title wrapped mid-word next to the unread badge.
- "We could not verify your daily allowance" popped up after any
  background allowance refresh failed (usually the network waking after
  unlock). The server never failed (34/34 OK in 24 h). Background refreshes
  now retry quietly; the message shows only when sending an interest
  cannot be checked.

Before inviting the 12 closed testers:

- Testers who are not license testers pay real money for Premium. Either
  add all 12 to License testing (test card) or tell them in the invite.
- Complete the Google Payments identity verification (BillDesk email) and
  add a payout bank account; without them Google holds payouts.
- Done 8 Nov: the QA report against Khatun was dismissed through the admin
  queue (audited `report_dismissed`).

### 8 November follow-up (remaining device QA items)

Builds: 44048 on the OnePlus (f4c62d1); 46048 on the Android 9 emulator
with this run's fixes. Details in `device-qa.md`, run of 8 November.

| Item | Result |
|---|---|
| Profile ⋮ → Block on device, both directions | PASS; unblock also works |
| Clean install, no missing-services warning | PASS (emulator) |
| Offline cold start, then reconnect keeps the session | PASS (emulator) |
| `https://silarah.com/auth/...` app link | PASS (domain verified, opens the app) |
| Unfinished OTP sign-up resumes; replaced code rejected | PASS (owner typed the codes); time-expired code not waited out |
| Discovery scopes and filters | PASS on the server; outside-India controls hidden |
| Interest limits, reset and Premium prompt | PASS |
| Multiple photos swipe, owner and viewer | PASS |
| Chat translation | N/A, retired |
| Photo-review evidence and 48-hour limit | PASS by server review (no live submission yet) |
| Pause, suspend and appeal UI | PASS after fixing Discover for restricted members |
| Idle network and image refetching | PASS after fixing a Profile retry loop |
| 15-minute session | No ANR, crash, kill or memory growth (2 GB emulator); frame timing not instrumented |
| Android 8 | NOT RUN (owner skipped the 981 MB image) |
| QA report against Khatun | DONE, dismissed and audited |

## Automated and repository gates

- [x] `flutter analyze` has zero findings.
- [x] CI-equivalent Flutter suite passes (453 tests on 31 August 2026).
- [x] Admin lint, typecheck, Next.js build, OpenNext Cloudflare build and
      production dependency audit pass.
- [x] Supabase migration validation and Edge Function tests pass.
- [x] Secret scan passes; no production secrets or signing material are tracked.
- [x] Release-signed APK smoke test updates and launches on the OnePlus without
      Flutter plugin-registration, Firebase Messaging, App Check or Shared
      Preferences startup errors (ABI-split local test build `34029`; not a
      store artifact). Offline cold start and automatic online recovery pass.
- [x] Release AAB built with the upload certificate (42047, 7 Nov).
- [x] Size (112.7 MB) and upload-key signature checked for 42047.
- [ ] Source is committed, pushed and tagged from a clean worktree.

## External configuration that can be completed before Play purchase

- [x] Upload SHA-1/SHA-256 are registered on the Firebase Android app.
- [ ] Register the final Play app-signing SHA-256 for Play Integrity, confirm
      App Check metrics with the exact release candidate, then enable enforcement
      for supported Firebase products after monitoring valid-token traffic.
- [x] `/.well-known/assetlinks.json` contains the upload certificate until Play
      App Signing provides the production app-signing certificate.
- [x] Support, safety, privacy and grievance addresses receive transactional mail.
- [x] Crashlytics symbols uploaded with the 42047 build; a controlled
      non-fatal from the 42047 source reached Firebase on 7 Nov.
- [x] RevenueCat Test Store exposes the current monthly and three-month packages;
      Android purchase, restore, cancellation, forced failure and accelerated
      renewal/expiry pass. Production webhook state remains a Play sandbox/staging
      gate.
- [x] Legal pages, deletion URL, sitemap and canonical domain are live.
- [x] Production and staging migration history match local source through migration 254;
      Security Advisor categories are classified in
      `release/supabase-security-signoff.md`.
- [x] Fresh version 2 post-254 production app-owned backup has passed checksums,
      archive-catalogue and snapshot-inventory checks.
- [x] Production app-owned data restored into a uniquely named staging-side
      ephemeral database; all 84 table counts matched and cleanup succeeded.
- [ ] Capture refreshed post-254 Security/Performance Advisor dashboard totals;
      direct ACL, ownership, cache, blocking and long-query checks are recorded.
- [x] Reconcile Data safety and public processor wording against the final
      Brevo email and Firebase architecture.
- [ ] Device QA checklist is signed off.

## Requires the Google Play developer account

- [x] Create the Play app with package `com.silarah.app`.
- [ ] Google Payments merchant profile: 7 Nov check found both payments
      accounts flagged "Issue with account", a critical alert "Verify your
      identity" (BillDesk PA-CB verification email to imranahmed8341@gmail.com,
      status In progress), no payout bank account under Payment methods and
      no tax section shown. Owner action; does not block test purchases but
      Google will not pay out until done.
- [x] Enrol in Play App Signing and save the app-signing SHA-1/SHA-256
      (SHA-1 `45aa2bee3fdcb5ef78f84ef89c0a3e58a7dbd5b5`, SHA-256
      `14e804148c62926d54d00024f97374cbfb4c6bd122e8c7dc6375539d7f7fe50c`).
- [x] Replace/add the Play app-signing SHA-256 in Digital Asset Links and Firebase
      (2026-10-24: live assetlinks lists both keys and Android verifies
      silarah.com; both Play SHAs registered on the Firebase Android app).
- [x] `silarah_monthly` and `silarah_three_month` base plans live at INR 299 /
      INR 749 (prices load in the app, 7 Nov).
- [x] Products imported into RevenueCat and attached to the entitlement and
      current offering.
- [ ] Complete App content: Data safety, content rating, target audience, ads,
      account deletion, privacy policy and reviewer access.
- [ ] Capture the final-build screenshots and upload them with the
      signed AAB to internal/closed testing. Do not upload the current AAB.
- [ ] For a new personal account, complete Google’s required closed-test eligibility
      process before requesting production access.

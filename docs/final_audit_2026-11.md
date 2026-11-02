# Silarah final pre-launch audit — November 2026

Date: 2 November 2026. Branch `release/42045`, starting at `3fe74ce`.

This audit builds on three earlier reviews and does not repeat them:
`docs/security_audit_2026-10.md` (migration 280), the payments review
(b04b0f6, 98c9ff5, ee3a2f1; migrations 286–287) and the launch-readiness
review (e73d8dc, 5768dc6).

## What was checked

**Changes since those reviews**

- Migrations 279–287. Production `schema_migrations` lists every one, and the
  online-count rewrite (284) is live in both the snapshot and health jobs.
- `get_discovery_feed_page` (282). It is SECURITY INVOKER, so the inner
  feed and revision functions keep their own caller and Premium checks.
- Free-plan limits, alerts and the staff alert email (283, `staff-alert-email`).
  The worker checks the vault cron secret, the queue is service-role only,
  and an alert emails staff once when it fires. Production queue: 1 email,
  sent, nothing stuck.
- Live online count (284). Staff-only, and it runs only while the dashboard
  is open and visible.
- Startup account snapshot (`my_account_snapshot.dart`, `auth_cubit`). Reads
  are keyed by member. Any write clears them after the server answers, and a
  read in flight across a write is not cached.
- Edge-function region pinning. Every invoke passes
  `SupabaseService.functionsRegion`, and all four local build configs set
  `ap-northeast-1`.
- Photo viewer rewrite (`profile_detail_screen.dart`) and the admin System
  page and cockpit.
- Admin Android shell. It stays on admin.silarah.com, blocks screenshots,
  has no backup or cleartext traffic, and adds no credentials of its own.

**Fresh pass, production `jukpscfxzwttgtxvrbmj` (read-only)**

- Grants and RLS on every public table and view.
- Every function members (`authenticated`) or signed-out visitors (`anon`) can
  run, including all SECURITY DEFINER functions that return other members'
  data.
- Storage buckets and policies, and the deployed edge functions with their
  JWT settings.
- Server state machines: interests, matches, blocking, reporting, photo
  requests, account deletion and restore. Unique indexes stop duplicate
  interests, matches, reports and blocks.
- Supabase security advisor. Nothing new: only the accepted PostGIS items and
  leaked-password protection.

**Fresh pass, app**

- Double taps on every action that writes.
- Error paths for already-handled interests.
- Offline and timeout behaviour.
- Unguarded `firstWhere` and `.first` on server rows. All are guarded.

## Findings

| # | Severity | What was wrong (plain words) | Where | Status |
|---|---|---|---|---|
| 1 | Medium | After you block someone, they could still read your full profile (bio, job, education, last active time). Routes: your old match (a block marks it "blocked" but keeps it), a bookmark, today's view, and an explicit "they blocked me" rule. Migration 280 fixed this for photos only. | `get_authorized_member_profiles` | Fixed in `288`. Verified on staging, applied to production 2 Nov with your approval. |
| 2 | Low | Same gap with less data. A blocked member could still see your verification and guardian badges, and your photo privacy setting and photo count. Your partner preferences (sect, deen, education) could be read by anyone with your profile id, even after a block or with Premium incognito on. | `get_member_trust_summaries`, `get_photo_access_context`, `get_discovery_compatibility_preferences` | Fixed in `288`. Verified on staging, applied to production 2 Nov with your approval. |
| 3 | Low | When the server said the interest already exists (`interest_already_active`) or you are already matched (`already_matched`), the app checked for a different message. A stale "Send interest" button therefore kept failing and the screen never refreshed. | `InterestsCubit.sendInterest` | Fixed. The screen now reloads. |
| 4 | Low | Double taps sent duplicate interests. On "Who viewed me", a double tap on Send interest made two requests: the second was rejected and showed "Interest could not be sent" right after a successful send. Profile detail could stack two note sheets. | `profile_views_screen.dart`, `profile_detail_screen.dart` | Fixed. One send per member at a time (cubit), plus guards on both screens. |
| 5 | Low | Answering an interest already handled on another device showed "could not be accepted" and left the old card on screen. | accept, decline and withdraw in `InterestsCubit` | Fixed. The list reloads, and accepting counts as done when the match exists. |
| 6 | Low | Supabase requests had no time limit. On a stalled mobile connection (captive portal, switching networks), a spinner could stay up for many minutes until Android gave up on the socket. Only 7 calls in the app had their own timeout. | `SupabaseService` HTTP client | Fixed. One central limit: 30 s for reads and RPCs, 60 s for edge functions, 120 s for photo uploads. A timeout uses the same error path as a dropped connection. |
| 7 | Low | Delete account: a double tap on the final button sent two requests and signed out twice. With no spinner or timeout, it could look frozen on a slow connection. | `delete_account_screen.dart` | Fixed. One request, a spinner, and a 20 s limit. |

Regression tests: `test/final_audit_2026_11_test.dart`. Both interest tests
fail on the old code. `flutter analyze` is clean, and the full suite passes
(731 tests).

### Staging verification of 288 (rolled-back transactions)

- **Before the fix.** A blocks B; B still gets A's profile (1 row).
- **After the fix.** With the same block:
  - B gets no profile (0), no trust badges (0) and no preferences (0).
  - B's photo-access check returns the normal "Profile is unavailable."
  - A still sees B, which the blocked-members list needs.
  - Each member still sees their own profile.
- **Control, no block.** An earlier closed match still gives B the badges, the
  preferences and the photo context (1 each). The fix closes only the blocked
  case.
- The four function definitions were byte-identical on staging and production
  before the change.

### Production (approved and done, 2 November)

- Migration `288` was applied to production, and `schema_migrations` lists
  it as version 288. On staging and production, all four functions have the
  same definition fingerprint and the same grants: `authenticated` and
  `service_role` only.
- A read-only check as a real member, rolled back, confirmed that their own
  profile, trust badges and photo-access context still load. Their own
  partner preferences are excluded, as designed.

## Informational (no change made)

- **Staff alert email recipients.** All active staff go in one "To" line, so
  staff see each other's addresses. This is internal and acceptable; switch
  to one email each if the team grows.
- **Restoring an account.** Signing in within 30 days restores the account,
  but the profile stays paused, because deleting paused it. The member sees
  the paused banner with a Resume button. This looks deliberate.
- **Default table grants.** `anon` and `authenticated` keep Supabase's default
  table privileges, including TRUNCATE. RLS blocks every row operation, and
  PostgREST cannot issue TRUNCATE, so members cannot use them.
- **Retired function folders.** `verify-firebase-phone`, `digilocker-verify`,
  `process-kyc`, `purge-kyc-documents` and `translate-message` are still in
  `supabase/functions/`. Only `translate-message` is deployed, and it returns
  410. Deleting the folders is a tidy-up for after launch.

## Checked and found fine

- **Tables.** Every public table has RLS except PostGIS `spatial_ref_sys`
  (accepted). Members cannot read `profiles` directly. `users` and
  `my_profile_private` return only the caller's own row. Write grants without
  a matching policy are blocked by RLS.
- **Functions.** Every admin function checks `is_active_admin`, and every
  worker function checks `service_role`. Only three functions are open to
  signed-out visitors: sign-up consent and the referral check, both
  rate-limited.
- **Storage.** Two private buckets, JPEG only, 2 MB limit, no member storage
  policies. All access goes through the checked edge functions.
- **Edge functions.**
  - User-facing functions require a JWT.
  - Workers check the cron secret.
  - The RevenueCat webhook checks its secret.
  - `staff-alert-email` (new) checks the cron secret.
- **Server state machines.**
  - **Interests and matches.** Interests are pair-locked and unique while
    pending or accepted. Matches are created by a locked trigger that
    rechecks blocks and reports.
  - **Blocks.** A block closes the match and removes pending interests.
  - **Account deletion.** It hides the profile and expires pending interests.
    Restoring is refused once the purge has started.
  - **Photo requests.** They are idempotent and honour blocks.

## Needs you

Nothing new in the Supabase dashboard or Play Console. Leaked-password
protection stays off because it needs the paid plan (accepted). The app
fixes reach members with the next build you upload to Play.

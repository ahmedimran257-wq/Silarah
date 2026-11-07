# Physical-device release QA

Record device model, Android version, app version, tester, date and evidence for
each run. Test the signed release build—not a debug build.

## Run of 7 November 2026

Devices: OnePlus 8 (IN2011, Android 13) with release `1.0.0 (44047)`
(arm64 split of 42047), and an Android 9 (API 28, google_apis x86_64)
emulator with `1.0.0 (46047)`. Production backend. Accounts: Khatun
(ahmedimran257, license tester), Abdul (imranahmed8341w) and a throwaway
`ahmedimran257+qa1107` ("Qatest", male), deleted at the end of the run.

Known emulator limits: no Play Store, so the paywall shows "Plans couldn't
load"; its IPv6 is broken, so requests stalled for 30 s until IPv6 was
turned off inside the emulator.

## Installation and startup

- [ ] Clean install launches without a missing-services warning.
- [x] Existing signed-in session returns to the correct profile after restart (7 Nov).
- [ ] Offline cold start shows the offline experience and, after reconnecting,
      restores the existing session instead of routing to sign-up.
- [x] Upgrade from the previous installed build preserves auth and user data
      (44046 to 44047 on the OnePlus, 7 Nov).
- [ ] App links from `https://silarah.com/...` open the expected in-app route.

## Account and onboarding

- [x] Sign-up sends exactly one email containing one usable OTP (7 Nov).
- [ ] An unfinished OTP sign-up can resume without an “already exists” dead end.
- [ ] Sign-in sends exactly one OTP (PASS 7 Nov: one recovery request per
      sign-in in auth logs); expired/replaced code not re-tested.
- [x] All five onboarding steps save and resume correctly (force-stop at
      step 3 resumed at step 3 with the city kept; all fields in the DB, 7 Nov).
- [x] A photo uploads; a faceless image shows "Is this a photo of you?" and,
      if kept, is saved with moderation pending (7 Nov). Explicit fixture not
      re-tested.

## Core product

- [ ] Discovery returns eligible same-city and India-wide profiles.
- [ ] Same city, same state, explicit state/city, radius and View all India
      filters return only authoritative matches; outside-India controls remain
      unavailable in this release.
- [ ] Filter and bottom-tab transitions remain smooth under repeated use.
- [ ] Interest limits, reset time and premium prompt match server entitlements.
- [x] Interest arrives live (badge 1 + push), accept shows "Mabrook", chat
      opens; messages arrive live with an in-app banner and unread count 2 on
      the other device (7 Nov). Men without Premium see the messaging gate by
      design, so the reply direction needs a Premium man (last run 26 Oct).
- [ ] Translation changes only the chosen message and handles provider failure.
- [ ] Multiple profile photos swipe for owner and authorized viewers.
- [x] Photo privacy is enforced on the server: with "after mutual interest",
      the unmatched member got 0 photo paths and a matched member got 3; after
      the match, 3 (7 Nov).
- [x] Notification insert appears live as a badge/banner; FCM push arrives
      in the background on Android 9 and opens the chat route (7 Nov). The
      grey status-bar icon is fixed in 42048.

## Safety, billing and lifecycle

- [ ] Report and block (7 Nov): report works and hides the profile; block
      from chat works both ways (match blocked, photos 0 both ways). Block from
      the profile menu did nothing (fixed in 42048, needs a device re-check).
      Pause/suspend/appeals not re-tested.
- [ ] Human profile-photo review exposes only the temporary look/smile/blink
      evidence required for a reviewer decision and enforces the 48-hour limit.
- [x] Play test-card purchase, renewal, cancellation and expiry update the
      app and Supabase exactly once; restore on sign-in keeps Premium (7 Nov,
      see `revenuecat-qa.md`).
- [x] Transactional email is sent once per event (renewal, cancellation,
      expiry, 7 Nov).
- [x] A controlled non-fatal (`uncaught:network_unreachable`) from the 42047
      source appears in Crashlytics; 0 crashes in 24 h; symbols uploaded with
      the AAB (7 Nov). A test crash was not forced.
- [x] Delete account schedules deletion (`pending_deletion`), signs out and
      shows the 30-day recovery window (7 Nov).

## Performance and data cost

- [ ] No unexpected repeated network calls while idle on each main tab.
- [ ] Images load from cached/signed URLs without unbounded refetching.
- [ ] A 15-minute navigation/chat/photo session has no ANR, memory kill or visible
      sustained jank in Android Studio profiler.
- [ ] Android 9 (API 28 emulator) and Android 13 (OnePlus) pass (7 Nov).
      Android 8 and a low-memory physical device are still to do before
      production.

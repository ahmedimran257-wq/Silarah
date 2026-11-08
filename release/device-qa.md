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

## Run of 8 November 2026

Devices: the OnePlus 8 with `1.0.0 (44048)` (f4c62d1) and the Android 9
emulator (2 GB RAM, the low-memory stand-in) with `1.0.0 (46048)` built
from f4c62d1 plus this run's fixes. Production backend. Accounts: Khatun
and a throwaway `ahmedimran257+qa1108` ("Qatest One", male), deleted
(`pending_deletion`) at the end. The owner typed every sign-in code.

Fixed in this run (in the next build):

- A suspended, banned or deactivated member kept seeing Discover cards
  cached from before the restriction, with a Send Interest button that did
  nothing visible (the server returns no profiles and refuses the interest).
  Discover now shows "Discovery unavailable" and reloads once the
  restriction is lifted.
- Settings showed "Blocked Profiles · None" after a restart while a member
  was blocked, until the block list screen was opened.
- The profile-refresh retry added on 7 Nov re-armed every 8 s while the
  refresh kept failing (offline), re-reading seven endpoints each time. It
  now retries once per failure streak; Retry, resume and tab visits still
  refresh.

## Installation and startup

- [x] Clean install launches without a missing-services warning (emulator,
      8 Nov: language picker, no Google Play services prompt).
- [x] Existing signed-in session returns to the correct profile after restart (7 Nov).
- [x] Offline cold start shows the offline experience and, after reconnecting,
      restores the existing session instead of routing to sign-up (emulator,
      8 Nov: "Waiting for a connection", then straight back to Discover).
- [x] Upgrade from the previous installed build preserves auth and user data
      (44046 to 44047 on the OnePlus, 7 Nov; 46048 over 46048 on the
      emulator, 8 Nov).
- [x] App links from `https://silarah.com/...` open the expected in-app route
      (8 Nov). The app claims only `https://silarah.com/auth/...` (sign-in
      callback); Android shows the domain as verified, `assetlinks.json`
      lists the upload and Play keys, and a cold `auth/callback` link opened
      Silarah, ignored the invalid code and kept the session. Profile
      (`/profile/...`) and referral (`/r/...`) links are web pages by design.

## Account and onboarding

- [x] Sign-up sends exactly one email containing one usable OTP (7 Nov).
- [x] An unfinished OTP sign-up can resume without an “already exists” dead end
      (8 Nov: force-stop after the code resumed onboarding; after wiping app
      data, "Create Profile" with the same email sent a new code and
      continued onboarding).
- [x] Sign-in sends exactly one OTP (PASS 7 Nov: one recovery request per
      sign-in in auth logs). Replaced code rejected (8 Nov): after Resend,
      the earlier code returned 403 "token has expired or is invalid" and
      the newest code signed in. A time-expired code was not waited out.
- [x] All five onboarding steps save and resume correctly (force-stop at
      step 3 resumed at step 3 with the city kept; all fields in the DB, 7 Nov).
- [x] A photo uploads; a faceless image shows "Is this a photo of you?" and,
      if kept, is saved with moderation pending (7 Nov). Explicit fixture not
      re-tested.

## Core product

- [x] Discovery returns eligible same-city and India-wide profiles (8 Nov,
      server as Khatun: Abdul, Kurnool, in default, same city, same state,
      All India and radius; production has one eligible profile for her, so
      negative checks carry the weight below).
- [x] Same city, same state, explicit state/city, radius and View all India
      filters return only authoritative matches; outside-India controls remain
      unavailable in this release (8 Nov: Telangana, Hyderabad, UAE and age
      30–35 return 0, Andhra Pradesh, Kurnool, IN and 25–30 return Abdul;
      location filters need Premium on the server (`premium_filter_required`
      for a free member); `get_launch_configuration` is `single_country` IN,
      which hides Browse Countries and Diaspora in the filter sheet).
- [ ] Filter and bottom-tab transitions remain smooth under repeated use
      (no ANR or kill over 15 minutes, see Performance; frame timing not
      instrumented).
- [x] Interest limits, reset time and premium prompt match server entitlements
      (8 Nov: `get_interest_quota` and the insert trigger both use 5 free /
      25 Premium per UTC day, reset 00:00 UTC; the app reads limit and reset
      from the server; "15 profiles remaining" matched
      `get_profile_view_quota`; the paywall says 25 interests per day).
- [x] Interest arrives live (badge 1 + push), accept shows "Mabrook", chat
      opens; messages arrive live with an in-app banner and unread count 2 on
      the other device (7 Nov). Men without Premium see the messaging gate by
      design, so the reply direction needs a Premium man (last run 26 Oct).
- N/A Translation changes only the chosen message and handles provider failure.
      Chat translation is retired: no translate control remains in chat and
      the privacy policy says it is no longer offered (8 Nov).
- [x] Multiple profile photos swipe for owner and authorized viewers (8 Nov:
      Khatun 1/3 to 3/3 on her own profile on the OnePlus; Qatest 1/3 to 3/3
      on Khatun's profile on the emulator).
- [x] Photo privacy is enforced on the server: with "after mutual interest",
      the unmatched member got 0 photo paths and a matched member got 3; after
      the match, 3 (7 Nov).
- [x] Notification insert appears live as a badge/banner; FCM push arrives
      in the background on Android 9 and opens the chat route (7 Nov). The
      grey status-bar icon is fixed in 42048.

## Safety, billing and lifecycle

- [x] Report and block (7 Nov): report works and hides the profile; block
      from chat works both ways (match blocked, photos 0 both ways). Block from
      the profile menu (8 Nov, 46048): confirm dialog, "Khatun blocked.",
      profile closed, Khatun gone from Qatest's Discover; Qatest gone from
      Khatun's feed (present again only with the block removed in a
      rolled-back transaction). Unblock from Blocked Profiles works and the
      count is fixed (see above).
- [x] Pause, suspend and appeal standing UI (8 Nov): Settings → Profile pause
      shows "Profile paused" on Profile and a Resume banner on Discover;
      Resume makes the profile visible. An admin suspension (audited
      `account_suspend`) shows "Profile suspended" with Get help / Contact
      support (the appeal route to Help & Support); the server returns no
      profiles and refuses interests; Discover shows "Discovery unavailable"
      (fixed this run). Restore (audited `account_restore`) reloads Discover.
- [x] Human profile-photo review exposes only the temporary look/smile/blink
      evidence required for a reviewer decision and enforces the 48-hour limit
      (8 Nov, server review; no live submission in production yet): the
      staff-only queue returns the main photo plus the neutral, smile and
      blink captures, only while pending and before the deadline; the
      deadline is submission + 48 h; captures are purged 10 minutes before it
      or right after a decision; decisions after the deadline are refused;
      the purge job ran 288/288 times in 24 h.
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

- [x] No unexpected repeated network calls while idle on each main tab
      (8 Nov, emulator, 60 s idle each: Discover 6 KB, Interests 0.6 KB,
      Chat 0.2 KB, Profile 3.8 KB per minute after it settles). The Profile
      retry loop found here is fixed.
- [x] Images load from cached/signed URLs without unbounded refetching
      (8 Nov: one photo-URL signing per 5 minutes across a 15-minute
      navigation session).
- [ ] A 15-minute navigation/chat/photo session has no ANR, memory kill or visible
      sustained jank in Android Studio profiler. 8 Nov, 2 GB emulator,
      22 loops of tabs, Discover photo carousel, list scrolling and
      Settings: same process throughout, PSS 134–143 MB with no growth, no
      ANR, crash or low-memory kill. Frame timing needs a profile build with
      DevTools (`gfxinfo` does not see Flutter frames); the OnePlus was in
      use, so the chat part was not scripted there.
- [x] Android 9 (API 28 emulator) and Android 13 (OnePlus) pass (7 and 8 Nov).
      Low-memory stand-in: the 2 GB emulator above. Android 8 (API 26) not
      tested: the owner chose not to download its 981 MB system image.

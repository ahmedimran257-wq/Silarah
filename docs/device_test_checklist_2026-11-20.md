# Device test checklist — 20 Nov 2026

Release APK (arm64 split, `tool/install_android.ps1 -Mode release`, no `SILARAH_PERF_LOG`),
OnePlus phone `d2e084e7` (Android, 1080×2400), production backend `jukpscfxzwttgtxvrbmj`,
branch `release/42045`.

Inventory source: `lib/core/router/app_router.dart` (24 routes), `lib/features/home/screens/*`
(27 screens), `lib/features/onboarding/screens/*` (9), `lib/features/verification/*`,
`lib/core/cubits/*` (12 cubits), `lib/core/services/*` (41 services), server rules in
`supabase/migrations/129, 208, 225, 289, 307, 311, 313–317`.

Status: PASS / FAIL / FIXED (failed, fixed, re-verified on the phone) / NOT RUN (reason).
Evidence: screenshots in `release/device-qa-2026-11-20/` (local only, 46 MB, not committed)
or a server/SQL line. Test accounts: Abdul (`0b9630d4…`, free man, temporary test Premium
grants revoked after use), Qatest Woman (`607217c8…`), Qatest Second (`5843c1c7…`),
Qatest Man (`c4f0c148…`) — all `ahmedimran257+qa1120…@gmail.com` fixtures created for this run.

## A. Install, launch, onboarding, auth
| # | Item | Status | Evidence |
|---|---|---|---|
| A1 | Release APK builds and installs over 42053 without wiping data; no `[perf]` | PASS | build log "Silarah installed successfully", versionCode 44053, session kept; config has no PERF key |
| A2 | Cold launch → boot routes to the right screen | PASS | a2_launch.png (signed-in Discover after cold start; force-stop relaunch → Home) |
| A3 | Language selection | PASS | a3_language.png (10 languages, Continue) |
| A4 | Legal gate consent | PASS | Continue does nothing until all three are ticked; a4_consents_checked.png |
| A5 | Email validation, consent-bound code | FIXED | invalid and disposable addresses refused; a repeated identical error showed nothing (bug #15) → fixed, 3/3 attempts now show it; code sent a6_code_screen.png |
| A6 | Email code | PASS | wrong code: "This verification code is invalid or has expired" (a6_wrong_code_rejected.png); owner typed the real code |
| A7–A11 | Onboarding (for whom, location, identity, Islamic identity, photo) | PASS | a7_after_myself.png → a11_after_onboarding.png; email in first name refused by the server with the new message (a8_email_name_result.png); photo published |
| A12 | Steps, back, resume after kill | PASS | "Step n of 5"; Back returns a step; force-stop on step 5 resumed on step 5 |
| A13 | Sign out | PASS | a13_signed_out.png |
| A14 | Sign back in | PASS | a14_signed_in.png (new account), Abdul restored |

## B. Discover
| # | Item | Status | Evidence |
|---|---|---|---|
| B1 | Feed shows the opposite gender only | PASS | a2_launch.png, b2_swipe1.png (man sees only women); woman→woman interest refused (`profile_unavailable`) |
| B2 | Swipe, card carousel photos | PASS | b2_swipe1.png, c1_photo_viewer.png (1/4 → 3/4) |
| B3 | Send interest with note; note safety | PASS | b3_interest_sheet.png, b3_interest_sent.png; email in note blocked in-app; phone in note `interest_note_blocked` |
| B4 | Bookmark | PASS | profile Save → "Saved"; My Profile Saved profiles shows Qatest (b10_boost.png) |
| B5 | Free daily limit (15) → paywall | PASS | b5_limit.png "0 profiles remaining · Daily limit reached · Upgrade Now" |
| B6 | Viewed profiles gallery | PASS | b6_viewed.png |
| B7 | Filters (age, sect, deen, location India state/city, Premium locks) | FIXED | b7_shia_results.png showed raw "shia" chip → fixed (`discoveryFacetLabel`); city filter b7_city_results.png; free locks b7_filters_free.png |
| B8 | Filter presets (several with Premium; free → paywall) | PASS | b8_two_presets.png, b8_free_preset_result.png |
| B9 | Empty state | PASS | b7_shia_results.png |
| B10 | Profile boost (Premium) / locked for free man | PASS | b10_boost.png (2 h countdown); free: "Subscribe to unlock profile boosts." |
| B11 | Incognito (Premium) / locked for free | PASS | b11_incognito_on.png + `premium_privacy_settings.incognito_requested=true`; b11_incognito_free.png |

## C. Profile detail
| # | Item | Status | Evidence |
|---|---|---|---|
| C1 | Details, photos, compatibility | PASS | c1_profile_review.png, c1_qatest2.png (100% compatibility as Premium) |
| C2 | Surname initial until match + note | PASS | c1_profile_review.png "Review T. · Full surname is shared once you match."; after match chat shows "Qatest Woman" |
| C3 | Photo access request / approve / revoke | PASS | f6_photo_requests.png → f6_shared.png → revoked (`request_status=revoked`) |
| C4 | Private shortlist editor | PASS | c4_shortlist_editor.png, c4_shortlist_saved.png |
| C5 | Share profile | PASS | c5_share.png (no private data in text) |
| C6 | Report / Block menu | PASS | c6_menu.png, c6_report_sheet.png (cancelled — reviewer account); block tested from chat (E4) |


## D. Interests and matches
| # | Item | Status | Evidence |
|---|---|---|---|
| D1 | Received / Sent tabs | PASS | d1_received.png, d3_sent_declined.png |
| D2 | Accept → "Mabrook!" → chat | PASS | d2_accept.png |
| D3 | Decline; 30-day re-send pause | PASS | d3_resend_result.png "You can send another after 30 days."; receiver-side decline d3_decline_dialog.png |
| D4 | Daily quota free 5 / Premium 25 | PASS | d4_free_quota.png "Free · 1 of 5"; d3_sent_declined.png "Premium · 1 of 25" |
| D5 | Rematch cooldown (Abdul ↔ Khatun) | PASS | a2_launch.png "Rematch available in 5 days" (server `rematch_available_at` 24 Nov) |
| D6 | Same-gender interest refused | PASS | API: `profile_unavailable` |

## E. Chat
| # | Item | Status | Evidence |
|---|---|---|---|
| E1 | Inbox, search | PASS | e1_chatlist_free_man.png, e1_search.png |
| E2 | Send/receive; 2000-char cap | PASS | e2_chat_open.png; composer stopped at exactly 2000 chars |
| E3 | Contact details blocked | FIXED | digits/email blocked (e3_phone_blocked.png); spelled-out numbers were delivered (e2_chat_open.png) → migration 318 |
| E4 | Report message, block from chat | FIXED | report closed the match but chat stayed open (e4_msg_reported.png) → reload + closed banner; block e4_blocked.png |
| E5 | Delete chat | PASS | e5_deleted.png |
| E6 | Conversation openers | PASS | e6_openers_woman.png; opener sent, openers hidden |
| E7 | Free man locked → paywall; women message free | PASS | e7_locked_chat_man.png; woman sends via API without Premium |
| E8 | Premium expiring mid-chat | PASS | e8_expiry_midchat.png (send → Premium notice, history hidden) |
| E9 | Failed message retry (network) | NOT RUN | the PC is USB-tethered through the phone, so cutting the network cuts the test link; needs a second network path |
| E10 | Blocked message retry would re-strike | FIXED | e3_phone_blocked.png "Tap to retry" on a refused message → text returns to the composer |
| E11 | Premium granted while app open | FIXED | e2_chat_premium.png / e2_chat_refresh.png wall stayed → inbox re-read on open |

## F. Saved, views, notifications
| # | Item | Status | Evidence |
|---|---|---|---|
| F1 | Shortlist screen | PASS | f1_shortlist.png; free: "Plan privately with Premium" |
| F2 | Saved profiles on My Profile | PASS | b10_boost.png |
| F3 | Who viewed me (Premium list / free gate) | FIXED | f3_views_premium2.png; free gate promised a count but showed none (f3_views_free.png) → count shown |
| F4 | Notifications screen, tap-through | FIXED | f4_notifications.png; guardian message notification opened "Conversation no longer available" (f4_tap_message.png) → migration 319 + routing |
| F5 | Push delivery and tap | PASS | quiet hours respected (08:00 IST), system-tray push opened the Guardian dashboard (f5_push_opens_guardian_dashboard.png) |
| F6 | Photo access requests screen | PASS | f6_photo_requests.png, f6_shared.png |

## G. Premium / paywall
| # | Item | Status | Evidence |
|---|---|---|---|
| G1 | Man's plans screen | PASS | g1_sub_man.png, g1_sub_man_bottom.png |
| G2 | Woman's plans screen | PASS | g2_sub_woman.png "Unlock Premium · You already message free", no messaging line |
| G3 | Play purchase sheet, backed out | PASS | Play sheet "Silarah Premium Monthly ₹299" (test card) dismissed, g3_after_cancel.png |
| G4 | Test Premium card | PASS | h1_profile_top.png "Test Premium is active · 23h 57m" |
| G5 | Premium gates (compatibility, shortlist) | PASS | g5_compat_gate.png |
| G6 | Restore purchase | PASS | "No previous purchases found for this account." |

## H. My Profile, edit, verification
| # | Item | Status | Evidence |
|---|---|---|---|
| H1 | Quality card, standing, presence | PASS | h1_profile_top.png, h1_profile_mid.png |
| H2 | Edit profile; contact-detail refusal; Discard prompt | PASS | h2_bio_phone_save (refused), bio saved, h2_discard.png |
| H3 | Photos add / remove | PASS | h3_uploaded.png (published instantly, review pending); removal → `deletion_pending` |
| H3b | Reorder / make main | FIXED (copy) | copy promised "Reorder"; no such feature exists — copy corrected; feature is an owner decision |
| H4 | Selfie photo verification | NOT RUN | screen h4_verify.png reached; needs camera permission and the owner's live face |
| H5 | Pause / resume profile | PASS | h5_paused_discover.png; `visibility` paused → visible |

## I. Settings
| # | Item | Status | Evidence |
|---|---|---|---|
| I1 | Notification toggles, digest, quiet hours | PASS | `notification_prefs.boost_available` false → true; i1_digest.png, i1_quiet.png |
| I2 | Themes: Rose, Ivory, OLED, Automatic | PASS | i2_rose_montage.png, i2_ivory_montage.png, i2_automatic_nightphone.png |
| I3 | 10 languages, RTL ar/ur | FIXED | i3_*_montage.png; wrong words fixed (see report); RTL name punctuation fixed |
| I4 | Photo privacy | PASS | i4_photo_request.png; `photo_privacy` request_only → public |
| I5 | Blocked list / unblock; report history | FIXED | i5_blocked.png, i5_unblocked.png; message reports missing and status always "Pending" → fixed (fix6_report_status.png: Pending / Reviewed) |
| I6 | Download my data | PASS | i6_export.png → ZIP `silarah-data-export-2026-11-20.zip`; second request `export_rate_limited_24_hours` |
| I7 | Privacy requests | PASS | i7_submitted.png (reference + response date) |
| I8 | Help Center, guide, grievance | PASS | i8_help.png, k7_guide.png, i8_grievance.png |
| I9 | Legal documents (10) | PASS | all 10 opened with titles |
| I10 | Version | PASS | 1.0.0 (44053) |
| I11 | Delete account | PASS | i11_delete_screen.png → reason → DELETE; server `pending_deletion`, profile paused |

## J. Guardian / Wali
| # | Item | Status | Evidence |
|---|---|---|---|
| J1 | Guardian mode, invite code | PASS | j1_guardian_on.png, j1_invitation.png; accepted via API (`member_guardian`) |
| J2 | Accept invitation in app | FIXED | accepted (DB), but member landed on dashboard with no way back; Back exited the app → back route added |
| J3 | Dashboard + read-only transcript | PASS | j3_dashboard_live.png, j3_transcript.png |

## K. Other
| # | Item | Status | Evidence |
|---|---|---|---|
| K1 | Referral code copy / share | PASS | k1_referral.png |
| K2 | Offline banner, cached content, reconnect | PASS | k2_offline_chat.png, k2_offline_discover.png, k2_reconnected.png |
| K3 | Poor network | NOT RUN | the PC is USB-tethered through the phone; throttling the phone cuts the test link |
| K4 | Back navigation | PASS | every screen above returned with Back; guardian dashboard fixed (J2) |
| K5 | Rotation | PASS | app is portrait-locked (`SCREEN_ORIENTATION_PORTRAIT`) with auto-rotate on |
| K6 | Shared phone (B after A) | FIXED | new account saw none of Abdul's chats, interests, presets (k6_*.png); but Blocked/Report History stayed empty for 5 min after any sign-in (bug #16) → fixed |
| K7 | Product guide, coach marks | PASS | k7_guide.png |
| K8 | App links (silarah.com/auth) | PASS | `pm get-app-links` verified; link opened app without losing session |

## Findings and fixes

| # | Finding | Fix | Verified on phone |
|---|---|---|---|
| 1 | Spelled-out phone numbers (words, romanised Hindi/Urdu, Arabic/Urdu/Hindi/Bengali script, "double 7") passed chat and interest-note checks | migration 318 `text_has_spelled_phone_number` in `chat_safety_check`; app `ContentFilter` mirrors it | fix1_fix3_refused_draft.png; live API: chat `blocked`, note `interest_note_blocked` |
| 1b | Profile names/profession/bio were checked for contact details only in the app | migration 318 trigger `trg_enforce_profile_public_text`; app maps the refusal to a clear message | a8_email_name_result.png |
| 2 | Server-side Premium grant while the app is open left the chat wall up; "Refresh access" could not clear it | chat re-reads the inbox and entitlement when the server allows a cached-locked chat; no read receipts while locked | fix2_unlocked_without_restart.png, fix2_refresh_access.png |
| 3 | A refused message stayed as "Tap to retry" (retry = another strike) | refused text goes back to the composer; never a retry bubble | fix1_fix3_refused_draft.png |
| 4 | Reporting a message closed the match but the open chat did not change | inbox reload after report; report-specific banner; reported member gets a neutral label | fix4_report_closed_state.png |
| 5 | Filter chip showed "shia" | shared `discoveryFacetLabel` | fix5_chip_label.png |
| 6 | Report History missed message reports and always said "Pending" | message reports listed with reason and real status | fix6_report_status.png |
| 8 | Latin names showed ".Khatun K" in Arabic/Urdu | `UiText` lays out Latin-only text LTR with mirrored alignment | fix8_ar_montage.png |
| 9 | Copy promised photo reordering that does not exist | copy corrected in 10 languages | fix9_photo_copy.png |
| 10 | Wrong translations ("Practicing" ×8, Report History ×4, Malay "jantan"/"sendi"/"wad"/lower case, Turkish "İlgi alanları", Hindi "संदेशों") | ARB + catalog corrections | fix10_ms_settings.png |
| 11 | A member who accepted a Guardian invitation could not get back to their Home (Back closed the app) | dashboard back route for members | fix11_dashboard_after_accept.png, fix11_back_to_member_home.png |
| 13 | Guardian message notifications opened "Conversation no longer available" | migration 319 link → Guardian dashboard; app routes the type | f5_push_opens_guardian_dashboard.png |
| 14 | Free Profile Views promised a weekly count but showed none | count shown (0 / 1 / n wording) | fix14_free_views_count.png |
| 15 | Repeating the same sign-in error showed nothing the second time | every error attempt is a new state | 3/3 attempts showed the disposable-address error |
| 16 | Blocked Profiles and Report History stayed empty for 5 minutes after any sign-in | freshness tied to the loaded account; cleared on sign-out | fix16_reload_after_signin.png (fast path by unit test) |

Not fixed, needs the owner:
- Photo reorder / choose main photo does not exist; building it needs a decision on the "Photo verified" badge when the main photo changes.
- H4 selfie verification needs camera permission and a live face.
- E9 and K3 need a network that is not the phone's own tether.
- All nine translations are machine-made; Malay, Turkish and Hindi need a native review first.

---

# Second list — 21 Nov 2026

Devices: OnePlus `d2e084e7` (Abdul), Redmi Note 4 `427bc4f00903` (Android 10, 1080×1920,
Neha `6949307d…`; for the large-text pass its display was set to the default 360 dp width and
Android's "Largest" text, 1.3, then restored to the owner's 0.95 text / 378 density), and
briefly an emulator `qa_small` (Android 15, 320×533 dp, text 200%; dropped after it crashed
twice on this PC's RAM). Evidence in `release/device-qa-2026-11-21/` (local only).

| # | Check | Status | Evidence / note |
|---|---|---|---|
| L1 | Crashlytics, Play vitals, pre-launch, tester feedback | PASS | 90-day crash issues all from builds ≤44046 (last event 2 Nov), each already fixed in code; 7-day crash-free users 100%; Play vitals 0 crashes / 0 ANRs in 28 days; no tester feedback; no pre-launch report generated. Play warnings (SafetyNet via `firebase_app_check` 0.3.x, deprecated edge-to-edge colour APIs) need library/UI work, not crash fixes |
| L2a | Test purchase (license tester, test card) | PASS | Play sheet "Test card, always approves"; app showed Premium; server `INITIAL_PURCHASE` 04:52 UTC, notification "Silarah Premium is active" |
| L2b | Renewal | PASS | `RENEWAL` 04:57 UTC, expiry moved, "Your membership renewed" |
| L2c | Plan change (monthly ↔ 3 months) | FIXED (app) · server fix pending deploy | In-app "Switch plan" built and tested on the OnePlus with the test card, 21 Nov 12:45–13:06 UTC. Monthly → 3 months: Play charged ₹749 now with the unused monthly time added on (12-min sandbox period); server `PRODUCT_CHANGE` + `INITIAL_PURCHASE`, expiry correct. 3 months → monthly: booked for the renewal, nothing charged; monthly arrived as a `RENEWAL` at 13:01. **Bug:** booking the downgrade cut server Premium (expiry 13:09:48 → 12:59:09) because `PRODUCT_CHANGE` carries the change time as its expiry. Fixed by migration 322 (staging pgTAP 19/19, rolled back), not yet on production. See `release/revenuecat-qa.md` |
| L2d | Cancel and expiry | PASS | Cancelled in Play 05:01; access kept to the period end; `REVOCATION` + `EXPIRATION` 05:02, status `none`, app back to the paywall, "Your Silarah subscription has ended" |
| L2e | Refund | FIXED | First refund (04:57 order) was issued without "Remove entitlement": Google keeps such orders out of its voided-purchase feed, so RevenueCat and Silarah never heard of it (documented behaviour, not a code bug). Second test purchase 06:13, refunded with "Remove entitlement": `REVOCATION` + `EXPIRATION` reached the server in 40 s, status `none`, "subscription has ended" sent; RevenueCat then logged `REFUND` at 08:07. The open app still showed Premium until resumed (#22, fixed). Procedure written into `docs/pre_play_revenuecat_checklist.md` |
| L3 | Two phones chatting live | PASS | delivery 2.7 s / 3.2 s, "Neha is typing", read tick + `status=read`, unread badge; Wi-Fi off on the Redmi → "Message failed. Tap to retry", reconnect in 7 s, retry delivered once |
| L4 | Push: background, killed, after reboot, Guardian link | PASS | killed: push arrived, tap opened the chat; after reboot: arrived in ~9 s without opening the app; background + Guardian dashboard link verified 20 Nov (migration 319) |
| L5 | Upgrade keeping data | PASS | Redmi 42046 → current: Neha still signed in, filters 22–31, unread count, language kept; retired theme falls back to Ivory & Emerald. OnePlus 42053 → current kept Abdul's session |
| L6 | Small screen + largest text | FIXED | welcome, sign-in, referral sheet, Guardian invitation scroll to every button; "Have a referral code?" was cut to "Have a referral" (#18); the consent screen left the checkboxes a ~110 dp strip (#19); the Terms consent line and the code screen's "sent to" line ignored the system text size (#21) |
| L6b | Old Android | PASS (Android 10) | Redmi Note 4 on Android 10 ran every check in this list: upgrade, live chat, push after reboot, idle sign-in and the large-text pass. Android 7–9 (the app's minSdk is 24) was not run: no device and no older emulator image |
| L6c | Largest text on the Redmi (signed in) | FIXED | Discover, Interests, Messages, chat, Profile, Settings, Edit profile, filter sheet and Notifications all scroll and wrap. Found: the Discover header counter collapsed to an empty pill (#23); "Profile quali… · Good pro…" and the profile tips were cut (#24); "1 preferences selected" / "Apply 1 filters" (#25, every text size) |
| L7a | Daily limits reset | FIXED | Views, interests and bookmarks reset at UTC midnight (05:30 IST); owner chose member-local midnight (#26). Migration 321: rolled-back production test, an interest 1 min before IST midnight no longer counts and 1 min after does, `resets_at` = 00:00 IST, views use the local date; Abdul's quota through the app API shows `resets_at` 18:30 UTC (12:00 AM IST) |
| L7b | Premium expiring with the app open | FIXED | card disappeared at expiry, but its "Xm remaining" did not count down (#17) |
| L7c | Long-idle sign-in | PASS | Neha's 19-day-old session sat idle past its 1-hour token; reopening refreshed it (05:25:11) with no sign-out and the feed loaded |
| L7d | Rematch pause (7 days) | PASS | server test one minute either side: `rematch_cooldown` at 7d−1m, interest sent at 7d+1m (rolled back) |
| L7e | Decline pause (30 days) | FIXED | counted from when the interest was sent, so a decline on day 13 paused only 17 days (#20); now counts from the decline: 30d−1m refused, 30d+1m sent (rolled back) |

## Findings and fixes (second list)

| # | Finding | Fix | Verified |
|---|---|---|---|
| 17 | Profile's time-limited Premium banner showed a frozen "Xm remaining" while open | banner reschedules itself just after each shown minute runs out (`premiumCountdownRefreshDelay`) | unit tests; phone |
| 18 | "Have a referral code?" cut off at large text | link texts wrap freely (page scrolls) | emulator, 200% text |
| 19 | Consent screen: fixed title left a tiny scroll strip for the three checkboxes on small phones at large text | title and subtitle scroll with the terms; Back and Continue stay fixed | emulator, 200% text |
| 20 | 30-day decline pause measured from the interest's send time | migration 320: `interests.responded_at` stamped by trigger on every answer path, immutable; `send_interest` measures from it | staging + production, boundary test rolled back |
| 21 | Two texts (Terms consent line, "We sent a code to …") used `RichText`, which ignores the system text size | `Text.rich`; a test fails if `RichText(` returns anywhere in `lib/` | emulator, 200% text |
| 22 | After a refund (or any billing change) the open app kept showing Premium until the next resume; RevenueCat's on-device cache still said active | billing notifications (`subscription_*`) now make the app drop RevenueCat's cache and re-read Premium (`SubscriptionCubit.refreshFromStore`) | phone |
| 23 | Discover header: at large text the wordmark took the whole row and the "15 left" counter ellipsized to an empty pill | the wordmark (logo) keeps its size; the counter scales down as a whole | Redmi, Largest text |
| 24 | Profile card: "Profile quality · Good profile" cut on both halves; tip lines cut to one line | one wrapping line (2 lines max); tips allow 2 lines | Redmi, Largest text |
| 25 | "1 preferences selected" and "Apply 1 filters" | singular wording in English and the 9 translations | Redmi |
| 26 | Daily limits reset at UTC midnight, 05:30 in India | migration 321: `private.member_today` / `member_day_start` from `users.timezone` (validated, UTC fallback) in all 8 limit functions; a member's timezone may change once every 7 days so it cannot be hopped for extra resets | production boundary test (rolled back), app API |

Staging note: staging has a trigger `enforce_member_timezone` that is in no migration and not on production (it rejects invalid zone names and sets Asia/Kolkata for India). Worth reconciling.

## Release candidate 1.0.0+46060 — 21 Nov 2026 (evening)

`release/42045` with the SafetyNet removal, in-app plan switch and edge-to-edge
branches merged (7f22f1e). Analyzer clean, 1,047 tests pass. Server: webhook
and migration 322 on staging and production (19/19 checks, rolled back on
production); migration 309 on production (free member cannot save an unviewed
profile, can after viewing). Phone build: arm64 release APK, versionCode 48060,
installed over 46059 on both phones.

| # | Check | Result | Notes |
|---|---|---|---|
| RC1 | Dark theme (OLED Night), Redmi Android 10 | PASS | light status-bar icons; Settings, Discover, tab bar clear of the bars |
| RC2 | Onboarding signed out, Redmi, dark | PASS | welcome, consent, email, code, and all five profile steps clear the status bar; Continue sits above the bottom edge; mother-tongue sheet clears the status bar. Test account `ahmedimran257+qa1121onb` deleted in-app afterwards (pending_deletion, out of Discover) |
| RC3 | Chat composer, OnePlus 3-button navigation, light | PASS | composer above the transparent nav bar; with the keyboard open it sits directly above the keyboard |
| RC4 | Dark theme, OnePlus 3-button navigation | PASS | light status and nav icons, transparent nav bar, nothing covered |
| RC5 | Android 15+ | NOT TESTED | no device; emulator run planned 22 Nov |

Minor, not new: on the location step with the keyboard open, the city results
box opens above the field and covers the "City" label while results load.

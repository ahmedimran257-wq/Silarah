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
| A3 | Language selection (first run) | PENDING | new-account run |
| A4 | Legal gate consent | PENDING | new-account run |
| A5 | Email screen validation, consent-bound code request | PENDING | new-account run |
| A6 | Email code (OTP) | PENDING | owner types the code |
| A7–A11 | Onboarding steps (for whom, identity, Islamic identity, location, photo) | PENDING | new-account run |
| A12 | Progress bar, back between steps, resume after kill | PENDING | new-account run |
| A13 | Sign out | PENDING | new-account run |
| A14 | Sign back in | PENDING | owner types the code |

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
| C7 | Open chat from a matched profile | PENDING | re-test on new build |

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
| E6 | Conversation openers | PENDING | needs an empty new match |
| E7 | Free man locked → paywall; women message free | PASS | e7_locked_chat_man.png; woman sends via API without Premium |
| E8 | Premium expiring mid-chat | PASS | e8_expiry_midchat.png (send → Premium notice, history hidden) |
| E9 | Failed message retry | PENDING | |
| E10 | Blocked message retry would re-strike | FIXED | e3_phone_blocked.png "Tap to retry" on a refused message → text returns to the composer |
| E11 | Premium granted while app open | FIXED | e2_chat_premium.png / e2_chat_refresh.png wall stayed → inbox re-read on open |

## F. Saved, views, notifications
| # | Item | Status | Evidence |
|---|---|---|---|
| F1 | Shortlist screen | PASS | f1_shortlist.png; free: "Plan privately with Premium" |
| F2 | Saved profiles on My Profile | PASS | b10_boost.png |
| F3 | Who viewed me (Premium list / free gate) | FIXED | f3_views_premium2.png; free gate promised a count but showed none (f3_views_free.png) → count shown |
| F4 | Notifications screen, tap-through | FIXED | f4_notifications.png; guardian message notification opened "Conversation no longer available" (f4_tap_message.png) → migration 319 + routing |
| F5 | Push delivery | PASS | interest push held for quiet hours (`scheduled_at` 08:00 IST), later `delivery_status=sent` |
| F6 | Photo access requests screen | PASS | f6_photo_requests.png, f6_shared.png |

## G. Premium / paywall
| # | Item | Status | Evidence |
|---|---|---|---|
| G1 | Man's plans screen | PASS | g1_sub_man.png, g1_sub_man_bottom.png |
| G2 | Woman's plans screen | PENDING | new woman account |
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
| I5 | Blocked list / unblock; report history | FIXED | i5_blocked.png, i5_unblocked.png; message reports missing from history → added |
| I6 | Download my data | PASS | i6_export.png → ZIP `silarah-data-export-2026-11-20.zip`; second request `export_rate_limited_24_hours` |
| I7 | Privacy requests | PASS | i7_submitted.png (reference + response date) |
| I8 | Help Center, guide, grievance | PASS | i8_help.png, k7_guide.png, i8_grievance.png |
| I9 | Legal documents (10) | PASS | all 10 opened with titles |
| I10 | Version | PASS | 1.0.0 (44053) |
| I11 | Delete account | PENDING | new test account |

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
| K6 | Shared phone (B after A) | PENDING | new-account run |
| K7 | Product guide, coach marks | PASS | k7_guide.png |
| K8 | App links (silarah.com/auth) | PASS | `pm get-app-links` verified; link opened app without losing session |

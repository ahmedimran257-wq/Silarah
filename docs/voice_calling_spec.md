# Voice calling — spec (Stream Video)

Status: approved plan, 22 Nov 2026. Not built. Ships behind a server switch that stays OFF until every
staging gate in section 9 passes.

## 1. Goal and money rule

In-app voice calls between matched members, paid for by Premium and minute packs, so members never need
to swap phone numbers and calling can never lose money. Provider: Stream Video (getstream.io), custom
call type `silarah_voice`, audio only.

Cost basis (verified 22 Nov 2026):
- Stream audio: $0.30 per 1,000 participant minutes; a 2-person call minute = $0.0006 ≈ ₹0.054
  (+18% GST ≈ ₹0.064). **Planning cost: ₹0.08 per call minute.**
- Free: $100 of Audio/Video usage every month (≈166,000 two-person call minutes).
- Ringing is not billed: a ring call has no session until the callee accepts (and we only create the
  Stream call at accept, see 4).
- Play keeps ~28% (18% GST + 15% fee): we keep ≈ 72% of the price. Break-even ≈ ₹0.11/min.

## 2. Access rules

| | Start a call | Answer | Included minutes | Packs |
|---|---|---|---|---|
| Man, free | No → Premium paywall | No: not rung; sees missed call → paywall | none | No |
| Woman, free | No → Premium paywall | Yes, free | none | No |
| Man or woman, Premium | Yes | Yes | 30 per Premium month | Yes |

- Calls only between members with an active match who have not blocked each other.
- The man on the call must have Premium at all times (`has_active_premium`, grace counts). If the caller
  or the male callee loses Premium mid-call, the server ends the call.
- Only the caller's minutes are used. Answering is always free.
- Included minutes: 30 every 30 days counted from the member's Premium start (annual and 3-month plans
  get 30 per 30-day period). Not rolled over. Used before pack minutes.
- Pack minutes never expire, but can only be used while Premium is active (stated before purchase:
  "Calls need an active Premium plan").

## 3. Packs (Google Play consumables, Premium members only)

| Product ID | Price (IN) | Minutes | ₹/min | We keep | Stream cost |
|---|---|---|---|---|---|
| `silarah_calls_20` | ₹19 | 20 | 0.95 | ₹13.70 | ₹1.60 |
| `silarah_calls_60` | ₹49 | 60 | 0.82 | ₹35.30 | ₹4.80 |
| `silarah_calls_150` | ₹99 | 150 | 0.66 | ₹71.30 | ₹12.00 |
| `silarah_calls_350` | ₹199 | 350 | 0.57 | ₹143.30 | ₹28.00 |

Floor: no country priced below the equivalent of ₹0.40/min (Play local prices checked per country).

## 4. Call flow (our server owns ringing)

We ring with Silarah's own FCM, not Stream ringing or Stream push. Reasons: Stream's ringing package
needs `launchMode="singleInstance"` (risks the silarah.com auth App Links, photo picker and Play
billing; the app uses `singleTop`), and a second push system would reintroduce the shared-phone leak
(previous account's calls ringing after sign-out). One place handles quiet hours, Silent/Off,
privacy-safe names and missed calls.

1. Caller taps Call → RPC `request_call(conversation_id)` checks: active match, no block, caller
   Premium, male side Premium, callee call setting, quiet hours, harassment cap, caller not already in
   a call, balance ≥ 1 minute, global switch on. Glare (callee is calling the caller) → merge into the
   existing request. Busy callee → missed call.
   - If the callee is a free man, or has Calls off / Silent / quiet hours: no ringing, the caller sees
     the same neutral message ("isn't taking calls right now"), the callee gets a missed-call note.
2. Server creates `call_requests` row (status ringing, 30 s timeout) and sends a high-priority FCM
   incoming-call push to all the callee's devices (heads-up notification with Answer/Decline; full-
   screen only if the member grants it; Android 14+ Play revokes full-screen intent for non-calling apps).
3. Caller cancels → status cancelled, cancel push stops ringing everywhere; a later Answer is refused.
   Timeout → missed.
4. Callee taps Answer → RPC `accept_call` (atomic: first device wins). Server then:
   - holds the caller's minutes: hold = min(balance, 60 min);
   - creates the Stream call (new call ID per call, server-side, members = the two users,
     `settings_override.limits.max_duration_seconds` = hold + 30 s connect allowance);
   - returns short-lived Stream user tokens (exp 1 h) to both apps; both join.
5. Server ends the call (Stream `mark_ended`) when: either participant leaves; both have not joined
   within 20 s of accept; block / report / unmatch / ban / pause / account deletion; Premium lost;
   global switch off. Stream's max duration is the hard stop even if our server is down.
6. Top-up mid-call: server extends `max_duration_seconds` (members cannot).
7. "Still talking?" prompt at 60 min; call ends unless extended by a new hold.

## 5. Billing and settlement

- Charge = time both participants were connected, rounded up per started minute, capped at the hold.
- Held minutes stay unavailable until the call is settled, so a missed webhook can never under-charge.
- Settlement sources: Stream webhooks (`call.session_participant_joined` / `_left` with
  `duration_seconds`, `call.session_ended`, `call.ended`); fallback job reads Stream's call record for
  every unsettled call we created. Stream has no usage/billing API and retries webhooks only ~15 s.
- Webhook security: verify `X-Signature` (HMAC-SHA256, API secret) over the raw body, gunzip first if
  compressed; dedupe on `X-Webhook-Id`; reply within 6 s.
- Server monthly cap on total call minutes (below the free credit until a card is attached and revenue
  covers it), with email alerts at 70% / 90%; admin switch to stop new calls.

## 6. Packs: purchase and refund (RevenueCat)

- Purchase → `NON_RENEWING_PURCHASE` webhook; server credits minutes. Dedupe on event `id` and unique
  store `transaction_id`. Minutes are never granted from the app.
- Refund → `CANCELLATION` for a non-renewing product (separate path from subscriptions): remove the
  minutes; balance may go negative and blocks calling until topped up; after 2 refunds the member can
  no longer buy packs. Needs Google Real-Time Developer Notifications connected in RevenueCat.
- Premium refunded → that period's included minutes removed.
- Pack product IDs added to the webhook allow-list.

## 7. Stream lockdown (`silarah_voice` call type)

- `user` role: no `create-call`, no `join-call`. `call_member`: `join-call`, `send-audio`, `end-call`.
- Nobody: `send-video`, `screenshare`, `change-max-duration`, `update-call`, `update-call-settings`,
  `join-ended-call`, `start-record-call`, `start-transcription-call`.
- Settings: video off, screensharing off, recording disabled, transcription disabled, backstage off,
  broadcasting off, session inactivity timeout 30 s.
- Stream user = Silarah user ID + first name and initial only (no surname, no photo URL). App loads
  photos itself under the member's photo privacy setting. Stream user deleted on account deletion.
- API key and secret only in Supabase secrets.

## 8. Member controls, safety, legal

- Call setting: Ring (default) / Silent (no ring, shows missed) / Calls off. Per chat: mute calls,
  block calls from this person. Missed and refused calls show in the chat ("📞 tried to call you");
  free women get "Ask him to call back" (free message) and "Call back" (Premium paywall).
- Harassment: 3 unanswered calls to the same person in 24 h → calling them blocked until the next day.
  Report from the call screen. No recording, ever.
- Guardian mode: Guardian sees call time and length only; never blocks calls.
- Call history in the chat and in the data export; deleted with the account.
- Android: restore `RECORD_AUDIO` (currently removed in the manifest), microphone rationale screen,
  microphone foreground service started only after Answer, Play declarations (foreground service with
  demo video, full-screen intent), Data safety form (audio), earpiece / speaker / Bluetooth, proximity
  screen-off, phone-call interruption handling, Xiaomi/Oppo/Vivo/Realme auto-start tip.
- Privacy policy and terms updated (Stream processes audio, call logs, no recording); consent version
  bumped so members re-accept.
- All 10 languages and all themes.

## 9. Staging gates (all must pass before the switch is turned on)

1. A member token cannot create a call or join a call it is not a member of.
2. A member cannot turn on video, record, transcribe or extend the time limit.
3. Max duration ends the call on time for both.
4. Webhooks: signature check (incl. compressed bodies) and duplicate delivery counted once.
5. Stream dashboard minutes match talk time only (ringing not billed).
6. License tester buys the same pack twice; a refund removes the minutes.
7. Shared phone: previous account's calls never ring after sign-out; auth links, photo picker and Play
   purchases still work.
8. Two phones: audio both ways, earpiece/speaker/Bluetooth, incoming phone call mid-call, background
   and locked screen, Android 7 (minSdk 24) device.

## 10. Worst cases accepted

- Refund after using a pack: ≤ ₹28 (₹199 pack). Refunded Premium: ≤ ₹2.40 of included minutes.
- 30 s connect allowance: ≈ 4 paise per call.
- Members swapping numbers on a call: cannot be prevented; the man has always paid first.

## 11. Owner tasks

- Stream: create account, apply for Maker plan, add a card before launch, share API key/secret.
- RevenueCat: Google refund notifications (RTDN) connected.
- Play Console: 4 consumable packs (section 3), microphone/calling declarations.

Sources: getstream.io/video/pricing, /video/docs/flutter/pricing-guide, /video/docs/api/ring-calls,
/video/docs/api/calls, /video/docs/api/call-types/settings, /video/docs/api/webhooks/overview,
revenuecat.com/docs/integrations/webhooks, /platform-resources/server-notifications,
/platform-resources/non-subscriptions.

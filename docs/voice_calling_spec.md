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
- Only the caller's minutes are used; answering never uses minutes. Women answer without Premium; a man
  needs Premium to answer too, so "answering is always free" is said to women only.
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
   - If the callee is a free man, or has Calls off / Silent: no ringing, the caller sees the same
     neutral message ("isn't taking calls right now"), the callee gets a missed-call note.
   - Quiet hours (hers, or the default 11 PM - 8 AM in her time zone): no ringing, and the caller is
     told so, with when calls ring again on the caller's own clock ("Aisha has quiet hours now. Calls
     ring again at 8:00 AM."); the callee gets a missed-call note. Her own refusals (calls blocked or
     muted for him, calls off, silent) are checked first, so "quiet hours" never reveals one (333).
     Her calling settings say callers are told this.
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
- Stream's limit starts as hold + 30 s (connect allowance). When both members are in (migration 327)
  it becomes hold + the real connect time + 2 s, and "Add minutes" builds on that, so paid talk time is
  never longer than the hold, whatever the app does. The caller's phone also ends the call at 0.
  "Add minutes" raises Stream's limit, which Stream sends to both phones; the callee's phone then reads
  the new hold and limit from the server, so its countdown, warnings and backstop follow (gate 3).
- Held minutes stay unavailable until the call is settled, so a missed webhook can never under-charge.
- Settlement sources: Stream webhooks (`call.session_participant_joined` / `_left` with
  `duration_seconds`, `call.session_ended`, `call.ended`); fallback job reads Stream's call record for
  every unsettled call we created. Stream has no usage/billing API and retries webhooks only ~15 s.
- Webhook security: verify `X-Signature` (HMAC-SHA256, API secret) over the raw body, gunzip first if
  compressed; dedupe on `X-Webhook-Id`; reply within 6 s.
- Monthly minute brake, an **emergency brake, never a budget limit for paid members**: it is at least
  the minutes members are entitled to this month (active Premium members x included minutes + unused
  pack minutes) plus 25%, recomputed hourly; a manual floor (`monthly_cap_minutes`) applies when that
  figure is stale. It trips only on abnormal spend: new calls then get "Calling is paused right now"
  and staff get the operational alert (70% / 90% alerts before that). The admin switch stops calling
  completely.

## 6. Packs: purchase and refund (RevenueCat)

- Purchase → `NON_RENEWING_PURCHASE` webhook; server credits minutes. Dedupe on event `id` and unique
  store `transaction_id`. Minutes are never granted from the app.
- Refund → `CANCELLATION` for a non-renewing product (separate path from subscriptions): remove the
  minutes; balance may go negative and blocks calling until topped up (the next pack makes up the
  difference first). No purchase limit (334): a Premium member can always top up, so a refund never
  leaves a dead end; the refund count is kept for records and safety review. Silarah itself refunds only
  its own mistakes (Refund Policy). Needs Google Real-Time Developer Notifications connected in
  RevenueCat.
- Premium refunded → that period's included minutes removed.
- Pack product IDs added to the webhook allow-list.

### 6.1 Included minutes follow Premium runs (migration 325)

- A **Premium run** is an unbroken stretch of Premium from any source: subscription (active or grace),
  promotional / referral grant, owner test grant. Included minutes come in consecutive 30-day periods
  from the run's start.
- The run starts when Premium starts (the event's time; a grant's `starts_at`). It ends when Premium
  actually ends: at the moment coverage ran out (`call_wallets.premium_covered_until`), or at once when
  an event withdraws it (expiration, revocation, refund, grant revoked or deleted).
- The same rules run from triggers on the subscription state and both grant tables, a 15-minute expiry
  sweep (`voice_call_premium_runs`) and every balance read, so the result never depends on who notices
  first. A read never decides on its own that Premium ended.
- Renewal, plan change, un-cancellation and a recovered billing retry **continue the run** (same
  periods, same used minutes), even after a short lapse. Grace / billing retry counts as Premium.
  Only a new purchase (`INITIAL_PURCHASE`) or a grant after Premium ended starts a **fresh run with
  full minutes**.
- A refunded Premium payment forfeits that period's included minutes (unchanged).
- Grant members (promo, referral, test) get included minutes and count in the monthly brake.

### 6.2 Pack refunds and reversals

- A refund applies only against the **recorded purchase of that store transaction**, to the member who
  received it, for that purchase's minutes. A refund with no purchase yet is stored
  (`call_pack_pending_refunds`) and netted the moment the purchase arrives. Each refund counts once.
- Staff refunds in Play Console must tick **Remove entitlement**: Google sends no notice for a refund
  that leaves the pack owned (gate 6, 25 Nov 2026: such a refund never reached RevenueCat), so the
  minutes would stay. If it was missed, remove the minutes with admin "Adjust pack minutes" (the card
  says so). License testers' purchases are SANDBOX events and count only for the IDs in
  `REVENUECAT_SANDBOX_TESTER_IDS`; real closed testers' purchases are production events.
- `REFUND_REVERSED` / `UNCANCELLATION` of a pack gives the minutes back once per transaction and lowers
  the refund count. A reversed refund that was still waiting is dropped, so the purchase counts in full.
- A pack refunded during a live call: the call finishes from its hold; the balance then goes negative
  and the next call asks for a top-up.

### 6.3 Paid packs are never lost

- The minutes sheet buys only when RevenueCat already knows this member
  (`Purchases.appUserID == Supabase user id`); otherwise "We couldn't confirm your account with Google
  Play yet. Please try again in a moment. You were not charged."
- A pack paid by a store account that matches no member (anonymous RevenueCat ID, deleted account) is
  kept in `private.call_pack_unclaimed`, staff get an admin notification, and it is credited:
  automatically when one of that store account's IDs is a member (aliases), on a later `TRANSFER` to a
  member, or by staff with one audited action (admin → Voice calls → Packs waiting for a member).
- Pending payments (UPI and other delayed methods): "Your payment is pending. Minutes are added
  automatically when it completes; you won't be charged twice." A pending payment that is cancelled
  or expires sends no purchase event and adds nothing.

### 6.4 What the minutes card promises

- "Available until {date}" when Premium will not renew or ends before the current period does
  (`premium_until`, `will_renew` from the server; renewal is shown only for an active subscription whose
  latest event keeps it going).
- "Unused included minutes don't carry over; they reset on {date}." only while Premium lasts past the
  period end.
- "Pack minutes never expire; you need Premium to use them." Lapsed with pack minutes: "Your {minutes}
  pack minutes are saved. Renew Premium to use them."
- Holds and settlement use included minutes before pack minutes. A call that crosses a period reset
  keeps its hold on the old period; the unused part goes back there and the new period starts full.
- The in-call meter counts minutes the way settlement charges: every started minute, never more than
  the hold.

### 6.5 Calling terms

- `call_settings.calling_consent_version` (and `calling_consent_type`, default `terms_of_service`) is
  set by the legal phase. Until it is set nothing changes.
- Once set, a member must have accepted that version or later to call, plan a call or accept a plan.
  The caller gets "Please review and accept the updated terms to use calls."; a callee without it is
  the same neutral "unavailable" for the caller and gets a missed-call notification "Review and accept
  the updated terms to receive calls."

### 6.6 Pause, deletion and export

- Profile pause: "Your {minutes} paid call minutes are kept while your profile is paused."
- Account deletion: "You have {minutes} paid call minutes. They will be lost and cannot be refunded
  after deletion."
- Release order: migration 325 changes `call_service_refund_pack(p_app_user_id, ...)`; deploy the
  `revenuecat-webhook` function in the same step as the migration.
- The data export has a `minutes_summary`: packs bought, pack minutes bought / refunded / adjusted by
  staff, included minutes used and forfeited, pack minutes used.

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
  Only calls that reached her count: declined; missed or cancelled after her phone showed the ring
  (332); and calls she refused by her own choice (calls off, silent, calls from him muted or blocked).
  Never counted (333): a phone with its data off, quiet hours, her being on another call, no phone able
  to ring, her account unavailable, his plan, her calling terms - none of those disturbed her or was
  her answer to him.
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
9. Status bar: the OnePlus shows the system call chip (Android 12+) with the caller's first name and a
   running timer; Mute / Hang up work from the notification; tapping it returns to the call.
10. Rings with the app swiped away, with the screen locked and asleep (the screen lights), and after
    10+ minutes idle (Doze). A ring that reaches the phone after its 30 s is shown as a missed call and
    never rings. Cancel and answered-elsewhere clear the ring on every device.
11. Notifications denied (or the incoming-call channel off) on every device of the callee: the caller
    gets the neutral "isn't taking calls right now", the callee sees the missed call and the Calls tab
    shows the "turn on call notifications" prompt.
12. Free man and free woman see the notification texts of section 12.5; several missed calls from one
    person collapse into one notification.
13. Calls tab: tab-name audit tests pass; 360 dp and largest font size screenshots in the longest
    locales; Arabic and Urdu (RTL) screenshots; every theme (Rose & Marigold, Ivory & Emerald, Pure
    OLED, Automatic light and dark).
14. Scheduled call: propose, accept, reminder 5 min before on both phones, Call now, expiry.
15. Call sound and route (12.9), both phones, recorded: ringback while ringing out, connected tone,
    end tone on both sides (hang-up, time up, server end), not-reached tone, reconnecting (Wi-Fi off a
    few seconds) with tone and recovery, 2-minute and 30-second warnings; volume keys change the call
    volume and silence an incoming ring; silent / vibrate / Do Not Disturb respected; a real Bluetooth
    headset: call starts on it, connect and disconnect mid-call, picker shows its name, headset button
    hangs up; wired headphones; earpiece default; proximity; mute in sync on screen and notification.

## 10. Worst cases accepted

- Refund after using a pack: ≤ ₹28 (₹199 pack). Refunded Premium: ≤ ₹2.40 of included minutes.
- 30 s connect allowance: ≈ 4 paise per call.
- Members swapping numbers on a call: cannot be prevented; the man has always paid first.

## 11. Owner tasks

- Stream: create account, apply for Maker plan, add a card before launch, share API key/secret.
- RevenueCat: Google refund notifications (RTDN) connected.
- Play Console: 4 consumable packs (section 3), microphone/calling declarations, foreground service
  types `phoneCall` and `microphone` and the full-screen intent, each with the demo video recorded on
  the OnePlus during the staging gates (`release/voice_calling_play_demo.mp4`: incoming ring, answer,
  status-bar chip, mute, hang up, missed call). Required before any AAB with calling code is submitted.
- Release order: migration 324 must be on production before an app version with this code ships (the
  app reads `notification_prefs.missed_call` and the new RPCs).
- Release order: migration 328 (the matched member's full name on the call screen) goes on production
  in the same step as the `calls` function, which reads its `caller_shown_name`.

## 12. Notifications, status bar and Calls tab rules

Added 22 Nov 2026 at the owner's request. Same principles as above: the server decides who may call,
who is rung, what each person is told and what is charged; the app only shows the server's answer.

### 12.1 One native call module

All call notifications, the call foreground service and the system call integration live in one small
local Flutter plugin (`packages/silarah_calls`, Kotlin). A plugin is registered in every Flutter engine,
so the same code runs from the FCM background isolate when Silarah is closed. It replaces the
`flutter_local_notifications` package and the `MainActivity` call channel.

- Notification channels, created once at first launch (Android cannot change a channel's importance
  later): **Incoming calls** (high, system ringtone, vibration, shows on the lock screen), **Missed
  calls** (default), **Ongoing call** (low, silent).
- Incoming ring: `Notification.CallStyle.forIncomingCall` (Android 12+; a heads-up with Answer and
  Decline below that), full-screen on a locked or sleeping phone (the screen lights), caller's first name
  and photo only under the caller's photo privacy. Decline is sent to the server from native code with
  the one-time decline token, without opening Silarah.
- Ongoing call: Jetpack Core-Telecom (`androidx.core:core-telecom`, self-managed call,
  `MANAGE_OWN_CALLS`, foreground service type `phoneCall`) on Android 8+, which gives the system call
  chip in the status bar (Android 12+), headset / car buttons, Bluetooth routing and correct hold when a
  regular phone call arrives. The notification is `CallStyle.forOngoingCall`: first name, a running
  timer, minutes left, Mute and Hang up, tap returns to the call. Android 7 (API 24–25): a microphone
  foreground service with the same ongoing notification.
- In the app: a slim "Tap to return to call · 04:12" bar above every screen while a call is live and the
  member is not on the call screen.
- Not used: `stream_video_push_notification` (forces `singleInstance`; the app keeps `singleTop`).

**The call screen (WhatsApp / Telegram model, 24 Nov 2026).** The call screen is a layer above the
whole app (`CallLayer`), never a page of the app's navigation. It shows from the first ring or tap until
the member leaves it or the call is over, over whatever is underneath, start-up included; the app keeps
its place below it. Device findings that led here: with Silarah open and the phone asleep, a ring after
an earlier ring had run out reached the app but no ring screen showed (status-bar icon, ringing and
vibration only); with Silarah closed, a ring opened the app's start-up instead of the call.

| Situation | What the member sees |
|---|---|
| Phone unlocked, using another app | Android's heads-up ring (Answer / Decline). Tapping it opens the native ring screen only |
| Phone locked or asleep, or Silarah closed | The native ring screen (`IncomingCallActivity`) over the lock screen; never Silarah's start-up or home |
| Answer, on the ring screen or the heads-up | The native screen shows "Connecting…" (no buttons) until Silarah's call screen has drawn over it in the same task; Silarah holds its first frame until then, so no logo or launch window shows. The heads-up's Answer opens the native screen already answering, and Silarah opens only once that screen is on screen (over an empty task Android would show Silarah's launch window) |
| Decline, on the ring screen or the heads-up | Sent at once; the phone stays (or goes back) where the member was |
| Silarah open | The full-screen call screen over the current screen |
| Back on a ring | Nothing: a ring waits for Answer or Decline |
| Back during a call, phone unlocked | The app, with the return bar; the call goes on |
| Back during a call, phone locked | Silarah steps back to the lock screen (the app is never shown over a locked phone); the call goes on, with its notification and status-bar chip |
| A ring that brought Silarah up from closed or another app ends, its screen still up | The phone goes back to where the member was (lock screen or the other app). A ring that arrived while Silarah was in front, or a member who left the call screen, stays in Silarah |

### 12.2 Ring delivery

0. Calling, then Ringing (WhatsApp model, 332). The callee's phone sends a receipt the moment it shows
   the ring (open, in the background or closed), proven with the ring's own Decline token, so no
   session is needed. The caller sees "Calling…" until the receipt arrives and "Ringing…" after, on the
   call screen and the status-bar notification. A ring that runs out without a receipt ends as
   "Couldn't reach their phone. It may be offline."; every other unanswered ending stays "Not
   answered", so the caller never learns whether it was declined, silenced or refused.
1. Ring, cancel and answered pushes are data-only, high priority, and live only as long as the ring
   (TTL = ring time, 30 s). A phone that comes online later never rings for an old call.
2. Before ringing, the phone checks the ring is for the signed-in account and has not expired (on this
   phone's clock, from arrival). After a tap the server is asked again; a cancelled, answered or expired
   call shows the missed call instead of the call screen.
3. Cancel or answer on another device sends a cancel push to every device of the callee; each clears its
   ring. Every ring push ends in a visible notification (incoming, then missed or cleared), so Android
   does not lower Silarah's push priority.
4. Each device reports with its push registration whether it can ring: notifications allowed and the
   Incoming calls channel not blocked (`user_fcm_tokens.can_ring`, refreshed at every app start and
   resume). If no device of the callee can ring, the server treats the callee as unavailable: the caller
   gets the neutral "isn't taking calls right now", the callee gets the missed call in the app and the
   Calls tab shows "Turn on call notifications".
5. Shared phone: sign-out cancels every call notification, stops any call service and ends a live call
   before the push token is removed (on top of the existing token clean-up). The phone also stores which
   account it rings for and drops rings for anyone else.
6. Auto-start tip (OnePlus, Xiaomi / Redmi / POCO, Oppo, Vivo, Realme, iQOO only) in Calls settings.

### 12.3 What the callee is told

Names in every push are the **first name only**, never a surname or initial. Photos only under the
member's photo privacy (blurred or initials where the member requires it).

| Situation | Callee notification | In chat and the Calls tab |
|---|---|---|
| Premium caller → free woman or any Premium member, call setting Ring | Incoming call "Abdul · Silarah voice call", Answer / Decline | Call log row; chat call tile |
| Callee is a free man | No ring. "Khatun tried to call you" · "Get Premium to talk with your matches". Tap opens the Calls tab with the paywall | Missed row with the paywall. The locked chat's inbox preview shows "📞 Missed voice call" (call metadata, shown deliberately as the upsell); the chat itself stays locked |
| Free woman misses a call | "Missed call from Abdul". Tap opens the Calls tab | Missed row with "Ask him to call back" (free templated message under normal messaging rules) and "Call back" (Premium paywall) |
| Callee on Silent, or in quiet hours | Silent missed-call notification (Missed calls channel) | Missed row |
| Callee on Calls off | No push at all | Missed row and badge only |
| Missed-call notifications switched off (`notification_prefs.missed_call`) | No missed-call push | Missed row and badge |

- Several missed calls from the same person collapse into one notification ("3 missed calls from
  Abdul"); the count comes from the server.
- Ring / Silent / Calls off is the only control for ringing. `notification_prefs` gets one new toggle,
  `missed_call`, for missed-call pushes only.
- Guardian: time and length in the mirror log, no push per call.
- Already in Silarah: the full-screen in-app incoming screen instead of the heads-up.

### 12.4 What the caller is told

- Busy, declined, timeout, Silent, Calls off, quiet hours, or no device can ring: always the same
  neutral "isn't taking calls right now" in the app, never which; no push to the caller. In the caller's
  history and chat: "No answer".
- A call that connected: both sides see "Voice call · 12 min" (talk time).

### 12.5 Calls tab

**Placement.** A fifth bottom tab, between Chats and Profile: Discover · Interests · Chats · **Calls** ·
Profile. Tabs are identified by name, never by position: `/home?tab=calls`, `/calls`, `/calls/<peerId>`.
Stored notifications and old links that still carry `/home?tab=0..3` keep their old meaning (3 =
Profile). The tab is shown only while the server switch is on (`calls_enabled`); with the switch off the
app looks exactly as before. Guardian-only accounts never reach the home tabs, so never see it.
Five labels fit at 360 dp in all 10 languages; the bar ignores system font scaling like the other tabs.

**Screen, top to bottom**

1. *Minutes card.* Premium: included minutes left this Premium month and the renewal date, pack minutes,
   **Top up** (opens the packs sheet). Free members: a card explaining that Premium unlocks calling
   (women: "you can always answer for free"). If this phone cannot ring (12.2.4): "Turn on call
   notifications" with a button to the right system screen.
2. *Monthly insight.* "You talked 2 h 15 m this month" (talk time of connected calls in the member's
   current calendar month, local time). Hidden when zero.
3. *Planned calls* (section 13), pinned above the history: name, time, countdown, Call now / Accept /
   Cancel.
4. *Filter chips* All · Missed · Incoming · Outgoing · Planned, and search by name.
5. *History grouped by day* (Today / Yesterday / weekday / date in the member's language). Each row:
   avatar (photo privacy), name (first name + surname initial until matched, as everywhere), direction
   icon (outgoing, incoming, missed in the theme's error colour), talk time and minutes used, time of
   day. Consecutive calls with the same person on the same day collapse into one row with a count
   ("Abdul (3)").
6. *Row tap* → call details sheet: every attempt with that person (time, direction, result, talk time,
   minutes used), totals, Call back · Message · View profile, Mute calls · Block calls · Report (with
   the "Harassing calls" reason).
7. *Swipe* → Call back, or Remove from history. Remove hides the rows for this member only (it never
   changes harassment limits, safety logs, the Guardian log or the data export; the export includes
   hidden rows).
8. *Badge.* The tab shows the server's count of unseen missed calls; opening the tab marks them seen on
   every device (`mark_calls_seen`). Updated live by the missed-call push and on resume.
9. *Paywall routing.* Free woman's missed row: "Ask him to call back" and "Call back" (paywall). Free
   man: missed rows open the paywall. Caller: "No answer" for any call that did not connect.
10. *Unavailable members* (blocked either way, deleted, banned, deactivated): "Member unavailable", no
    photo, no name, no actions except Remove.
11. *Empty state and loading skeletons* in the Silarah style, motion from `silarah_motion`; all
    themes; TalkBack labels on every row and action; RTL for Arabic and Urdu; large fonts wrap, never
    clip.

**Server.** One RPC `get_my_call_log(p_filter, p_query, p_before, p_before_id, p_limit)` returns a page of
the member's own attempts (cursor = `created_at, id`, indexes on caller and callee by time), with the
other member's id, display name, availability and photo eligibility decided in the same query (same
rules as the chat inbox: no N+1). `get_my_call_overview()` returns minutes, renewal date, the monthly
insight, unseen count, ring capability and planned calls in one call. `hide_my_call_log_rows(peer,
up_to)` and `mark_calls_seen()` write only the member's own rows. Free tier: no new paid services; all
reads are bounded pages.

- **A call's result before settlement (migration 326).** A call is settled a few seconds after it ends.
  A call both members were in counts as answered at once; its talk time and minutes appear at
  settlement. While a member's call is being settled the overview says `settling` and the app checks
  again every 3 seconds (up to a minute), then reloads the call log, chats and minutes once.
- **Return-to-call bar** shows only off the call screen. The call screen's open count is published
  after the frame, never while the tree builds (a mid-build change once froze the bar on "Calling…").

### 12.6 One gate, one source of numbers, clear instructions

- **One gate.** `get_calling_rules()` (any signed-in account, Guardians included) returns the switch and
  every number a member is told. While the switch is off the app looks exactly like a release without
  calling: no Calls tab, call settings, missed-call toggle, "How calling works", Help entry, call
  buttons, minutes or packs, Premium benefit or Guardian call log. If the switch turns off while the app
  is open, the tab disappears and `/calls` links land on Chats; a call already live ends by the server's
  rules (section 4.5). Turning it on shows everything again on the next refresh or resume.
- **One source of numbers.** Unanswered-call limit, included minutes and period, longest call, ring
  time, minimum minutes to call, planned-call lead / horizon / window / reminder / limits
  and log retention all live in `private.call_settings`; copy uses placeholders, never fixed numbers.
- **"How calling works"** is shown once before a member's first call and from the Calls tab (ⓘ), the
  minutes sheet, call settings and Help: who can call whom, minutes (included, packs, per started
  minute, caller pays, refunds), Ring / Silent / Calls off and per-person mute / block, the unanswered-
  call rule in plain words, reporting, no recording, Guardian sees times only, planned calls.
- **Explained where it applies**, never a code: the unanswered-call limit (the number and when they can
  call again), Premium needed (calls paywall), minutes out (packs sheet) and warnings in the call,
  callee not taking calls (neutral), negative balance after a Google Play refund, packs non-refundable (before purchase), Calls
  off (what callers see), notifications off (Calls tab prompt), planned call expired ("Missed scheduled
  call"), calling paused (switch or brake).
- **Premium screen** lists private voice calls with the included minutes for men and women (women: they
  can call with Premium and always answer free), and the paywall sheets list it, only while calling is on.
- All in 10 languages, RTL, every theme.

### 12.7 Retention

Call records (who called whom, when, outcome, length, minutes) are kept **12 months**
(`log_retention_months`), then deleted by a daily job, except while an open (pending) report between the
two members needs them. "Remove from history" only hides rows for that member. Minutes ledger rows are
the member's account history and are deleted with the account (existing deletion flow), as are all call
records of a deleted account. Audio is never recorded or stored by Silarah.

### 12.8 Staff tools (admin panel, staff roles and AAL2)

- Calling switch (super admin) with a confirm dialog; every change in the admin audit log.
- This month's charged minutes, the brake in force and the estimated Stream cost.
- "Harassing calls" reports in the existing reports queue with the call metadata between the two members
  (times, results, lengths, unanswered attempts before the report; never audio).
- One member's call history for an open case (moderators, support).
- Manual pack-minute adjustment (super admin, support) with a written reason, in the ledger and the
  audit log.

### 12.9 Call sound and audio route (phone-call parity)

- **One call from the first ring.** An outgoing call is a self-managed Telecom call (Android 8+) from
  the moment it rings out, so its ringback, route and status-bar call are a call's; it becomes active
  when the other member answers. An incoming call joins Telecom when answered.
- **Tones** on the voice-call stream (they follow the route and the in-call volume): ringback while the
  other phone rings, stopped at answer / cancel / timeout; a short tone (and a haptic) when the call
  connects; an end tone on both phones however a connected call ended (hang-up, time up, server end);
  one neutral "not reached" tone for every call that rang out without connecting (never why, 12.4); an
  error tone for a failure; a tone when the connection drops ("Reconnecting…"); a tone + haptic at 2
  minutes and at 30 seconds left (at the 60-minute hold, "Still talking?" 2 minutes before).
- **Time up:** the caller's phone ends the call when the paid time reaches 0 (end tone, "Your call minutes
  ran out."); the other phone ends with the end tone when the server ends it. Stream's limit (hold +
  30 s connect allowance) is only the backstop. Proven by ear on 23 Nov: ringback, connected beep,
  2-minute and 30-second warnings, end tone and the declined (not-reached) tone, through a Bluetooth
  device.
- **Reconnecting** longer than 30 seconds ends the call ("Call failed. Please try again."); Stream ends
  it on the server and billing stops there.
- **Hold:** a regular phone call holds the Silarah call both ways: the microphone is off and the other
  member is not heard; both come back when the phone call ends.
- **Back** during a call leaves the call screen (the call goes on, with the return bar); a ring waits
  for Answer or Decline.
- **After a call** the phone leaves communication audio mode (the call service resets it; Android 10
  and older keep an app's mode until it does, and rings would then neither vibrate nor ring normally).
- **A ring on a sleeping phone** turns the screen on (not with Do Not Disturb on or full-screen calls
  off).
- **Volume keys** set the call volume while a call rings out or is live; during an incoming ring on
  Silarah's screen they silence the ring (it stays on screen, like a phone call).
- **Route.** Stream picks the route at join: a connected headset, else the earpiece. The app follows it
  (it never forces the earpiece). One decision is applied to Telecom and the audio engine together.
  A Bluetooth or wired headset that connects takes the call; the member's choice stays while that
  route exists; when the route in use goes away, the next best (Bluetooth, wired, earpiece; never the
  speaker by surprise). The picker lists Phone / Speaker / Bluetooth (with the headset's name) /
  Headphones.
- **Bluetooth permission** (Android 12+, nearby devices): asked with the microphone, or once on its own
  with a short reason ("Use your Bluetooth headset"); declining never stops a call.
- **Still open (device gates):** answering an incoming ring with a headset button needs the ring to be
  a Telecom call too; until then the headset button hangs up a live call (Telecom) and the ring is
  answered on the phone.

## 13. Planned calls ("Request a call at 8 pm")

1. A plan is possible only where a call would be: an active match, no block, the man in the pair holds
   Premium, and neither member has Calls off. Either member proposes a time from a call's details (a
   free man is sent to the paywall; a free woman proposing to a free man gets the neutral answer):
   at least `plan_min_lead_minutes` (10) and at most `plan_max_days_ahead` (7 days) ahead. One open plan
   per match, at most `plan_max_open` (5) open plans per member, and at most `plan_max_per_chat_day` (3)
   proposals per chat in 24 hours. Refused neutrally where a call could not happen.
2. The other member accepts or declines (push "Abdul suggested a time to talk", first name only, opens
   the plan). Either member can cancel at any time. Nobody is told why a plan was declined.
3. Accepted plans are pinned in both Calls tabs with a countdown. `plan_reminder_minutes` (5) before,
   both get a reminder: none for Calls off, silent in quiet hours or on Silent, none if cancelled. From
   then until `plan_window_minutes` (30) after, the member who can start calls sees **Call now**; the
   call itself goes through every check of sections 2–5 at that moment (Premium, minutes, block,
   unanswered-call limit, ringing). A free man sees the paywall instead.
4. A plan ends as done when the two connect within that window, otherwise expired ("Missed scheduled
   call"). It is done as soon as that call is settled; while a call made in the window is still
   ringing, live or unsettled when the window ends, the plan waits for it (at most the longest call
   the window allows), so a long planned call is never "missed" (331). It is cancelled when the match closes, someone blocks, or the man's Premium ends. Plans are
   part of the call history, the Guardian log (time only) and the data export.

## 14. Rule → proof

Every rule above has a proof before the switch is turned on: R = server rollback test
(`supabase/tests/voice_calling_rules_test.sql`, `supabase/tests/calls_tab_rules_test.sql`,
`supabase/tests/call_money_integrity_test.sql`),
D = Deno test, W = Dart unit / widget test, P = phone evidence (`docs/voice_calling_staging_evidence.md`).

| Rule | Proof |
|---|---|
| 2 Access (free man / free woman / Premium, man must be Premium, caller pays) | R |
| 3 Packs credited once, refunds claw back | R, D, P (gate 6) |
| 4 Ringing owned by the server; first device wins; cancel / timeout refuse a late answer | R, P |
| 4 Hold = min(balance, 60); max duration = hold + 30 s; ends on block / report / ban / pause / Premium loss / switch | R, P (gate 3) |
| 5 Charge = connected time, per started minute, capped; Stream record first, webhook log fallback | R, D, P |
| 5 Webhook signature incl. gzip, dedupe | D, P (gate 4) |
| 7 Stream lockdown | P (gates 1–2, 29 probes) |
| 8 Ring / Silent / Off, quiet hours, per-chat mute and block, harassment limit | R, P |
| 12.1 CallStyle ongoing + status-bar chip, Mute / Hang up | W, P (gate 9) |
| 12.2 TTL, late-ring suppression, cancel everywhere, screen lights on a locked phone | D, W, P (gate 10) |
| 12.2.4 No device can ring → unavailable + prompt | R, W, P (gate 11) |
| 12.2.5 Shared phone sign-out | W, P (gate 7) |
| 12.3 Texts per situation, first name only, collapse count, `missed_call` toggle | R, D, W, P (gate 12) |
| 12.4 Caller always neutral, "No answer" | R, W |
| 12.5 Tab by name, old links keep meaning, hidden when switch off | W, P (gate 13) |
| 12.5 Log privacy (names, photos, unavailable members), pagination, filters, search | R, W |
| 12.5 Remove hides for the member only; export keeps hidden rows; badge and seen | R, W |
| 13 Planned calls: window, one per match, limits, accept / cancel / reminder / expiry | R, W, P (gate 14) |
| 13.1 Plans only where a call could happen (man Premium, no Calls off), end on Premium loss / block | R |
| 13.3 Reminder silent in quiet hours, none for Calls off | R, D |
| 12.6 One gate: switch off hides every surface; tab and links fall back to Chats | W, P (gate 13) |
| 12.6 Numbers from the server rules in the guide, minutes card, paywall, Premium screen, plan sheet | R, W |
| 12.6 Premium screen and paywall list calling only while on, men and women, 10 languages | W |
| 5 Monthly brake never below entitled minutes; stale figure falls back to the manual floor | R |
| 12.7 Retention: 12 months, kept while an open report needs it | R |
| 12.8 Staff RPCs closed to members; minutes adjustment needs a reason, audited | R, admin `tsc` |
| 6.1 Run starts / ends on Premium events, never on a read; read, trigger and sweep give the same end time | R |
| 6.1 Renewal, plan change, recovered billing retry continue the run; new purchase after the end is fresh | R |
| 6.1 Grace counts as Premium; grants get included minutes and count in the brake | R |
| 6.2 Refund only against its recorded purchase; early refund netted; reversal once, refund count lowered | R, D |
| 6.3 Unknown store account: kept, staff alerted, credited by alias / transfer / audited staff action | R, D, admin `tsc` |
| 6.3 Sheet buys only for the signed-in store identity; pending payment message | W |
| 6.4 "Available until" / reset date never promise a renewal; lapsed pack minutes kept | R, W |
| 6.4 Included before pack; period reset mid-call; pack refunded mid-call; meter = settlement maths | R, W |
| 6.5 Calling terms gate for caller, callee, plans; no change until a version is set | R, W, D |
| 6.6 Pause / deletion notes; export minutes summary | R, W |
| 12.9 Ringback / connected / end / not-reached / failed / reconnecting / warning tones on the call stream | W (wiring), P (gate 15) |
| 12.9 Route follows headsets; no forced earpiece; one decision for Telecom and engine; headset names | W, P (gate 15, BT headset) |
| 12.9 Volume keys = call volume; volume key silences the ring; 30 s reconnect limit; 2 min / 30 s warnings | W, P (gate 15) |
| 12.5 Connected calls answered before settlement; `settling` re-check until final | R (326), W |
| 12.1 Return bar hidden on the call screen, redraws after it | W, P |
| 5 Paid talk time never longer than the hold: allowance shrinks to the real connect time (327) | R, P |
| 8 Blocked by them: old calls show "Member unavailable" (no name, photo, call back); a call or plan is refused and never rings; no missed note | R, W |
| 12.1 Call screen shows the other member's photo on every path (ring carries the caller id) | W, P |
| 12.3 / 12.5 Names: pushes first name only; Stream first name + initial; call screen full name once matched (328) | R, P |
| 12.5 The call list of a member closes on a swipe down from the top of the list | W, P |

Sources: getstream.io/video/pricing, /video/docs/flutter/pricing-guide, /video/docs/api/ring-calls,
/video/docs/api/calls, /video/docs/api/call-types/settings, /video/docs/api/webhooks/overview,
revenuecat.com/docs/integrations/webhooks, /platform-resources/server-notifications,
/platform-resources/non-subscriptions.

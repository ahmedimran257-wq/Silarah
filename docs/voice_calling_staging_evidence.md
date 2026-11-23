# Voice calling — staging evidence

Staging project `ykmgkrveucslglxvcyss`, Stream app "Silarah Staging" (Mumbai).
Calling switch: **OFF** (`private.call_settings.calls_enabled = false`).

## Server build (22 Nov 2026)

| Item | Result |
|---|---|
| Migration 323 dry run (BEGIN … ROLLBACK) | compiled, rolled back |
| Rule tests `supabase/tests/voice_calling_rules_test.sql` (one transaction, rolled back) | **94 / 94 pass** |
| Migration 323 applied, recorded in `schema_migrations` | `calls_enabled = false`, watchdog `voice_call_watchdog_10s` scheduled |
| Edge functions deployed | `calls`, `stream-webhook`, `call-worker`, `call-gate-probe` (staging only) |
| Deno tests (webhook signature + gzip, talk-time overlap, lockdown body, settlement decisions, RevenueCat packs) | all pass |

The rule tests cover: switch off; free woman / free man cannot start; free man
not rung but gets a missed-call note; neutral answer to the caller; one ring
per caller; busy callee; only the callee answers; first device wins; hold =
min(balance, 60); max duration = hold + 30 s; extend after top-up; duplicate
pack purchase and duplicate RevenueCat event counted once; settlement rounds
up per started minute, capped at the hold, included minutes first; refunds
(once, may go negative, negative blocks calling, 2 refunds stop packs);
Premium refund removes included minutes; Ring / Silent / Calls off; quiet
hours; 3 unanswered calls in 24 h; per-chat mute and block calls; decline
token; cancel and timeout refuse a late Answer; glare; block, report,
unmatch, ban, pause, deletion, Premium loss, messaging suspension and the
switch each end a live call; join timeout; monthly cap; purge mid-call
returns minutes; members cannot call service RPCs, read call tables or flip
the switch; data export includes call history.

## Stream call type `silarah_voice` (read back from Stream)

- grants: `user` = none, `call_member` = join-call, send-audio, end-call,
  `guest` = none (Stream's default guest grant included video and joining).
- video off, screen sharing off, recording / individual / raw / frame
  recording disabled, transcription and captions disabled, ingress off,
  backstage off, broadcasting off, session inactivity 30 s, max participants
  2, type-level max duration 3630 s, lifecycle single_use, Stream
  notifications off, guest user creation disabled on the app.
- Webhook hook: `…/functions/v1/stream-webhook`, events
  session_participant_joined / _left, session_started / _ended, call.ended.

## Gate 1 and 2 — real member tokens against Stream (29 / 29 pass)

| Probe | HTTP | Result |
|---|---|---|
| member token cannot create a call | 403 | pass |
| join with create=true cannot create a call | 403 | pass |
| stranger cannot join someone else's call | 403 | pass |
| stranger cannot read someone else's call | 403 | pass |
| anyone with only the API key cannot become a guest | 404 | pass |
| call member can join their own call | 200 | pass |
| member joins own call the SDK way (create=true) | 200 | pass |
| stranger cannot join with create=true either | 403 | pass |
| member's own capabilities are only join/send-audio/end-call | — | pass |
| member cannot extend the time limit | 403 | pass |
| member cannot remove the time limit | 403 | pass |
| member cannot turn video on | 403 | pass |
| member cannot grant themselves send-video | 403 | pass |
| member may ask for video (Stream accepts the ask) | 200 | pass |
| member cannot read call details (no read-call grant) | 403 | pass |
| member re-joins to read capabilities | 200 | pass |
| asking for video grants nothing | — | pass |
| the other member cannot grant video either | 403 | pass |
| member cannot start recording | 403 | pass |
| member cannot start an individual recording | 403 | pass |
| member cannot start frame recording | 403 | pass |
| member cannot start transcription | 403 | pass |
| member cannot start closed captions | 403 | pass |
| member cannot broadcast (HLS) | 403 | pass |
| member cannot go live | 403 | pass |
| member cannot add a third person | 403 | pass |
| member cannot make the call ring through Stream | 403 | pass |
| member can end their own call | 200 | pass |
| nobody can join an ended call | 403 | pass |

## Gate 4 — webhooks against the deployed function (8 / 8 pass)

Signed plain body 200; same delivery again 200 and recorded **once**
(`private.stream_webhook_deliveries`); signed gzip body 200 (signature over
the uncompressed bytes); gzip signed over compressed bytes 401; wrong,
missing or tampered signature 401; another app's key 401. Refused deliveries
are not recorded. Real Stream deliveries are checked again during the phone
test.

## Phone tests, 22 Nov (OnePlus d2e084e7 + Redmi 427bc4f00903, build 48102)

- Ringing in front, in the background and with the app closed (2–6 s); decline in the app and from the
  notification; missed call with its note; answer from the notification with the app closed.
- Audio both ways (IN_COMMUNICATION, microphone recording), speaker / earpiece switch, mute, microphone
  kept alive in the background, call over the lock screen.
- Settlement from Stream's participant sessions: 51 s → 1 min, 195 s → 4 min, 228 s → 4 min.
- Unanswered-call limit: the 4th call is refused until the caller's local midnight, with the message.
- Found and fixed: a ring on a sleeping Android 10 screen opened the call behind a dark screen (the
  window is now set as the ring opens Silarah); a failed chat-state load hid the call button (the last
  answer is kept and the load retried).

## Calls tab, notifications, planned calls (migration 324, 23 Nov)

| Item | Result |
|---|---|
| 324 dry run on staging (BEGIN … ROLLBACK) | compiled |
| `supabase/tests/voice_calling_rules_test.sql` with 324 | **94 / 94 pass** |
| `supabase/tests/calls_tab_rules_test.sql` | **112 / 112 pass** |
| Deno (`_shared`, incl. push builders) | 47 pass |
| Flutter: `test/calls_tab_test.dart` (tabs by name, grouping, plans, guide numbers, Premium list on/off in 10 languages, 5 tabs at 360 dp in 10 languages, Calls tab in every theme incl. Arabic/Urdu, return-to-call bar) | 52 pass |
| Android compile incl. `packages/silarah_calls` (Core-Telecom 1.1.0) | passes |
| Admin panel `tsc --noEmit`, eslint | clean |

## Still to run (needs phones / approval)

- Gate 3 (max duration ends on time for both), gate 5 (Stream dashboard
  minutes = talk time), gate 7 (shared phone, auth links, photo picker, Play
  purchases), gate 8 (two phones, routes, phone-call interruption,
  background/locked, Android 7): need a second Android phone.
- Gate 6 (license tester buys a pack twice, refund): needs the owner's
  approval and a RevenueCat-enabled build.

## Two-phone test, build 48103 (23 Nov 2026; OnePlus 8 = Imran, Premium; Redmi Note 4 = Aisha, free)

| Check | Result |
|---|---|
| Calls tab and minutes card show (switch on); guide before the first call with server numbers | pass |
| Outgoing call is a Telecom call from the first ring (state DIALING, audio mode IN_COMMUNICATION) | pass |
| Ring on the Redmi: first name only, Answer / Decline (plain heads-up fallback on this ROM) | pass |
| Answer: Telecom ACTIVE; OnePlus call goes to its connected Bluetooth device (HeadsetStateMachine AudioOn), Redmi on the earpiece | pass |
| Meter "17 min left" = 18 − 1 started minute; notification "16 min left" after 1 minute | pass |
| Volume key changes the Bluetooth call volume (8 → 7), set back | pass |
| Mute in sync: notification action turns to "Unmute" | pass |
| Callee hangs up: caller shows "Call ended" within 1 s; both phones back to MODE_NORMAL, no Telecom call, no service, no notification | pass |
| Settlement: 108 s → 2 min, included minutes, 4 s after the end | pass |
| Volume key during the ring: FLAG_INSISTENT removed (0x86 → 0x82), ring stays on screen | pass |
| Caller cancels while ringing: ring gone on the Redmi, both phones clean; missed-call note "9 missed calls from Imran" | pass |
| **Found:** return bar shown on the call screen and frozen on "Calling…" | fixed in 48104 (bar count published after the frame) |
| **Found:** right after a call the Calls tab showed "No answer" and 0 minutes (read before settlement) | fixed (migration 326 + re-check) |
| Ringback, connected beep, 2-minute and 30-second warnings, end tone, declined (not-reached) tone: heard by the owner, through the OnePlus's Bluetooth device (48104, 3-minute hold) | pass |
| **Found:** a 3-minute hold ran 3:29 (Stream's limit = hold + 30 s connect allowance; joining took 4 s); billing capped at 3 min | fixed in 48105: the caller's phone ends at 0 |
| **Found (owner):** the Redmi's call screen showed Imran's initial, not his photo (the ring carried no caller id; the screen showed a photo only when the opener passed one) | fixed in 48105 |
| **Found (top-up review):** a modified app could talk up to 30 s free per call (Stream allowance) | fixed: migration 327 shrinks the allowance to the real connect time |

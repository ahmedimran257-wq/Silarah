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

## Still to run (needs phones / approval)

- Gate 3 (max duration ends on time for both), gate 5 (Stream dashboard
  minutes = talk time), gate 7 (shared phone, auth links, photo picker, Play
  purchases), gate 8 (two phones, routes, phone-call interruption,
  background/locked, Android 7): need a second Android phone.
- Gate 6 (license tester buys a pack twice, refund): needs the owner's
  approval and a RevenueCat-enabled build.

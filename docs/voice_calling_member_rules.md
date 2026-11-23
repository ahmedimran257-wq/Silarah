# Voice calling — what members are told, and what the legal text must say

For the legal / privacy policy / website / Play listing session. Source of
truth for behaviour: `docs/voice_calling_spec.md`. Every number below comes
from `private.call_settings` through `get_calling_rules()`; current values in
brackets. Copy is in `lib/l10n/calling_ui_copy.dart` (10 languages).

## Rules members see ("How calling works")

**Who can call**
- You can call only your matches, inside Silarah. Nobody sees your phone number.
- Premium members start calls. When a man is on the call, he needs Premium.
- Women answer calls free, without Premium.

**Call minutes**
- Premium includes {included} [30] call minutes every {period_days} [30] days. Unused minutes do not carry over.
- Minute packs never expire, but you need Premium to use them.
- Only the caller's minutes are used, per started minute. A call lasts up to {max_call} [60] minutes at a time.
- If a pack is refunded, its minutes are removed. After {refunds} [2] refunds, packs can no longer be bought.

**Ringing and your choices**
- A call rings for {ring} [30] seconds. Choose Ring, Silent or Calls off in Settings.
  - Ring: Calls from your matches ring this phone.
  - Silent: No ring. Calls show as missed, and callers see that you are not taking calls right now.
  - Calls off: Nobody can call you or plan a call with you. Callers see that you are not taking calls right now.
- You can mute or block calls from one person; they are not told.
- If Silarah's notifications are off on your phone, calls cannot reach you.
- Missed-call notifications can be turned off; missed calls always show in the Calls tab.

**Protection from unwanted calls**
- If you call someone {limit} [3] times without an answer, you can call them again the next day. This protects members from unwanted calls.
- Report a call from the call screen or your Calls tab ("Harassing calls" reason). Reporting ends the call.

**Planned calls**
- Suggest a time to talk, at least {lead} [10] minutes and up to {days_ahead} [7] days ahead. The other member accepts or declines.
- You both get a reminder {reminder} [5] minutes before. If you do not talk within {window} [30] minutes of the time, the plan ends ("Missed scheduled call").
- A planned call is possible only where a call would be (the man holds Premium, neither has Calls off).

**Privacy**
- Calls are never recorded. Silarah keeps only when calls happened and how long they lasted, for {retention} [12] months.
- If you use Guardian mode, your Guardian sees call times and lengths only.

## Messages at the moment a rule applies

| When | Message |
|---|---|
| Unanswered-call limit | "You called {name} {limit} times without an answer. You can call again after {time}. This protects members from unwanted calls." |
| Callee not reachable (any reason) | "{name} isn't taking calls right now." (never the reason) |
| Premium needed | Calls paywall: "Talk with your matches" |
| No minutes | Minute packs sheet |
| Negative balance after a refund | "Your pack balance is below zero after a refund. Add minutes to call again." |
| Refund purchase limit | "After {refunds} refunded packs, minute packs can no longer be bought on this account. Your included minutes still work." |
| Switch off or monthly brake | "Calling is paused right now. Please try again later." |
| Notifications off on this phone | "Turn on call notifications. Calls cannot ring on this phone. Your matches see that you are not taking calls." |
| Planned call missed | "Missed scheduled call" |

## What the legal text and privacy policy must cover

1. **Processor.** Call audio is carried by Stream (GetStream, Inc.), app region Mumbai (India); Stream
   processes audio in real time only to connect the call. Silarah never records audio; Stream recording,
   transcription, captions, broadcasting and video are switched off for Silarah's call type.
2. **What Silarah stores** (call metadata): who called whom (within a match), when, ring outcome
   (answered / missed / declined / not available, without telling the caller why), connected length,
   minutes held and charged, planned call times and their status, per-person call mute / block, the
   member's Ring / Silent / Off choice, whether each phone can ring, report reasons.
3. **Retention.** Call metadata 12 months, longer only while an open report between the two members
   needs it; deleted with the account. Minutes ledger (purchases, refunds, charges) is the member's
   account history and is deleted with the account. "Remove from history" hides rows for the member only.
4. **Guardian.** In Guardian mode the Guardian sees call times, lengths and planned call times, never
   content.
5. **Payments.** Minute packs are Google Play consumables (₹19 / 49 / 99 / 199 for 20 / 60 / 150 / 350
   minutes in India); packs never expire but need active Premium; refunds remove the minutes and may make
   the balance negative; after 2 refunds packs can no longer be bought; a refunded Premium period removes
   that period's included minutes.
6. **Permissions.** Microphone (asked only when starting or answering a call), notifications (to ring),
   full-screen calls on the lock screen (Android 14+ setting), Bluetooth (headsets), and Android's
   own-call management (self-managed calls) with a phone-call foreground service while a call is live.
7. **Safety.** Unanswered-call limit, per-person mute / block, reporting from calls ends the call,
   Silarah may review call metadata when handling a report.
8. **Data export** includes call history (with removed rows marked), planned calls, the call setting and
   the minutes ledger.

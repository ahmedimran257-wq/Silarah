# Voice calling — legal updates (APPROVED by the owner, 25 Nov 2026; policy bundle 2.7.0)

Status: **approved and applied** as policy bundle **2.7.0** (2.6.0 is the separate US/Canada bundle on
`expansion/us-canada`). The text below is in `lib/core/legal/legal_documents.dart` and the `site/` pages, and
migration 335 lets the server accept 2.7.0 consents. It reaches members only with the calling release
(app + migrations + website deploy together). The Play Data safety form is submitted only after the new
Privacy Policy is live.

Each addition sits inside the existing policies, which already cover the DPDP Act legal bases (consent
or a section 7 legitimate use), the IT Rules 2021 180-day preservation duty, the grievance officer and
appeals, the 30-day deletion recovery period and statutory rights. Section D maps every law that applies
to calling to the sentence that covers it.

Every statement below matches what the app and server actually do (sources: `docs/voice_calling_spec.md`
sections 3–8, 12–13; migrations 323–333). If the product changes, this text must change with it.

Plain-language rule used throughout: say exactly what happens, including the things a member may not
like (Google refunds take minutes back; what a caller can learn; what is kept after deletion).

---

## A. Privacy Policy 2.7.0 — changes

### 2. Data you provide — add

> If you use voice calling, we also collect your call settings (Ring, Silent or Calls off, and calls you
> mute or block from a particular member), the calls you plan with a match, and any report you make
> from a call.

### 3. Data generated when you use Silarah — add

> When voice calling is available to you, we process call records: who called whom, when, the result
> (answered, declined, missed or not reached), how long you talked and the call minutes used; the time a
> ring reached your phone; whether your phone can ring (notification permission and the incoming-call
> setting); your call-minute balance, minute-pack purchases, Google Play refunds of packs and any
> balance below zero; and call-quality diagnostics sent by the calling software (for example connection
> statistics and the device model).

### New section 7 — Voice calls (sections 7–13 become 8–14)

> **What calling is.** Matched members may call each other inside Silarah without sharing phone numbers.
> Calling is optional; you can use Silarah without it and set Calls off at any time.
>
> **Microphone.** Silarah asks for microphone access only when you place or answer a call, and uses the
> microphone only while a call is in progress. You can withdraw the permission in your phone's settings.
>
> **No recording.** Your voice is sent live between the two phones through our calling provider. Calls
> are **never recorded, transcribed or stored** by Silarah or the provider, no member can turn recording
> on, and Silarah staff cannot listen to calls. Reports and safety reviews use call records (times,
> results, length), never call audio.
>
> **What the other member sees.** When you call, the other member's phone shows your name and your photo
> as your photo settings allow, including on the incoming-call screen over their lock screen, so they can
> decide whether to answer. Missed-call and other call notifications on a lock screen hide the name when
> the phone's settings hide private notification content.
>
> **What a caller can learn.** Whether a ring reached the other member's phone (the call shows
> "Calling…" until it does and "Ringing…" after); and, during the other member's quiet hours, that it is
> their quiet hours and when calls will ring again. Other reasons a call does not ring — calls turned
> off, Silent, or calls from that caller muted or blocked — are never revealed; the caller sees the same
> neutral message.
>
> **Protection from unwanted calls.** If calls to the same member go unanswered three times in a day
> (counting calls that reached their phone and calls they refused by their own settings), the caller
> cannot call that member again until the next day. Calls to a phone that was offline or in quiet hours
> do not count. You can report a member from the call screen.
>
> **Guardians.** A properly linked guardian sees the time and length of a member's calls, never their
> content.
>
> **Legal basis.** We process call data with your consent, which you give when you accept the calling
> terms and choose to call or receive calls. You can withdraw it by setting Calls off; call records
> already made are then kept only as described under Retention.

### 7 (now 8). Service providers and disclosures — add

> Stream (Stream.io, Inc.) for real-time voice-call transport and the call records it needs to run a
> call. It receives your Silarah member identifier and your first name with initial, and relays call
> audio without recording it. Minute packs, like subscriptions, are sold through Google Play with
> RevenueCat; Silarah never sees your card or bank details. Call records may be disclosed when lawfully
> required, in the same way as other data under this section.

### 8 (now 9). International processing — add

> Call audio and call data are routed through Stream's servers in India. Stream may access data from
> other countries under its contractual and security obligations.

### 9 (now 10). Retention — add

> Call records (who called whom, when, the result, talk time and minutes) are kept for 12 months and
> then deleted, except while an open report or a lawful order needs them longer. They are deleted with
> your account, except records that law requires us to preserve (see above), which are deleted when that
> period ends. Removing a call from your history hides it from you only; the record is kept for the
> same period for safety. Minute-pack purchase and refund records are kept as transaction records for
> the periods tax and payment law require. Call audio is never recorded or stored.

### 10 (now 11). Security — add

> Call audio is encrypted in transit between your phone and our calling provider. It is not end-to-end
> encrypted: it passes through the provider's servers to reach the other member, where it is relayed and
> not stored.

### 11 (now 12). Your rights and choices — add

> Your call history and a summary of your call minutes (packs bought, refunded and used) are included in
> the data export. You can turn calls off, set Silent, mute or block calls from a member, and change your
> quiet hours at any time.

---

## B. Refund Policy — full new text (subscriptions and minute packs)

The current Refund Policy (v2.5.0) covers subscriptions only. This replaces it, keeping every rule it
already has and adding minute packs under the same rule: **Silarah refunds only its own mistakes.**

Why "a charge you did not authorise" stays in the list: keeping money from a stolen card or a charge the
account holder never made is not allowed under Indian consumer and payment rules, and Google reverses
such charges anyway. It is the one case that is not Silarah's mistake but still has to be refunded.

> **Summary:** Silarah subscriptions and call minute packs are non-refundable. We refund only our own
> mistakes (a double charge, a wrong amount, or a fault on our side) and charges you did not authorise.
>
> **1. Purchases are final.** Subscription payments and call minute packs are final and non-refundable
> once the purchase is completed, including for any unused part of a billing period and any unused
> minutes. The price, billing period, renewal terms and pack size are shown by Google Play and on the
> purchase screen before you pay.
>
> **2. When we do not refund.** We do not refund because you changed your mind, did not find a match, did
> not receive interests, replies or calls, did not use Premium or your minutes, a member did not answer
> or ended a call, found a member incompatible, became engaged or married, forgot to cancel before a
> renewal, uninstalled the app, paused or deleted your account, or lost access after we enforced the
> Terms of Service or Community Guidelines.
>
> **3. When we do refund.** We refund only when: you were charged more than once for the same
> subscription period or the same pack; a charge is confirmed as not authorised by you; you were charged
> a different amount from the price shown at purchase; minutes you paid for were never added to your
> account and we could not add them within a reasonable time after you reported it; or Premium did not
> work for a substantial part of the paid period because of a fault on Silarah's side that we could not
> fix within a reasonable time after you reported it. The refund covers the duplicate, unauthorised or
> excess amount, the missing pack, or the affected part of the period, and is paid through Google Play to
> the original payment method. If a fault on our side used call minutes wrongly (for example on a call
> that never connected), we give those minutes back to your balance.
>
> **4. How minutes are used.** Only the caller's minutes are used, and only for time both members were
> connected, counted per started minute. A call that does not connect uses no minutes. Premium's included
> minutes are used before pack minutes. Pack minutes do not expire, but you need active Premium to use
> them; if Premium ends, they are kept for when you renew.
>
> **5. Google Play refunds.** Payments are processed by Google Play, not by Silarah, and Silarah never sees
> your card or bank details. Google Play may independently grant a refund under its own policies; for
> example, Google offers a refund request flow for many purchases made within 48 hours. Those decisions
> are made by Google and are outside this Policy. When a purchase is refunded, by Google or by us, what it
> paid for is removed: a refunded subscription ends that Premium access and removes that period's included
> call minutes; a refunded pack removes that pack's minutes from your balance. If you had already used
> those minutes, your pack balance goes below zero, and you cannot place calls (with pack or included
> minutes) until you add minutes; the next pack you buy first makes up the difference. If Google reverses
> a refund, the minutes come back.
>
> **6. How to request an eligible refund.** Email support@silarah.com from your Silarah account email,
> preferably within 30 days of the charge, with the Google Play order ID (it begins with GPA.), the charge
> date and a short description. We may ask for proportionate evidence, such as a screenshot showing both
> charges. Never send card numbers, bank details, passwords or OTP codes. Later requests are considered
> where the law requires it.
>
> **7. Cancellation and renewal.** You can cancel at any time in Google Play under Payments &
> subscriptions, or through Manage Subscription in the app. Cancelling stops the next renewal; you keep
> Premium until the end of the period you already paid for, and that period is not refunded. Uninstalling
> the app, pausing a profile or deleting a Silarah account does not cancel Google Play billing. A free
> trial, if offered, becomes a paid subscription unless cancelled before the deadline shown.
>
> **8. Account deletion and pause.** Paid call minutes remaining when an account is deleted are lost and
> are not refunded; the app shows how many you have before you confirm deletion. Pausing a profile keeps
> them.
>
> **9. Changes to Premium or calling.** We may add, change or retire individual Premium features, including
> calling, as the Service develops. If a change materially reduces what you paid for during an active
> period, or calling is withdrawn while you hold paid pack minutes, we will offer a reasonable remedy,
> such as an equivalent feature, extra time or a proportionate refund, where applicable law requires it.
>
> **10. Contact.** Billing questions: support@silarah.com. Formal complaints: grievance@silarah.com.
> Nothing in this Policy affects non-waivable statutory rights, including under the Consumer Protection
> Act, 2019.

---

## C. Terms of Service — add a calling section

> **Voice calls.** Voice calling is available between matched members as described in the app and the
> Privacy Policy. The caller needs Premium and available call minutes, and only the caller's minutes are
> used. Women can answer calls without Premium; men need Premium to place or answer calls. Answering a
> call never uses minutes.
> You must not record, transcribe or share a call without the other member's consent, use calls to
> harass, threaten or pressure anyone, or use calls for commercial purposes. We may limit, pause or end
> calls (including during a call) to protect members, enforce these Terms, respond to a report, ban or
> pause, or when calling is switched off or under maintenance; minutes are charged only for time already
> connected. Calling may not be available in every country, on every device, or at all times.
>
> **Not a phone service.** Silarah calls work only between Silarah members over the internet. They do not
> connect to phone numbers and **cannot be used to call emergency services**; use your phone's own dialler
> in an emergency. Call quality depends on your internet connection, and Silarah is not liable for calls
> that drop or cannot connect for reasons outside its control.

---

## D. How each law is covered

| Law or rule | What it requires for calling | Where it is covered |
|---|---|---|
| DPDP Act 2023, s.5–6 (notice, consent) | Clear notice of what is collected and why; consent that can be withdrawn | New section 7; calling terms accepted before the first call (consent version); Calls off withdraws |
| DPDP Act s.8(7) and DPDP Rules 2025, Rule 8(3) (in force about May 2027) | Erase data when no longer needed, but keep processing logs at least 1 year | 12-month call-record retention; deletion wording keeps records "law requires us to preserve" (see the action below) |
| DPDP Act s.8(5)–(6) (security, breach) | Reasonable safeguards; report breaches | Section 10 (now 11) adds encryption in transit; existing breach process applies |
| DPDP Act s.5(3) (notice languages) | Notice available in English or an Eighth Schedule language on request | See the action below (Hindi, Bengali, Urdu are already app languages) |
| DPDP Act s.9 (children) | No processing of children's data without parental consent | Silarah is 18+ only (existing Terms and sign-up) |
| IT Act s.79 and IT (Intermediary) Rules 2021, Rule 3 | Due diligence, rules against harassment, 180-day preservation, grievance officer | Terms calling section (conduct); existing Grievance Policy and retention text |
| IT Rules 2021, Rule 3(1)(h) | Keep registration data 180 days after an account ends | Existing retention text plus the new deletion wording |
| Consumer Protection Act 2019 and E-Commerce Rules 2020, Rules 4–6 | Show price, refund terms and complaint route before purchase; no unfair terms | Packs sheet now says "non-refundable, except as set out in the Refund Policy" with the policy a tap away; Google Play shows the price with taxes; statutory rights line in Refund Policy |
| CCPA dark-patterns guidelines 2023 | No hidden costs, drip pricing or confusing refund claims | Price shown by Google Play before payment; minutes card shows balance and use; refund messages now name Google Play |
| Telecommunications Act 2023 | Licence for telecom services | The Department of Telecommunications has said internet calling apps such as WhatsApp are not regulated under the Act; Silarah calls never connect to phone numbers. Terms add "Not a phone service" and no emergency calls |
| IT Act s.43A, 72A | No disclosure of personal data without consent | Calls are never recorded; staff cannot listen; Stream relays only |
| Google Play policies (User Data, Payments, Foreground service) | Prominent disclosure, Play Billing for digital goods, Data safety form matches the policy | Packs use Play Billing; demo video recorded; Data safety filled only after this policy is live |

### Actions to finish before calling goes live in production

1. **Stream data processing agreement**: accept Stream's DPA in the Stream dashboard (free, part of their
   terms) and confirm the production app's region is India (Mumbai), as on staging.
2. **Translated notices**: publish the calling sections in Hindi, Urdu and Bengali as well as English
   (DPDP s.5(3)). I can prepare these from the approved English text.
3. **Before May 2027 (DPDP Rule 8(3))**: change account deletion so call records are kept 1 year from
   the call (access-restricted) instead of being deleted at once. The policy wording above already
   allows this, so only the code changes then.
4. **Renewed acceptance**: raise the calling consent version so every member accepts the new calling
   terms once before their first call.

Limits I want you to know: these drafts follow the laws as published up to November 2026 and match what
the app does today. No document can rule out every complaint; what protects you is that the policy says
exactly what the app does and the app keeps doing it. If the product changes, update this text in the
same release.

---

## E. App wording fixed with this change (no legal change)

- Every refund message now names Google Play ("…because Google Play refunded a pack"), so none can be
  read as Silarah offering refunds. Server notices say the same.
- The packs sheet shows "Minute packs are non-refundable, except as set out in the Refund Policy" with
  a Refund Policy link before purchase; the calling guide says the same.
- The "no packs after 2 refunds" rule is gone (migration 334). It hid the buy buttons, so a member whose
  refund left the balance below zero could never top up or call again, even with Premium's included
  minutes. Now a Premium member can always top up; the next pack makes up the refunded minutes first,
  so nobody gains free minutes from refunds. The refund count is kept for records and safety review.
- All in 10 languages. The Refund Policy text itself changes only after you approve section B.

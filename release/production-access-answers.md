# Play Console — production access questionnaire (draft answers)

Based on the Testers Community report of 25 Nov 2026, rewritten so every answer matches what was really
done. Edit anything marked **[you]** before pasting; Google compares these answers with the app.

**1) How did you recruit users for your closed test?**
We used a paid testing provider (Testers Community) for broad device and Android-version coverage, and
we tested ourselves daily on two physical phones (OnePlus and Redmi) with separate test accounts.
**[you]** add friends, family or community members if you also invited them.

**2) How easy was it to recruit testers?** **[you]** pick: Easy / Neither / Difficult.

**3) Describe the engagement you received from testers.**
Testers used the app across many devices and Android versions and reported no crashes or functional
bugs. They sent a written report with usability suggestions: protecting against accidental exits, sharing
the app, rating it, and the store description. Alongside that, we ran our own structured test lists on
real phones every day (sign-up, profiles, interests, chat, photos, payments, notifications, languages,
large text and right-to-left layouts) and fixed what we found.

**4) Summary of the feedback and how you collected it.**
Feedback came as a written report from the testing provider plus our own test lists and crash reports
(Firebase Crashlytics). Testers asked for: a safeguard against leaving the app with one Back press, a
"Share app" option, a "Rate app" option in Settings, and a store description with clearer keywords.

**5) Intended audience.**
Adult single Muslims in India, and their families, looking for a life partner for nikah, across sects,
communities and languages.

**6) How does your app provide value?**
A respectful, privacy-first Muslim matrimony app: profiles built around faith, family and marriage
intentions; photo privacy controls (public, after mutual interest, or on approval); optional photo
verification with human review; a guardian (wali) mode; messaging only after both people accept; no
phone number required; and full block, report, pause and delete controls.

**7) Expected installs in the first year.** **[you]** pick (the provider suggested 10k–100k).

**8) What changes did you make based on the closed test?**
- Back on the main screen no longer closes the app at once: the first press shows "Press back again to
  exit" and only a second press within two seconds leaves (Back on other tabs returns to Discover first).
- Settings now has "Share Silarah" (shares an invite with the member's referral code) and "Rate
  Silarah" (opens the Google Play listing).
- The store description was refined with clearer, natural keywords.
- **[you]** add the other fixes from your own test rounds if you want (for example the issues found in
  the 20 and 21 November device test lists).

**9) How did you decide the app is ready for production?**
No crashes or functional bugs were reported by testers or Crashlytics during the test; every core flow
(sign-up, profile, discovery, interests, chat, photos, Premium purchase and restore, notifications,
account pause and deletion) passed on real phones; the tester suggestions are built and tested; and the
privacy policy, data safety and content declarations match what the app does.

**10) What did you do differently this time?** **[you]** — only if this is not your first production
request; otherwise say this is the first application.

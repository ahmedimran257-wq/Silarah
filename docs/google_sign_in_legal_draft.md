# Continue with Google — Privacy Policy draft (needs owner approval)

Status: **approved by the owner on 29 Nov 2026; migration 345 applied on staging and a staging sign-up recorded all five consents at 2.8.0. Not on production, website not deployed.** The app text (`legal_documents.dart`), every page under `site/`, the hi/ur/bn summaries (`legal_translations.dart`) and migration `345_policy_280_google_sign_in.sql` are ready. Migration 345 is applied on **staging only** (recorded as version 345 in the migration history). Effective date: **29 November 2026** (published the evening of 28 November with build 1.1.1+50300).

Remaining order: apply 345 on production **before** the app update and website go live (backend first, as with 2.7.0). Then deploy the site and release the app.

## Is a change needed?

Yes, before Google sign-in reaches members:

1. **New source of data.** Today the policy describes "verified email and authentication information" and "Supabase for verified-email authentication". With Google sign-in, Google sends us data about the member: name, email address, whether the email is verified, a profile-photo link and a Google account identifier (the ID token's `name`, `email`, `email_verified`, `picture`, `sub`). Supabase Auth stores these with the login (`auth.identities` and the user's metadata). DPDP Act 2023 section 5 requires the notice to describe the personal data processed.
2. **Google's own rule.** The Google API Services User Data Policy, which the OAuth consent screen accepts, requires a privacy policy that discloses how the app accesses, uses and shares Google user data. The consent screen also needs this policy's URL.
3. **Play Data safety.** The data types (name, email address, user IDs) are probably already declared. The owner must check (see the end of this note).

What the app does **not** do: it does not use the Google name or photo for the Silarah profile (members still enter their name and upload photos in onboarding). It asks only for the basic `openid email profile` sign-in scopes, does not read contacts, Drive, Gmail or any other Google data, and keeps no Google access or refresh token (only the one-time ID token goes to Supabase).

## Proposed text

### Section 2, "Data you provide": a new bullet in site/privacy/index.html, and the same sentence in the app (`LegalDocuments.privacy`, section 2)

> If you choose Continue with Google, Google shares your name, email address, profile-photo link and Google account identifier with Silarah when you sign in. We use the verified email address to create your account or sign you in, and keep these details with your login record. We do not use your Google name or photo for your Silarah profile, and we do not access your contacts, files or any other Google account data.

### Section 8, "Processors and disclosures": add Google as a sign-in provider

Current: "We use Supabase for verified-email authentication, …"

Proposed: "We use Supabase for verified-email authentication, including sign-in with Google, …" and, after the Google Firebase clause: "Google for Continue with Google sign-in, where you choose it;"

### Section 12, "Your rights and choices": one sentence

> You can remove Silarah's access to your Google account at any time in your Google Account under Security → Your connections to third-party apps and services; you can still sign in with the email-code option.

### Retention / deletion

No new text is needed: the Google identity is part of the login record and is deleted with the account under the existing Data Deletion Policy. **Owner check:** confirm that account deletion also deletes `auth.identities` rows (it does when the auth user is deleted).

## Version and rollout (if approved)

- This is a material addition to the notice, so make it **2.8.0** with a new effective date, shipped in the first update after launch together with Google sign-in. Do not edit 2.7.0 in place.
- Follow the 2.7.0 pattern: backend first, then the client.
  - A migration like `335_policy_270_voice_calling.sql` that adds `'2.8.0'` to the accepted versions of `begin_signup_consent_transaction`, `finalize_signup_consents`, `sync_my_user`, the reminder functions and the export, and makes 2.8.0 the current notice. Staging first, then production with the owner's approval.
  - `LegalDocuments.version = '2.8.0'` and the new `effectiveDate`. Update `site/privacy/index.html` (eyebrow line plus the three changes above), `site/legal/` and the other pages that print the version.
  - Translations of the changed paragraphs in `legal_translations.dart` (hi, ur, bn, like 2.7.0).
  - Contract tests: `legal_policy_completeness_test.dart` (version, date, app and site aligned). Add an expectation that both the app and the site mention "Continue with Google" and "do not access your contacts". Also `legal_translations_test.dart` and `public_site_launch_readiness_test.dart`.
  - Existing members get the normal policy reminder. No re-consent is needed for an optional sign-in method, but the owner decides that.

## Play Console Data safety (owner)

Google sign-in does not add a new data type if these are already declared: **Personal info → Name, Email address, User IDs**, collected and not shared, required for account management. If "Name" is declared only as "provided by the user", it still fits: the Google name is received but not used for the profile. No change to "Photos": a profile-photo *link* is stored, not the photo itself, and it is not used. Check the form when the update with Google sign-in is submitted.

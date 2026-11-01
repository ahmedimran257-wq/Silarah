# Google Play Data safety worksheet

This is a conservative implementation-based worksheet, not legal advice. Recheck
every answer against the exact production build and the current Play Console
wording immediately before submission.

## Global declarations

- Data is encrypted in transit: **Yes** (HTTPS/TLS and Supabase secure channels).
- Users can request deletion: **Yes** (in-app deletion plus
  `https://silarah.com/data-deletion/`).
- Users can download their data: **Yes** (authenticated in-app ZIP export plus
  assisted requests through `https://silarah.com/privacy-rights/`).
- Account creation is supported: **Yes**.
- Independent security review: **No**, unless a qualifying audit is completed.
- Data is sold: **No**.
- Third-party behavioural advertising: **No**.

## Data collected

| Play category | Examples in Silarah | Collected | Shared | Purpose | Required |
| --- | --- | --- | --- | --- | --- |
| Name | First/last name, profile identity | Yes | Service providers | Account, matching, safety | Yes |
| Email address | Sign-in and service contact | Yes | Supabase, Brevo | Authentication, account, transactional messages | Yes |
| User IDs | Supabase user/profile/device IDs | Yes | Service providers | Account, security, analytics-free operations | Yes |
| Address/location | City, state, country, coordinates | Yes | Supabase; location lookup provider receives query/location | Matching, app functionality | City/country required; precise device location optional |
| Photos | Profile photos and temporary optional photo-check captures | Yes | Supabase; on-device ML does not upload model input | Profile, safety, verification | Profile photo required; photo check optional |
| Personal info | DOB/age, gender, marital/family details, faith, education, work, income preferences, languages, bio | Yes | Supabase | Profile and matching | Mix of required and optional |
| Messages | Chats, interests, reports and guardian data | Yes | Supabase | App functionality and safety | Feature-dependent |
| Purchase history | Product, entitlement, transaction status, price/currency metadata | Yes | Google Play, RevenueCat, Supabase | Purchases, entitlement, support, fraud prevention | Purchase-dependent |
| App activity | Interests, matches, profile views, saved profiles, notification state | Yes | Supabase | App functionality, personalization, security | Feature-dependent |
| App info/performance | Crash traces, device/app diagnostics | Yes | Firebase Crashlytics | Stability and security | Automatically collected in production |
| Device or other IDs | FCM token, installation and Play Integrity/App Check identifiers | Yes | Firebase/Supabase | Notifications, security, abuse prevention | Automatically or device dependent |

## Handling notes for Console answers

- Mark data as **ephemeral** only when code truly processes it in memory and does
  not persist it. Profile photos, chat, IDs, reports and transaction records are
  not ephemeral.
- On-device ML Kit/TFLite processing alone is not third-party sharing because
  the image stays on the device. The later upload to Supabase is collection.
- Chat translation was retired (migration 259); no message text is sent to a
  translation service.
- Government-ID collection and matching are not present in this build. The
  optional photo check uses temporary look/smile/blink captures for authorized
  human comparison and deletes them after review and no later than 48 hours.
- The self-service export redacts credentials and confidential third-party or
  anti-abuse material. An assisted privacy route remains available for omitted
  categories and legally required explanations.
- Do not select advertising or marketing purposes for transactional email or
  FCM unless marketing campaigns are actually enabled in the submitted build.

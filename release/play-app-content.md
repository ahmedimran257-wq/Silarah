# Google Play App content worksheet

Complete this against the exact release candidate. It records the intended
answers; the Play Console submission itself remains the source of truth.

## Audience and availability

- Target audience: adults **18 and over only**.
- Child-directed: **No**.
- Release availability: **India only, Android only**.
- Ads: **No third-party advertising** in the submitted build.
- App category: Dating / Matrimony.

## User-generated content and safety

- Members can upload profile photos and send messages after a mutual match.
- Report and block are available from member profiles and conversations.
- Published photos pass moderation controls; optional profile-photo
  verification uses temporary look/smile/blink evidence and human review.
- Community Guidelines: `https://silarah.com/community-guidelines/`
- Child Safety Standards: `https://silarah.com/child-safety/`
- Safety contact: `safety@silarah.com`

For the content-rating questionnaire, answer the current Play wording
truthfully for matrimony/dating, user interaction, messaging and user-generated
photos. Do not describe the app as child-accessible or as guaranteeing identity.

## App access

- Authentication is required.
- Enter the two synthetic reviewer accounts described in
  `release/reviewer-instructions.md` only in Play Console.
- Reconfirm the stable review inbox, male reviewer test Premium grant, female free
  messaging and prepared synthetic conversation immediately before submission.
- Do not store reviewer credentials in this repository.

## Privacy and account controls

- Privacy policy: `https://silarah.com/privacy/`
- Data safety worksheet: `release/data-safety.md`
- Account deletion URL: `https://silarah.com/delete-account/`
- In-app deletion: Profile → Settings → Delete account.
- Data download: Profile → Settings → Download my data.
- Data encrypted in transit: **Yes**.
- Data sold: **No**.
- Independent security review: **No**, unless a qualifying audit is completed.

## Declarations to verify in Console

- [ ] Data safety answers match Firebase App Check/Play Integrity, push,
      Crashlytics and the exact transactional-email architecture in
      the submitted build.
- [ ] Ads declaration says no ads.
- [ ] Target audience is 18+ only.
- [ ] Content rating includes dating/matrimony, chat and UGC accurately.
- [ ] App access contains working reviewer credentials and OTP instructions.
- [ ] Account deletion URL and in-app path both work.
- [ ] Privacy policy is public, HTTPS, and names the same operator/contact as
      the verified developer account.
- [ ] Child-safety and UGC moderation declarations are complete.
- [ ] Support email and website match the store listing.

## Developer identity alignment

Before submission, compare the verified Play developer profile with the public
operator details in `/legal/`, `/terms/` and `/privacy/`. The legal name,
displayed developer name, postal address, support email and privacy contact must
refer to the same operator. Record the check in the release ticket; do not add
private identity documents to Git.

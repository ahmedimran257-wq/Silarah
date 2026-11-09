/// Versioned legal notices shown in the app.
///
/// The public HTML versions live under `site/` and are contract-tested against
/// these identifiers, titles, version and effective date. Policy changes must
/// update both surfaces and bump [LegalDocuments.version].
class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String id;
  final String slug;
  final String title;
  final String summary;
  final List<LegalSection> sections;
}

abstract final class LegalDocuments {
  static const version = '2.5.0';
  static const effectiveDate = '24 October 2026';
  static const operatorName = 'Silarah';
  static const grievanceOfficerName = 'Silarah Grievance Desk';
  static const supportEmail = 'support@silarah.com';
  static const privacyEmail = 'privacy@silarah.com';
  static const safetyEmail = 'safety@silarah.com';
  static const grievanceEmail = 'grievance@silarah.com';

  static const terms = LegalDocument(
    id: 'terms_of_service',
    slug: 'terms',
    title: 'Terms of Service',
    summary:
        'The contract governing eligibility, accounts, subscriptions, safety, content and use of Silarah.',
    sections: [
      LegalSection(
        '1. Agreement and incorporated policies',
        'These Terms form a binding agreement between you and Silarah, operated in India, for use of the Silarah mobile application, website and related services (the “Service”). By creating an account, accessing the Service or purchasing a subscription, you accept these Terms and the Privacy Policy, Privacy Rights and Grievance Policy, Community Guidelines, Refund Policy, Data Deletion Policy, Verification Policy, Photo Moderation Policy and Guardian/Wali Policy. If you do not accept them, do not use the Service.',
      ),
      LegalSection(
        '2. Eligibility and purpose',
        'You must be at least 18 years old, legally capable of entering this agreement and legally permitted to marry under the law that applies to you. Silarah is intended for adults seeking a genuine matrimonial introduction. It is not an escort, casual-dating, employment, immigration, fundraising or financial-services platform. You may not use the Service if we previously terminated you for a serious safety violation unless we give written permission.',
      ),
      LegalSection(
        '3. Your account and information',
        'You must provide accurate, current information about your identity, age, marital status, location and matrimonial intentions. You are responsible for safeguarding authentication codes and devices and for activity under your account. Do not create an account for another adult without their knowledge and authority. Notify support@silarah.com promptly if you suspect unauthorized access. We may require reverification when information changes or safety risk is detected.',
      ),
      LegalSection(
        '4. Profiles, photos and your licence to us',
        'You retain ownership of content you submit. You grant Silarah a worldwide, non-exclusive, royalty-free licence to host, copy, process, adapt for technical display, moderate and show that content only as needed to operate, secure and improve the Service. The licence ends when the content or account is deleted, except for cached copies and records we must retain for safety, disputes or law. You represent that you have the rights and permissions needed for everything you upload, including images of other people.',
      ),
      LegalSection(
        '5. Discovery, interests and communication',
        'Discovery and compatibility results are recommendations based on information and preferences members state; they are not personality, character, safety or marriage-outcome assessments. Compatibility explanations may omit criteria that either member did not specify and do not reveal another member’s private preference values. Limits on interests, messages, boosts and other features may vary by plan, gender-based product rules, safety state and region, and are displayed in the app before use or purchase. A match or accepted interest does not establish endorsement, identity certainty, compatibility or consent to off-platform contact. Respect blocks, withdrawals and requests to stop communicating.',
      ),
      LegalSection(
        '6. Verification and guardians',
        'Photo, email, account-history and guardian trust checks reduce certain risks but do not establish legal identity and do not constitute a criminal, financial, employment, immigration or comprehensive background check. A badge is not a guarantee that every statement is true or that a member is safe. Guardian mode is optional product functionality and is not legal advice or a determination that a particular wali arrangement is valid under religious or civil law. The separate Verification and Guardian/Wali Policies apply.',
      ),
      LegalSection(
        '7. Subscriptions, renewal and cancellation',
        'Paid plans, included features, total price, currency, billing period, trial (if any) and renewal terms are shown before purchase. Premium features may include explainable compatibility insights, private shortlist organization and Incognito Discovery. Incognito limits appearance in general discovery and search while it is enabled and Premium remains active; it does not hide you from people with whom you already interacted, matched, shared photo access or established a guardian relationship. Google Play subscriptions renew automatically at the price and frequency displayed by Google Play until cancelled there. Use the in-app Manage Subscription link or Google Play Subscription Center before the renewal date shown in Google Play. Removing the app, pausing a profile or deleting a Silarah account does not cancel store billing. Cancellation stops future renewal and ordinarily leaves access until the paid period ends; the current period is not refunded. Subscription payments are non-refundable except as set out in the Refund Policy or required by law. Premium improves access to stated features but never guarantees an interest, match, response, meeting or marriage.',
      ),
      LegalSection(
        '8. Prohibited conduct',
        'You must not misrepresent identity or intentions; solicit money, gifts, investments, visas or commercial services; harass, threaten, stalk or discriminate; sexualize, exploit or endanger anyone; share intimate or private material without consent; upload unlawful, infringing or malicious content; scrape, sell or build databases of member data; reverse-engineer or bypass access, moderation, subscription or rate limits; automate outreach; manipulate reports or verification; or use the Service for any unlawful purpose. The Community Guidelines provide further detail.',
      ),
      LegalSection(
        '9. Safety action and appeals',
        'We may limit content, visibility, messaging or features; require verification; preserve evidence; suspend, shadow-limit or terminate accounts; and report matters to stores, payment providers or authorities when reasonably necessary to enforce these Terms, protect people, investigate fraud or comply with law. Some urgent action may occur without advance notice. You may appeal a decision through the in-app support route or safety@silarah.com. We review appeals in good faith but do not guarantee restoration.',
      ),
      LegalSection(
        '10. Account closure and deletion',
        'You may pause visibility or request deletion in Settings. A deletion request enters a 30-day recovery period and is then permanently processed, subject to limited lawful retention described in the Data Deletion and Privacy Policies. We may close inactive or unsafe accounts. Provisions that by nature survive—such as payment obligations, content responsibility, disclaimers, liability limits, dispute terms and lawful retention—continue after closure.',
      ),
      LegalSection(
        '11. Service and member disclaimers',
        'Silarah provides an introduction and communication service on an “as available” basis. We do not arrange or guarantee a meeting, relationship or marriage; verify every claim; control member conduct off-platform; or promise uninterrupted or error-free operation. We may change, suspend or discontinue any feature, plan or part of the Service, with notice where reasonably practicable. Always use independent judgment, protect financial and identity information, involve trusted people where appropriate, meet safely and report concerns. Nothing in these Terms excludes warranties or rights that cannot lawfully be excluded.',
      ),
      LegalSection(
        '12. Liability',
        'To the maximum extent permitted by law, Silarah is not liable for indirect, incidental, special, consequential or punitive loss, loss of opportunity, or conduct of another member. Our aggregate liability arising from the Service will not exceed the greater of the amount you paid Silarah in the 12 months before the event or the minimum amount required by applicable law. These limits do not apply to fraud, wilful misconduct, death or personal injury caused by negligence, or any liability that law does not permit us to limit. To the extent permitted by law, you are responsible for loss Silarah suffers because of your breach of these Terms, unlawful use of the Service or content you post.',
      ),
      LegalSection(
        '13. Governing law and disputes',
        'These Terms are governed by the laws of India, without depriving you of mandatory consumer protections in your country of residence. Before filing a claim, contact grievance@silarah.com and allow 30 days for a good-faith resolution, unless urgent relief is needed. Courts of competent jurisdiction in India will have non-exclusive jurisdiction, subject to any mandatory local forum rights.',
      ),
      LegalSection(
        '14. Changes and contact',
        'We may update these Terms for legal, safety or product reasons. Material changes will be notified in the app or by email and, where required, we will request renewed consent. The version and effective date appear above. Product questions: support@silarah.com. Formal grievances: grievance@silarah.com.',
      ),
    ],
  );

  static const privacy = LegalDocument(
    id: 'privacy_policy',
    slug: 'privacy',
    title: 'Privacy Policy',
    summary:
        'What Silarah collects, why it is used, who processes it, how long it is kept and the choices available to you.',
    sections: [
      LegalSection(
        '1. Scope and controller',
        'This Policy applies to the Silarah app, silarah.com and related support, safety and verification operations. Silarah is operated in India and is the data fiduciary responsible for deciding why and how personal data is processed. Privacy questions and rights requests may be sent to privacy@silarah.com; the Silarah Grievance Desk receives formal grievances at grievance@silarah.com.',
      ),
      LegalSection(
        '2. Data you provide',
        'We collect account identifiers and contact details; date of birth, gender, marital and family information; city, region, country and optional approximate device location; education, occupation, income-range and lifestyle information; biography, partner preferences and matrimonial timeline; religious information such as sect and practice; photos and verification submissions; interests, bookmarks, private shortlist categories, private notes and reminder dates; blocks, reports, support messages and guardian details; and content you send through chat. Shortlist notes are visible only to the account that writes them. Do not place passwords, OTPs, payment details, government identifiers, private contact details or information you do not have authority to provide in a note or profile.',
      ),
      LegalSection(
        '3. Data generated when you use Silarah',
        'We process authentication and consent records, device and app version, notification tokens, language and settings, feature activity, matches, message delivery and typing state, moderation and fraud signals, subscription status and transaction events, crash diagnostics, IP-derived security information, timestamps and audit logs. Approximate device location is requested only for location-based discovery and can be denied; city-based discovery remains available.',
      ),
      LegalSection(
        '4. Sensitive and verification data',
        'Religious beliefs, temporary verification captures and some matrimonial information may be sensitive under applicable law. We use religious information for compatibility only with explicit consent where required. The optional photo check creates three temporary guided captures for an authorized human to compare with the current profile photo. We do not create facial embeddings or templates, perform government-ID matching, estimate age from a face, or use these captures for advertising.',
      ),
      LegalSection(
        '5. Purposes and legal bases',
        'We use data to create and secure accounts; provide discovery, explainable compatibility, interests, messaging, private shortlists and reminders, Incognito, photo privacy, guardian and subscription features; personalize results; perform verification and moderation; deliver service and safety notifications; prevent abuse and fraud; provide support; maintain records; diagnose failures; and comply with law. Compatibility uses stated profile and preference fields and returns only a criterion-level explanation, not another member’s raw preferences. For processing in India under the Digital Personal Data Protection Act when its relevant provisions apply, we rely on consent or a specific statutory legitimate use under section 7 whose conditions are met. A contract or a general business or safety interest is not, by itself, a DPDP legal basis. Any processing or retention required or authorised by another applicable Indian law is limited to that law and purpose. Other jurisdictions may confer additional rights. You may withdraw consent prospectively; we will explain any resulting feature limits and any processing that law requires or permits to continue.',
      ),
      LegalSection(
        '6. Visibility to other members and guardians',
        'Profile fields you choose to publish are visible to eligible registered members according to discovery and privacy settings. Incognito removes a profile from general discovery and name/city search while the setting is effective, but it cannot make prior interactions anonymous: people with an existing interest, match, permitted photo-access relationship or connected guardian relationship may continue to access the profile as needed for that relationship. Photos follow your selected mode: public, visible after mutual interest, or request-to-view. Private shortlist categories, notes and reminders are visible only to their author and are never shown to the saved member or that member’s guardian. Messages are visible to conversation participants and may be visible to a properly linked guardian where guardian chat mirroring is enabled. Reports disclose necessary content to authorized safety staff, not to the reported member except as needed for a fair process.',
      ),
      LegalSection(
        '7. Service providers and disclosures',
        'We use vetted processors to run the Service: Supabase for verified-email authentication, database, private storage, realtime and server functions; Google Firebase for Play Integrity-backed App Check, push delivery and crash reporting; RevenueCat and Google Play for subscriptions and transaction state; Brevo for transactional email; Cloudflare for website delivery, DNS and security; Google ML Kit for on-device capture guidance and photo-safety signals; and Photon/Wikidata for location and language lookup. Chat translation is no longer offered and we do not send new messages to a translation provider. These providers process data needed for their role under their own contractual and legal obligations. We may also disclose data at your direction, during a corporate transaction, to protect people and the Service, or when lawfully required. We do not sell personal data and do not run third-party behavioural advertising.',
      ),
      LegalSection(
        '8. International processing',
        'Our providers may process data in countries other than yours. Where required, we use contractual safeguards and assess provider security and transfer mechanisms. Local law may allow public authorities to request data. Contact privacy@silarah.com for information about safeguards relevant to your region.',
      ),
      LegalSection(
        '9. Retention',
        'Active-account profile, preference, photo, match and message data is retained while needed to provide the Service. Private shortlist metadata is deleted when its bookmark is removed or the account is deleted; a one-shot reminder is marked as sent and is not repeatedly queued. Incognito preference metadata is retained with the active account so the setting can be enforced consistently across devices. A requested account enters a 30-day recovery period before purge. Temporary photo-verification captures are deleted from active verification storage after review and no later than 48 hours after submission. We retain the decision, date, reviewer audit and deletion result without retaining the captures. Information and removed content that applicable intermediary rules require us to preserve may be retained for 180 days, or longer when a lawful order requires it. Reports, blocks, transaction records, consent records, security logs and backups may otherwise remain only for applicable limitation, tax, payment, abuse-prevention and legal periods, then be deleted or de-identified. Backup deletion completes through normal provider rotation. We periodically review retention and avoid keeping identifiable data merely because it may be useful. In-app Privacy requests, responses and associated case records are retained while unresolved and for 12 months after resolution, then erased from active systems unless a documented legal hold applies. Holds are access-restricted and reviewed; after a hold ends, an already-expired case becomes eligible for erasure. Unlinking a deleted account does not anonymise the request text. Backup copies expire through provider rotation. This case-retention schedule does not extend retention of the underlying profile or authorise unrelated processing.',
      ),
      LegalSection(
        '10. Security',
        'We use encrypted transport, private storage for temporary verification captures, row-level access controls, short-lived signed media access, role-based staff access, audit logs, rate limits, backups and secret management. No online system is risk-free. Use a secure device, protect OTP codes and report suspected compromise promptly. We investigate suspected personal-data breaches, take proportionate containment and remediation steps, and notify affected people and the competent authority within the time and manner required by applicable law.',
      ),
      LegalSection(
        '11. Your rights and choices',
        'Depending on applicable law, you may access, correct, export or delete data; withdraw consent; object to or restrict processing; request portability; nominate another person where that right applies; and complain to a regulator. In-app controls let you edit your profile, change photo visibility, pause discovery, manage notifications, block members, download a machine-readable ZIP archive and request deletion. Signed-in members can open Profile → Settings → Privacy → Privacy requests for assisted access, correction, erasure, withdrawal, nomination or grievance requests and read the reference, response target and staff response there. On older app versions without this screen, or if you cannot sign in, email privacy@silarah.com; urgent safety complaints should use safety@silarah.com or the reporting tools. A withdrawal or erasure submission creates a request for staff review; it does not immediately stop processing or delete your account. Pausing discovery only limits visibility. Use existing account controls where available, or specify the consent and purpose you want to withdraw through Privacy requests or privacy@silarah.com. After proportionate verification, we will explain and carry out the applicable cessation and processor follow-up, subject to processing required or authorised by law. Withdrawal does not undo earlier lawful processing and may make a dependent feature unavailable. Store subscriptions must be cancelled separately. Selecting Nomination submits a request to arrange and verify a nomination for exercise of rights on death or incapacity where applicable; it does not appoint a nominee or complete a nomination. Staff must explain the process, verify necessary authority and confirm any completed arrangement separately. Do not put nominee identity documents or unnecessary third-party information in the request. We may proportionately verify identity before completing a request. We will respond within the legally required period and explain any lawful refusal. Email privacy@silarah.com for an omitted category or assisted request.',
      ),
      LegalSection(
        '12. Adults only',
        'Silarah is not directed to anyone under 18 and we do not knowingly allow minors to hold accounts. If you believe a minor has provided data, contact safety@silarah.com so we can investigate and remove it.',
      ),
      LegalSection(
        '13. Changes and contact',
        'Material changes will be notified in-app or by email and renewed consent will be requested where required. The effective date and version identify the applicable notice. Privacy: privacy@silarah.com. Safety: safety@silarah.com. Grievances: grievance@silarah.com.',
      ),
    ],
  );

  static const community = LegalDocument(
    id: 'community_guidelines',
    slug: 'community-guidelines',
    title: 'Community Guidelines',
    summary:
        'Behaviour and content standards designed to keep matrimonial introductions sincere, dignified and safe.',
    sections: [
      LegalSection('1. Genuine matrimonial intent',
          'Use Silarah only for serious matrimonial introductions. Casual dating, sexual services, recruitment, commercial promotion, fundraising, visa arrangements and investment solicitation are not permitted.'),
      LegalSection('2. Be truthful',
          'Use your own identity and current, authentic photos. Accurately state age, marital status, location and material circumstances. Do not impersonate, catfish, create duplicate deceptive accounts, conceal that an account is guardian-managed, manipulate verification, or use an AI-generated, face-swapped or materially altered image that misrepresents how you look.'),
      LegalSection('3. Respect and consent',
          'Communicate with adab and respect. Do not pressure anyone to reply, share photos, move off-platform, meet, marry or involve family. A match or accepted interest is not consent to sexual, abusive or persistent contact. Stop when asked and respect blocks.'),
      LegalSection('4. Sexual and exploitative content',
          'Nudity, sexual activity, fetish content, sexual solicitation, unwanted sexual messages and intimate-image abuse are prohibited. Content involving or appearing to involve a minor is forbidden and may be reported to authorities. Do not request or share intimate material.'),
      LegalSection('5. Harassment, hate and violence',
          'Threats, stalking, bullying, humiliation, coercive control, blackmail, doxxing, glorification of violence and hateful attacks based on protected characteristics are prohibited. Compatibility preferences must not be expressed as abuse or dehumanization.'),
      LegalSection('6. Money, scams and unsafe requests',
          'Never request or send money, gift cards, cryptocurrency, bank credentials or OTP codes through a matrimonial interaction. Romance scams, fabricated emergencies, investment schemes, paid matchmaking solicitation and immigration fraud result in removal and may be reported.'),
      LegalSection('7. Privacy and off-platform safety',
          'Do not publish another person’s contact, identity, chat, photo or document without authority. Use in-app chat until trust is established, verify independently, tell a trusted person before meeting and choose a public place. Silarah staff will never ask for your OTP or password.'),
      LegalSection('8. Platform integrity',
          'Do not scrape profiles, automate interests or messages, evade quotas or bans, sell accounts, abuse reports, reverse-engineer safety systems, upload malware or attempt unauthorized access. Do not use information obtained from Silarah to build lists, advertise or discriminate unlawfully.'),
      LegalSection('9. Reporting, evidence and emergencies',
          'Use block and report tools for violations. Preserve relevant messages and explain the concern honestly. False or retaliatory reports are violations. If anyone faces immediate danger, contact local emergency services; Silarah is not an emergency service.'),
      LegalSection('10. Enforcement and appeal',
          'Responses are proportionate to risk and may include warning, content removal, feature limits, verification, visibility limits, suspension or permanent termination. Serious or repeated harm can lead to immediate removal. You may appeal through safety@silarah.com with the account email and relevant facts.'),
    ],
  );

  static const childSafety = LegalDocument(
    id: 'child_safety_standards',
    slug: 'child-safety',
    title: 'Child Safety Standards',
    summary:
        'The adult-only eligibility, reporting, review and enforcement standards used to prevent child sexual abuse and exploitation.',
    sections: [
      LegalSection(
        '1. Adults only',
        'Silarah is strictly for adults aged 18 and over. Members must be legally able to use the service, and adults may not create matrimonial profiles for minors. An account belonging to, representing or appearing to represent a person under 18 may be restricted while age is assessed. Attempts to conceal age, provide a false date of birth or help a minor evade eligibility controls are prohibited.',
      ),
      LegalSection(
        '2. Zero tolerance for exploitation',
        'Silarah prohibits grooming, sexualization of minors, solicitation, trafficking, sextortion, child sexual abuse material (CSAM), synthetic or altered exploitative imagery, requests for such material, and links, instructions or communities that facilitate abuse. This prohibition applies to profiles, photos, biographies, interests, messages, external links and any other feature of the Service.',
      ),
      LegalSection(
        '3. Content and conduct',
        'Members must not upload, request, send, describe, promote, normalize, trade or threaten to distribute exploitative content involving a minor. Attempts to move a suspected minor off-platform, conceal an age concern, evade a safety restriction, intimidate a reporter or preserve prohibited material for personal use are serious violations. Apparent joking, role-play or coded language does not excuse conduct that creates a child-safety risk.',
      ),
      LegalSection(
        '4. Reporting and immediate danger',
        'Members can block and report a profile or conversation in the app and may contact safety@silarah.com for a child-safety concern. Reports should identify the relevant account and explain the concern without downloading, forwarding or redistributing suspected CSAM. If a child is in immediate danger, contact local emergency services or the appropriate child-protection authority first; Silarah is not an emergency service.',
      ),
      LegalSection(
        '5. Review and enforcement',
        'We may immediately restrict access, preserve necessary evidence, remove content, suspend or permanently ban accounts, prevent re-registration and escalate serious matters. Safety action may occur without advance notice when needed to protect a child, prevent distribution or preserve an investigation. A report is assessed using the available account, content, device, moderation and behavioural context, with access limited to authorized safety handling.',
      ),
      LegalSection(
        '6. CSAM response and authorities',
        'When we become aware of apparent CSAM, we take steps to restrict access, preserve only what is necessary and lawful, and report to the relevant authority or designated reporting organization where required. Silarah responds to valid legal requests and cooperates with lawful investigations consistent with applicable law, member rights and evidence-preservation duties. We do not promise a particular investigative or prosecutorial outcome.',
      ),
      LegalSection(
        '7. Privacy and data handling',
        'Child-safety reports and preserved evidence are sensitive and access-restricted. We disclose them only to personnel, service providers, reporting organizations or authorities who need the information for safety handling, legal compliance or a valid investigation. Retention is limited to operational, evidentiary, abuse-prevention and legal needs and follows the Privacy and Data Deletion Policies.',
      ),
      LegalSection(
        '8. Appeals and good-faith reporting',
        'A restricted member may appeal through safety@silarah.com using the account email and relevant facts, but must not email prohibited imagery. An appeal does not automatically restore access or prevent a legally required report. Good-faith reporters are protected from retaliation; knowingly false, malicious or retaliatory reports may themselves result in enforcement.',
      ),
      LegalSection(
        '9. Related standards and contact',
        'These standards operate with the Terms of Service, Privacy Policy, Community Guidelines and Photo Moderation Policy. The designated child-safety contact is safety@silarah.com, and ordinary product support is available at support@silarah.com. Material changes will be published and communicated where legally required.',
      ),
    ],
  );

  static const refund = LegalDocument(
    id: 'refund_policy',
    slug: 'refund-policy',
    title: 'Refund Policy',
    summary:
        'Silarah subscriptions are non-refundable, except for duplicate, unauthorised or incorrect charges and failures caused by Silarah.',
    sections: [
      LegalSection('1. Subscriptions are non-refundable',
          'Silarah subscription payments are final and non-refundable once a purchase is completed, including for any unused part of a billing period. The price, billing period and renewal terms are shown by Google Play and on the purchase screen before you pay. This Policy does not limit any statutory right that cannot be excluded under applicable consumer law.'),
      LegalSection('2. When we do not refund',
          'We do not refund because you changed your mind, did not find a match, did not receive interests or replies, did not use Premium, found a member incompatible, became engaged or married, forgot to cancel before a renewal, uninstalled the app, paused or deleted your account, or lost access after we enforced the Terms of Service or Community Guidelines.'),
      LegalSection('3. When we do refund',
          'We refund only when: you were charged more than once for the same subscription period; a charge is confirmed as not authorised by you; you were charged a different amount from the price shown at purchase; or Premium did not work for a substantial part of the paid period because of a fault on Silarah’s side that we could not fix within a reasonable time after you reported it. The refund covers the duplicate, unauthorised or excess amount, or the affected part of the period, and is paid through Google Play to the original payment method.'),
      LegalSection('4. Google Play purchases',
          'Payments are processed by Google Play, not by Silarah, and Silarah never sees your card or bank details. Google Play may independently grant a refund under its own policies; for example, Google offers a refund request flow for many purchases made within 48 hours. Those decisions are made by Google and are outside this Policy. When a purchase is refunded by Google or by us, the Premium access it paid for ends.'),
      LegalSection('5. How to request an eligible refund',
          'Email support@silarah.com from your Silarah account email, preferably within 30 days of the charge, with the Google Play order ID (it begins with GPA.), the charge date and a short description. We may ask for proportionate evidence, such as a screenshot showing both charges. Never send card numbers, bank details, passwords or OTP codes. Later requests are considered where the law requires it.'),
      LegalSection('6. Cancellation and renewal',
          'You can cancel at any time in Google Play under Payments & subscriptions, or through Manage Subscription in the app. Cancelling stops the next renewal; you keep Premium until the end of the period you already paid for, and that period is not refunded. Uninstalling the app, pausing a profile or deleting a Silarah account does not cancel Google Play billing. A free trial, if offered, becomes a paid subscription unless cancelled before the deadline shown.'),
      LegalSection('7. Changes to Premium',
          'We may add, change or retire individual Premium features as the Service develops. If a change materially reduces what you paid for during an active period, we will offer a reasonable remedy, such as an equivalent feature, extra time or a proportionate refund, where applicable law requires it.'),
      LegalSection('8. Contact',
          'Billing questions: support@silarah.com. Formal complaints: grievance@silarah.com. Nothing in this Policy affects non-waivable statutory rights.'),
    ],
  );

  static const deletion = LegalDocument(
    id: 'data_deletion_policy',
    slug: 'data-deletion',
    title: 'Data Deletion Policy',
    summary:
        'How to delete an account or specific data, what the 30-day recovery period means and what limited records may remain.',
    sections: [
      LegalSection('1. In-app account deletion',
          'Signed-in users can open Profile → Settings → Delete Account, choose a reason and type DELETE to confirm. The account is disabled and enters a 30-day recovery period. Signing back in during that period may cancel the request where recovery is still available. After the period, the purge process deletes the authentication account and associated profile data.'),
      LegalSection('2. Web and email requests',
          'If you cannot access the app, email privacy@silarah.com from the account address with the subject “Delete my Silarah account”. We may request proportionate verification before acting. Do not attach an identity document unless our privacy team specifically provides a secure upload route. A public request route is available at silarah.com/data-deletion/.'),
      LegalSection('3. What is deleted',
          'The purge removes or de-identifies the account, profile, preferences, photos and private storage, interests, matches, messages, notification tokens and other user-linked service data, subject to the exceptions below. Content already lawfully received or saved outside Silarah by another member cannot be recalled from that person’s device.'),
      LegalSection('4. Limited retention',
          'We may retain the minimum information necessary for legal obligations, payment and tax records, fraud and abuse prevention, security logs, dispute resolution, enforcement history and proof of consent. Retained records are access-restricted, not used for discovery or marketing, and deleted or de-identified when the applicable purpose or legal period ends. Encrypted backups expire through normal rotation rather than being edited record by record. In-app Privacy requests, responses and associated case records are retained while unresolved and for 12 months after resolution, then erased from active systems unless a documented legal hold applies. Holds are access-restricted and reviewed; after a hold ends, an already-expired case becomes eligible for erasure. Unlinking a deleted account does not anonymise the request text. Backup copies expire through provider rotation. This case-retention schedule does not extend retention of the underlying profile or authorise unrelated processing.'),
      LegalSection('5. Specific-data requests',
          'You can edit many profile fields and delete or replace photos without deleting the account. For access, correction, export, restriction or deletion of a particular category, email privacy@silarah.com. We will explain if deletion would make a requested feature unavailable or if law permits us to refuse part of the request.'),
      LegalSection('6. Subscriptions are separate',
          'Account deletion does not cancel billing controlled by Google Play or any other app store. Cancel the subscription in the store before deleting the account. Deletion does not itself create a refund; see the Refund Policy.'),
      LegalSection('7. Timing and confirmation',
          'We begin processing verified requests without undue delay. In-app deletion is scheduled after the stated 30-day recovery period; complex privacy requests follow the deadline required by applicable law. We may confirm completion where contact details remain available. Contact privacy@silarah.com if the process does not behave as described.'),
    ],
  );

  static const privacyRights = LegalDocument(
    id: 'privacy_rights_and_grievance_policy',
    slug: 'privacy-rights',
    title: 'Privacy Rights & Grievance Policy',
    summary:
        'How to access, export, correct or erase data, withdraw consent, submit a complaint and appeal a grievance decision.',
    sections: [
      LegalSection('1. Scope and request channels',
          'This Policy explains the rights-request and grievance process for Silarah members and people whose data may be processed by the Service. Signed-in members can open Profile → Settings → Privacy → Privacy requests for assisted access, correction, erasure, withdrawal, nomination or grievance requests and read the reference, response target and staff response there. On older app versions without this screen, or if you cannot sign in, email privacy@silarah.com; urgent safety complaints should use safety@silarah.com or the reporting tools. You may also email privacy@silarah.com for access, correction, consent or deletion requests, grievance@silarah.com for formal complaints, and safety@silarah.com for urgent safety content. Never send passwords, OTP codes, payment credentials or identity documents by ordinary email.'),
      LegalSection('2. Downloading a portable copy',
          'Profile → Settings → Privacy → Download my data creates an authenticated ZIP archive immediately and opens the device save or share sheet. It includes a machine-readable JSON copy of account and profile data, current accessible profile photos, interests, matches, messages, settings, consent records, subscription events, notifications, guardian links, verification decisions, blocks and reports created by you. Repeated generation is briefly rate-limited to protect account data and control database cost.'),
      LegalSection('3. Export limits and assisted access',
          'The self-service archive excludes passwords, OTP codes, raw notification credentials, temporary verification captures, other members’ confidential reports, staff identities, privileged legal material and details that would undermine anti-abuse controls. Those exclusions do not automatically determine the result of a formal legal request. Email privacy@silarah.com if you require an omitted category, an explanation of processing, a summary of data, the identities or categories of processors, or an accessible alternative format. We may redact third-party data and apply lawful exceptions.'),
      LegalSection('4. Correction, erasure and withdrawal',
          'You can correct many profile fields and replace or remove photos in the app. You can pause discovery without deleting the account, or request account deletion in Settings. A withdrawal or erasure submission creates a request for staff review; it does not immediately stop processing or delete your account. Pausing discovery only limits visibility. Use existing account controls where available, or specify the consent and purpose you want to withdraw through Privacy requests or privacy@silarah.com. After proportionate verification, we will explain and carry out the applicable cessation and processor follow-up, subject to processing required or authorised by law. Withdrawal does not undo earlier lawful processing and may make a dependent feature unavailable. Store subscriptions must be cancelled separately. Erasure exceptions require an applicable lawful basis; safety or business convenience alone does not establish one.'),
      LegalSection('5. Identity verification and request tracking',
          'We verify a request using the signed-in session, the registered email or proportionate account facts. We do not ask for more data than reasonably needed and will provide a secure route if stronger verification is genuinely necessary. Include the account email, request type and relevant dates. We may ask you to identify the profile field, message, transaction or decision concerned. Duplicate or abusive automated requests may be consolidated without preventing a genuine legal right.'),
      LegalSection('6. Grievance timelines in India',
          'Formal grievances are acknowledged and resolved within the periods set by the applicable Indian intermediary and data-protection rules, including the shorter periods those rules set for specified urgent content such as non-consensual intimate imagery. Meeting a timeline does not guarantee a requested outcome.'),
      LegalSection('7. Grievance information and evidence',
          'The Silarah Grievance Desk receives formal grievances at grievance@silarah.com. Send a concise description, account email, dates, relevant profile or conversation reference and the outcome requested. Do not forward suspected child sexual abuse material or non-consensual intimate imagery by email; identify where it appears so authorized staff can preserve and restrict it safely. We may acknowledge receipt, request necessary clarification, issue a reasoned outcome, preserve required evidence, restrict content or accounts, and notify an authority when law requires.'),
      LegalSection('8. Appeals and external remedies',
          'If you disagree with a grievance decision, reply with the original reference and explain the error. Where the Indian Grievance Appellate Committee has jurisdiction, an eligible appeal may be filed through its prescribed online mechanism within the legally applicable period, currently 30 days from receipt of the grievance officer’s decision. Privacy complaints may also be taken to the competent data-protection authority when its relevant powers and procedures are in force. Nothing here removes a non-waivable court, consumer or regulatory remedy.'),
      LegalSection('9. Security, records and changes',
          'Rights requests and grievance records are access-restricted and used to verify, investigate, respond, audit compliance, prevent abuse and meet legal duties. In-app Privacy requests, responses and associated case records are retained while unresolved and for 12 months after resolution, then erased from active systems unless a documented legal hold applies. Holds are access-restricted and reviewed; after a hold ends, an already-expired case becomes eligible for erasure. Unlinking a deleted account does not anonymise the request text. Backup copies expire through provider rotation. This case-retention schedule does not extend retention of the underlying profile or authorise unrelated processing. Separate legally required records follow the relevant statutory retention period. Material changes to this process will be published with a new policy version and notified or presented for renewed consent where required.'),
      LegalSection('10. Nomination requests',
          'Selecting Nomination submits a request to arrange and verify a nomination for exercise of rights on death or incapacity where applicable; it does not appoint a nominee or complete a nomination. Staff must explain the process, verify necessary authority and confirm any completed arrangement separately. Do not put nominee identity documents or unnecessary third-party information in the request.'),
    ],
  );

  static const verification = LegalDocument(
    id: 'verification_policy',
    slug: 'verification-policy',
    title: 'Trust & Verification Policy',
    summary:
        'What photo, email, guardian and account-history checks establish, how temporary captures are handled and how decisions can be challenged.',
    sections: [
      LegalSection('1. Purpose and types of check',
          'Silarah may offer profile-photo review, verified-email confirmation, verified-email Guardian connection and established-member indicators. These are separate trust signals. They do not establish legal identity and are not a comprehensive background check. Silarah does not collect phone numbers, government IDs or biometric templates for these checks.'),
      LegalSection('2. What we collect',
          'For the optional photo check, we process three temporary guided captures (look at camera, gentle smile and blink), the current primary profile photo, submission timestamps, decision status, reviewer notes and deletion audit. We do not request a government ID for this check and do not create or retain facial embeddings or templates.'),
      LegalSection('3. Automated and manual processing',
          'On-device face signals provide capture guidance only. Smile and blink detection may be bypassed through the accessibility fallback. Every submission is decided by an authorized human reviewer comparing the temporary captures with the current profile photo; an on-device score can never grant or reject the badge.'),
      LegalSection('4. Fair-use requirements',
          'Submit your own current, unaltered image. Normal glasses, hijab, niqab and culturally modest clothing are allowed. Do not use filters, screens, masks intended to deceive or another person. Poor lighting, multiple people, mismatch or suspected manipulation may require resubmission or rejection.'),
      LegalSection('5. Badge meaning and limitations',
          'A badge means only that the stated Silarah check passed at a point in time. It does not certify character, intentions, marital status, finances, criminal history, immigration status or safety, and it does not replace independent judgment. We may remove or repeat verification when material information changes or risk is detected.'),
      LegalSection('6. Access, security and retention',
          'Temporary captures are stored privately, shown only through short-lived staff previews, and are never displayed to members or guardians. They are deleted from active verification storage after review and no later than 48 hours after submission. The decision, timestamps, reviewer audit and deletion result may remain for integrity, appeals and legal obligations without retaining the captures.'),
      LegalSection('7. Decision and appeal',
          'The app provides a reason or next step when possible. You may retry after correcting quality issues or appeal through safety@silarah.com. Include your account email and decision date, but do not email identity documents. Staff may request a new secure submission. Appeals do not guarantee approval.'),
      LegalSection('8. Regional availability and account confirmation',
          'The initial service launch is limited to India as shown in the app and Google Play listing. Accounts use verified email; Silarah does not collect or verify phone numbers. Messaging access can differ by plan and by product rules that the app shows before use or purchase. Premium billing remains tied to the Google Play and Silarah account. Guardian invitations are one-time, expire after 7 days, are stored only as hashes and can be accepted only by the invited verified-email account.'),
    ],
  );

  static const photoModeration = LegalDocument(
    id: 'photo_moderation_policy',
    slug: 'photo-moderation-policy',
    title: 'Photo Moderation Policy',
    summary:
        'Rules and automated safety checks for profile photos, plus review, privacy and appeal procedures.',
    sections: [
      LegalSection('1. Scope',
          'This Policy applies to profile and gallery photos. It is separate from the optional profile-photo trust check. Passing automated photo moderation does not grant a trust badge, and a trust badge does not exempt a photo from these rules.'),
      LegalSection('2. What profile photos must show',
          'Photos must be genuine, usable images relevant to the account member. Group and culturally modest photos, including hijab, niqab and traditional clothing, are permitted when otherwise compliant. You must have permission to upload images containing other adults. Images whose primary purpose is text, scenery, advertising, a random object or impersonation may be rejected as unsuitable for a matrimonial profile.'),
      LegalSection('3. Prohibited images',
          'Do not upload nudity, sexual activity, sexually explicit or fetish content, lingerie-focused or sexualized imagery, swimwear or bikini imagery intended or assessed as unsuitable for this matrimonial context, exploitation, violence, hate symbols, illegal content, intimate images shared without consent, images of minors used deceptively, contact advertising, watermarked stolen photos or malicious files.'),
      LegalSection('4. Automated checks',
          'Before publication, the app validates that the file is a decodable image, uses on-device object signals to assess human presence and uses an on-device safety classifier to detect explicit content. Server validation checks that the upload is authorized and accompanied by a valid moderation result. We do not publish model thresholds because doing so would help evasion. Automated systems can be wrong and may change as safety improves.'),
      LegalSection('5. Approval and review',
          'Photos assessed as compliant may publish without advance administrator approval. High-confidence explicit-content results are blocked and may be placed in a restricted moderation queue for authorized review. Members and staff may report or review a previously approved photo when new context or risk appears. We may remove, blur or restrict a photo while investigating.'),
      LegalSection('6. Photo privacy',
          'Moderation approval and visibility are different controls. You can select public, mutual-interest or request-to-view privacy. Access decisions are enforced by signed media access and account permissions, but recipients may still capture what they can view. Do not upload a photo you cannot tolerate an authorized recipient seeing.'),
      LegalSection('7. Decisions and appeals',
          'The app gives a practical reason when possible, such as unsupported image, no person detected or explicit content. Try a different clear image if the result is a quality error. To challenge a moderation decision, email safety@silarah.com with the account email and approximate upload time; do not attach prohibited content to ordinary email.'),
      LegalSection('8. Enforcement',
          'Repeated attempts to upload prohibited content, manipulate scores or bypass upload controls may lead to feature limits, suspension or termination. Apparent child sexual exploitation or other serious unlawful material may be preserved and reported as required by law.'),
    ],
  );

  static const guardian = LegalDocument(
    id: 'guardian_wali_policy',
    slug: 'guardian-policy',
    title: 'Guardian / Wali Policy',
    summary:
        'How guardian linking, chat visibility, active participation, consent and unlinking work on Silarah.',
    sections: [
      LegalSection('1. Optional support feature',
          'Guardian mode lets an adult member involve a trusted guardian or wali in matrimonial conversations. It is optional unless the member chooses it or a lawful safety requirement applies. Silarah does not appoint a wali or decide whether a person has religious or legal authority for a marriage.'),
      LegalSection('2. Guardian-managed profiles',
          'A parent, sibling or other authorized family representative may create and manage a profile for an adult candidate only with that candidate’s informed permission and accurate information. The profile is disclosed to members as Guardian-managed. The managing account remains responsible for activity and must stop using or delete the profile if authority or consent is withdrawn. Guardian-managed ownership does not itself provide chat-oversight access to another account.'),
      LegalSection('3. Adult member control and consent',
          'The adult profile owner (the “ward” in this Policy) chooses whether to enable guardian mode, supplies guardian details and selects available permissions. A guardian must know they are being linked and use their own authorized account. Do not secretly enrol, monitor or control another adult.'),
      LegalSection('4. Linking and verification',
          'A link may require a matching invitation, contact verification or other security checks. Guardian contact information is not publicly displayed. Silarah may pause or reject a link when identity, authority, consent or account safety cannot be established.'),
      LegalSection('5. Passive and active modes',
          'In passive mode, a guardian may receive read-only access to linked conversations and relevant match context. In active mode, where offered and enabled, a guardian may approve a match or send a message in the linked workflow. Guardian-originated activity is recorded and should be distinguishable; a guardian may not secretly impersonate the member.'),
      LegalSection('6. Privacy of all participants',
          'When guardian chat mirroring is enabled, conversation participants should expect messages in that conversation to be visible to the linked guardian. Guardian access is limited by account permissions and row-level controls. Guardians must not copy, publish or misuse member information and must comply with the Terms and Community Guidelines.'),
      LegalSection('7. Unlinking and access changes',
          'The adult member may disable guardian mode or change permissions in Settings, subject to security checks and any action already completed. Unlinking stops future authorized access but cannot erase copies a guardian lawfully received or actions already recorded. Silarah may unlink or restrict a guardian for misuse or safety risk.'),
      LegalSection('8. Safety and disagreements',
          'Guardian involvement does not replace the adult member’s consent, independent judgment or local legal requirements. Threats, coercive control, forced marriage, harassment or misuse of private messages are prohibited. Use block/report tools and contact safety@silarah.com; contact local emergency or specialist services where anyone is at risk.'),
      LegalSection('9. No legal or religious determination',
          'Family and wali requirements vary by school of thought and jurisdiction. Silarah provides communication tools, not legal, religious or marriage solemnization advice. Members and families should consult qualified local advisers for their circumstances.'),
    ],
  );

  static const all = <LegalDocument>[
    terms,
    privacy,
    community,
    childSafety,
    refund,
    deletion,
    privacyRights,
    verification,
    photoModeration,
    guardian,
  ];

  static LegalDocument fromType(String type) {
    final normalized = switch (type) {
      'tos' => 'terms',
      'guidelines' => 'community-guidelines',
      'child-safety' || 'csae' => 'child-safety',
      'refund' => 'refund-policy',
      'deletion' => 'data-deletion',
      'rights' || 'grievance' || 'data-access' => 'privacy-rights',
      'kyc' || 'verification' => 'verification-policy',
      'photos' || 'photo-moderation' => 'photo-moderation-policy',
      'guardian' || 'wali' => 'guardian-policy',
      _ => type,
    };
    return all.firstWhere(
      (document) => document.slug == normalized || document.id == normalized,
      orElse: () => privacy,
    );
  }
}

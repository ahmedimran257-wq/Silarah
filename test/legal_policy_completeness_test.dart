import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/legal/legal_documents.dart';

void main() {
  const expected = <String, String>{
    'terms': 'Terms of Service',
    'privacy': 'Privacy Policy',
    'community-guidelines': 'Community Guidelines',
    'child-safety': 'Child Safety Standards',
    'refund-policy': 'Refund Policy',
    'data-deletion': 'Data Deletion Policy',
    'privacy-rights': 'Privacy Rights & Grievance Policy',
    'verification-policy': 'Trust & Verification Policy',
    'photo-moderation-policy': 'Photo Moderation Policy',
    'guardian-policy': 'Guardian / Wali Policy',
  };

  test('all launch policies are substantive and uniquely versioned', () {
    expect(LegalDocuments.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(LegalDocuments.effectiveDate, isNotEmpty);
    expect(LegalDocuments.all.length, expected.length);
    expect(
      LegalDocuments.all.map((document) => document.slug).toSet(),
      expected.keys.toSet(),
    );

    for (final document in LegalDocuments.all) {
      expect(document.title, expected[document.slug], reason: document.slug);
      expect(document.summary.split(' ').length, greaterThanOrEqualTo(10));
      expect(document.sections.length, greaterThanOrEqualTo(7));
      final content = document.sections
          .map((section) => '${section.title} ${section.body}')
          .join(' ');
      expect(content.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(250),
          reason: '${document.slug} is too short to be a launch policy');
      expect(
        content.toLowerCase(),
        isNot(anyOf(contains('lorem ipsum'), contains('coming soon'))),
      );
    }
  });

  test('public site exposes every policy with canonical metadata', () {
    for (final entry in expected.entries) {
      final file = File('site/${entry.key}/index.html');
      expect(file.existsSync(), isTrue, reason: file.path);
      final html = file.readAsStringSync();
      expect(
        html,
        contains(entry.value.replaceAll('&', '&amp;')),
        reason: file.path,
      );
      expect(html, contains('https://silarah.com/${entry.key}/'));
      expect(html, contains(LegalDocuments.version));
      expect(html, contains(LegalDocuments.effectiveDate));
      expect(html.toLowerCase(), isNot(contains('placeholder')));
      expect(html.toLowerCase(), isNot(contains('coming soon')));
    }

    final sitemap = File('site/sitemap.xml').readAsStringSync();
    for (final slug in expected.keys) {
      expect(sitemap, contains('https://silarah.com/$slug/'));
    }
  });

  test('settings and onboarding use the versioned policy catalogue', () {
    final settings = File('lib/features/home/screens/settings_screen.dart')
        .readAsStringSync();
    final legalGate =
        File('lib/features/onboarding/screens/legal_gate_screen.dart')
            .readAsStringSync();
    final consentService =
        File('lib/core/services/legal_consent_service.dart').readAsStringSync();
    final originalConsentMigration = File(
      'supabase/migrations/134_versioned_legal_policy_consents.sql',
    ).readAsStringSync();
    final currentConsentMigration = File(
      'supabase/migrations/264_policy_250_compatible_consent_rollout.sql',
    ).readAsStringSync();

    expect(settings, contains('LegalDocuments.all'));
    expect(legalGate, contains('community-guidelines'));
    expect(consentService, contains('LegalDocuments.version'));
    expect(originalConsentMigration, contains("'community_guidelines'"));
    expect(currentConsentMigration, contains("'2.4.0', '2.5.0'"));
    expect(currentConsentMigration, contains(LegalDocuments.version));
    expect(LegalDocuments.operatorName, 'Silarah');
    expect(LegalDocuments.grievanceOfficerName, 'Silarah Grievance Desk');
  });

  test('2.5 privacy commitments are honest and aligned across app and site',
      () {
    expect(LegalDocuments.version, '2.5.0');
    final app = LegalDocuments.privacy.sections.map((s) => s.body).join(' ');
    final rights =
        LegalDocuments.privacyRights.sections.map((s) => s.body).join(' ');
    final html = File('site/privacy/index.html').readAsStringSync();
    final rightsHtml =
        File('site/privacy-rights/index.html').readAsStringSync();
    for (final copy in [app, html]) {
      expect(
          copy, contains('specific statutory legitimate use under section 7'));
      expect(copy, isNot(contains('legitimate interests in operating')));
      expect(
          copy, isNot(contains('legitimate safety and operational interests')));
      expect(copy, contains('when its relevant provisions apply'));
    }
    for (final copy in [app, html, rights, rightsHtml]) {
      expect(copy, contains('Profile → Settings → Privacy → Privacy requests'));
      expect(
          copy,
          contains(
              'does not immediately stop processing or delete your account'));
      expect(copy,
          contains('does not appoint a nominee or complete a nomination'));
      expect(copy, contains('12 months after resolution'));
      expect(copy, contains('unless a documented legal hold applies'));
      expect(copy, contains('while unresolved'));
      expect(copy, contains('does not anonymise the request text'));
    }
    final migration = File(
            'supabase/migrations/264_policy_250_compatible_consent_rollout.sql')
        .readAsStringSync();
    expect(migration, contains('VALUES (v_version, p_acceptances)'));
    expect(migration, contains('required.consent_type, v_tx.policy_version'));
    expect(migration, contains('p_acceptances IS DISTINCT FROM'));
    expect(migration, contains('v_tx.acceptances IS DISTINCT FROM'));
    expect(migration,
        contains('ON CONFLICT (user_id, consent_type, version) DO NOTHING'));
    expect(migration, isNot(contains('SET revoked_at = NULL')));
    expect(migration, isNot(contains('UPDATE public.user_consents')));
    expect(migration, contains("SELECT '2.5.0'::text"));
  });

  test('account deletion never claims app-store billing is cancelled', () {
    final screen = File('lib/features/home/screens/delete_account_screen.dart')
        .readAsStringSync();
    expect(screen, contains('Cancel store billing separately'));
    expect(screen, contains('does not cancel Google Play billing'));
    expect(screen, isNot(contains('Apple')));
    expect(screen, isNot(contains('Subscriptions cancelled')));
  });

  test('subscription disclosures preserve store and statutory remedies', () {
    final paywall = File(
      'lib/features/home/screens/subscription_screen.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/home/screens/my_profile_screen.dart',
    ).readAsStringSync();
    final policies = File(
      'lib/core/legal/legal_documents.dart',
    ).readAsStringSync();
    final privacy = File('site/privacy/index.html').readAsStringSync();
    final chat = File(
      'lib/features/home/screens/chat_screen.dart',
    ).readAsStringSync();

    expect(paywall, contains('Manage Subscription'));
    expect(paywall, contains("'refund-policy'"));
    expect(paywall, contains('before the renewal date shown there'));
    expect(paywall, isNot(contains('24h before renewal')));
    expect(profile, contains('openGooglePlaySubscriptions'));
    // Grievance access must stay named on the Profile support entry.
    expect(profile,
        contains("context.uiCopy('Help Center, contact and grievances')"));
    expect(profile, contains("initialSection: 'help'"));
    expect(profile, contains('child: _HelpAndGrievanceCard('));
    expect(
      profile.indexOf('child: _SavedProfilesSection('),
      lessThan(profile.indexOf('child: _HelpAndGrievanceCard(')),
    );
    // Non-refundable by default, with narrow exceptions the law expects.
    expect(policies, contains('final and non-refundable'));
    expect(policies, contains('charged more than once'));
    expect(policies, contains('fault on Silarah’s side'));
    expect(policies, contains('within 48 hours'));
    expect(policies, contains('statutory'));
    // A solo operator must not promise faster grievance handling than the law.
    expect(policies, isNot(contains('ordinarily resolved within 7 days')));
    final refundPage = File('site/refund-policy/index.html').readAsStringSync();
    expect(refundPage, contains('final and non-refundable'));
    expect(refundPage, contains('charged more than once'));
    expect(privacy, isNot(contains('MyMemory')));
    expect(chat, isNot(contains('onTranslate')));
    expect(chat, isNot(contains('_translateWithPrivacyNotice')));
  });
}

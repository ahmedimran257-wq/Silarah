import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/auth_callback_service.dart';

void main() {
  test('only the verified auth callback is accepted', () {
    expect(
      AuthCallbackService.isAuthCallback(
        Uri.parse('https://silarah.com/auth/callback?code=redacted'),
      ),
      isTrue,
    );
    expect(
      AuthCallbackService.isAuthCallback(
        Uri.parse('https://attacker.example/auth/callback?code=redacted'),
      ),
      isFalse,
    );
  });

  test('auth callback implementation never logs or renders callback values',
      () {
    final source =
        File('lib/core/services/auth_callback_service.dart').readAsStringSync();
    expect(source, isNot(contains('debugPrint(uri')));
    expect(source, isNot(contains('debugPrint(error')));
    expect(source, contains('exchangeCodeForSession'));
    expect(source, isNot(contains('setSession(')));
  });

  test('DigiLocker product code and deployment source are absent', () {
    expect(
        File('lib/core/services/digilocker_service.dart').existsSync(), false);
    expect(
      File('supabase/functions/digilocker-verify/index.ts').existsSync(),
      false,
    );
    expect(
      File('lib/features/verification/screens/kyc_verification_screen.dart')
          .existsSync(),
      false,
    );
    expect(File('supabase/functions/process-kyc/index.ts').existsSync(), false);
    expect(
      File('supabase/functions/purge-kyc-documents/index.ts').existsSync(),
      false,
    );

    final finalRetirement = File(
      'supabase/migrations/211_retire_legacy_kyc_and_refresh_admin_metrics.sql',
    ).readAsStringSync();
    expect(finalRetirement,
        contains('DROP TABLE IF EXISTS public.kyc_review_submissions'));
    expect(finalRetirement,
        contains('legacy_kyc_cleanup_blocked_nonempty_storage'));
    expect(finalRetirement, contains("purpose = 'profile_photo'"));
    expect(finalRetirement, contains("'pendingPhotoChecks'"));

    final retirementMigration = File(
      'supabase/migrations/195_retire_digilocker_verification.sql',
    ).readAsStringSync();
    expect(
      retirementMigration,
      contains(
        'DROP TABLE IF EXISTS public.identity_verification_evidence',
      ),
    );
    final publicPolicy = File(
      'site/verification-policy/index.html',
    ).readAsStringSync();
    expect(publicPolicy.toLowerCase(), isNot(contains('digilocker')));
    expect(publicPolicy, contains('look at the camera'));
    expect(publicPolicy, contains('gentle smile'));
    expect(publicPolicy, contains('blink once'));
    expect(publicPolicy, contains('government-ID matching'));
    expect(publicPolicy, contains('48 hours'));
  });

  test('policy reminders use current metadata with honest signup compatibility',
      () {
    final migration = File(
      'supabase/migrations/264_policy_250_compatible_consent_rollout.sql',
    ).readAsStringSync();
    final legalDocuments =
        File('lib/core/legal/legal_documents.dart').readAsStringSync();
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final reminder = File(
      'lib/features/home/widgets/policy_reminder_sheet.dart',
    ).readAsStringSync();

    expect(legalDocuments, contains("static const version = '2.8.0'"));
    expect(
        File('supabase/migrations/345_policy_280_google_sign_in.sql')
            .readAsStringSync(),
        contains("'2.8.0'"));
    expect(migration, contains("'2.4.0', '2.5.0'"));
    final priorReminderMigration = File(
      'supabase/migrations/214_policy_230_subscription_and_privacy_consents.sql',
    ).readAsStringSync();
    expect(priorReminderMigration, contains("interval '3 months'"));
    expect(migration, contains('get_my_policy_reminder_state'));
    expect(migration, contains('acknowledge_policy_reminder'));
    expect(home, contains('PolicyReminderService.instance.getState()'));
    expect(home, contains('PolicyReminderSheet.show(context)'));
    expect(reminder, contains('barrierColor: Colors.black'));
    expect(reminder, contains('_ReminderHero('));
    expect(reminder, contains('_ReminderRulesPanel('));
    expect(reminder, contains('_LegalAction('));
  });

  test('retired government-ID copy cannot return to active localization', () {
    final sources = <String>[
      for (final file in Directory('lib/l10n').listSync())
        if (file is File &&
            (file.path.endsWith('.arb') ||
                file.path.endsWith('ui_copy.dart') ||
                file.path.endsWith('ui_copy_supplement.dart')))
          file.readAsStringSync(),
    ].join('\n');

    expect(sources, isNot(contains('kyc_statusApproved')));
    expect(sources, isNot(contains('KYC & Verification Policy')));
    expect(sources, isNot(contains('Photograph your ID')));
    expect(sources, isNot(contains('Government ID verified')));
    expect(sources, isNot(contains('Passive face scan')));
  });

  test('Android owns branded notification channels and native share', () {
    final activity = File(
      'android/app/src/main/kotlin/com/silarah/app/MainActivity.kt',
    ).readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(activity, contains('silarah_alerts'));
    expect(activity, contains('IMPORTANCE_HIGH'));
    expect(activity, contains('Intent.ACTION_SEND'));
    expect(manifest, contains('default_notification_channel_id'));
  });

  test('block migration preserves completed match cycles', () {
    final migration = File(
      'supabase/migrations/191_preserve_match_history_on_block.sql',
    ).readAsStringSync();
    expect(migration, contains("AND status = 'active'"));
    expect(migration, isNot(contains("AND status <> 'blocked'")));
  });

  test('legacy feature text renders through the localization boundary', () {
    final roots = <Directory>[
      Directory('lib/features'),
      Directory('lib/core/widgets'),
    ];
    final rawTextConstructor = RegExp(r'\bText\(');
    final findings = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('language_selection_screen.dart')) continue;
        final source = entity.readAsStringSync();
        if (rawTextConstructor.hasMatch(source)) findings.add(entity.path);
      }
    }

    expect(findings, isEmpty, reason: findings.join('\n'));
  });
}

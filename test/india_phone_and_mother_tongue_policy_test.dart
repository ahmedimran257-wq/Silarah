import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogue = File(
    'supabase/migrations/210_india_phone_and_mother_tongue_catalogue.sql',
  ).readAsStringSync();
  final retirement = File(
    'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
  ).readAsStringSync();
  final subscription = File(
    'lib/features/home/screens/subscription_screen.dart',
  ).readAsStringSync();
  final profile = File(
    'lib/features/home/screens/my_profile_screen.dart',
  ).readAsStringSync();
  final contextService = File(
    'lib/core/services/country_context_service.dart',
  ).readAsStringSync();

  test('paid Premium purchase has no phone or SMS prerequisite', () {
    expect(subscription, contains('Future<void> _startPurchase'));
    expect(subscription, contains('.purchase(planId)'));
    expect(subscription, isNot(contains('showPhoneVerificationSheet')));
    expect(subscription, isNot(contains('verifyPhoneNumber')));
    expect(profile, isNot(contains('showPhoneVerificationSheet')));
    expect(profile, isNot(contains('PhoneVerificationService')));
    expect(
        File('lib/core/services/phone_verification_service.dart').existsSync(),
        isFalse);
    expect(
        File('supabase/functions/verify-firebase-phone').existsSync(), isFalse);
  });

  test('retirement migration removes every writable phone boundary', () {
    for (final boundary in <String>[
      'begin_my_paid_phone_verification',
      'assert_my_phone_verification_intent',
      'complete_paid_phone_verification',
      'set_guardian_phone',
      'complete_guardian_phone_and_accept',
    ]) {
      expect(retirement, contains('DROP FUNCTION IF EXISTS public.$boundary'));
    }
    expect(retirement,
        contains('DROP TABLE IF EXISTS private.phone_verification_intents'));
    expect(retirement, contains('users_phone_identity_retired CHECK'));
    expect(retirement, contains('profiles_guardian_phone_retired CHECK'));
  });

  test('Firebase Auth is removed and release App Check uses Play Integrity',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    expect(pubspec, contains('firebase_app_check:'));
    expect(pubspec, isNot(contains('firebase_auth:')));
    expect(main, contains('FirebaseAppCheck.instance.activate'));
    expect(main, contains('const AndroidPlayIntegrityProvider()'));
    expect(main, contains('const AndroidDebugProvider()'));
    // SafetyNet is deprecated; Play Console flags any build that ships it.
    final lock = File('pubspec.lock').readAsStringSync();
    final appCheck = RegExp(
      r'^  firebase_app_check:\r?\n(?:    .*\r?\n)*?    version: "0\.(\d+)\.',
      multiLine: true,
    ).firstMatch(lock);
    expect(appCheck, isNotNull);
    expect(int.parse(appCheck!.group(1)!), greaterThanOrEqualTo(4),
        reason: 'firebase_app_check 0.3.x pulls in SafetyNet');
    expect(main.toLowerCase(), isNot(contains('safetynet')));
    expect(main, contains('setTokenAutoRefreshEnabled(true)'));
  });

  test('catalogue covers all 28 states and 8 union territories', () {
    final rowPattern = RegExp(
      r"\('([A-Z]{2,3})','[^']+',((?:true)|(?:false)),'[^']+',\d+\)",
    );
    final units = <String, bool>{};
    for (final match in rowPattern.allMatches(catalogue)) {
      final code = match.group(1)!;
      if (code == 'ALL') continue;
      units[code] = match.group(2) == 'true';
    }
    expect(units.length, 36);
    expect(units.values.where((isUt) => !isUt).length, 28);
    expect(units.values.where((isUt) => isUt).length, 8);
  });

  test('state selection ranks regional languages without excluding India', () {
    expect(catalogue, contains('Census of India C-16 (2011)'));
    expect(catalogue, contains("('KA','Karnataka',false,'Kannada',1)"));
    expect(catalogue, contains("('TS','Telangana',false,'Telugu',1)"));
    expect(catalogue, contains("('JK','Jammu and Kashmir',true,'Kashmiri',1)"));
    expect(catalogue,
        contains("mt.state_code = 'ALL' OR mt.state_code = v_state_code"));
    expect(contextService, contains("'get_mother_tongues_for_location'"));
    expect(contextService, contains("const cacheVersion = 'v2'"));
    expect(contextService, contains("'p_state_name':"));
    expect(contextService, contains("'p_city_name':"));
  });
}

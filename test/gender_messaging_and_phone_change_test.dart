import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/utils/messaging_access_policy.dart';
import 'package:silarah/features/home/screens/paywall_gate_screen.dart';

void main() {
  test('client messaging policy is explicit and unknown gender fails closed',
      () {
    expect(MessagingAccessPolicy.hasFreeMessaging('female'), isTrue);
    expect(MessagingAccessPolicy.hasFreeMessaging('male'), isFalse);
    expect(MessagingAccessPolicy.hasFreeMessaging(null), isFalse);
    expect(MessagingAccessPolicy.hasFreeMessaging('other'), isFalse);
  });

  testWidgets('rapid Premium gate requests render only one modal',
      (tester) async {
    AppColors.activate(SilarahThemeMode.ivoryEmerald);
    final auth = _SeededAuthCubit('male');
    addTearDown(auth.close);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final context = tester.element(find.byType(SizedBox).first);
    final first = PaywallGateSheet.show(context);
    final second = PaywallGateSheet.show(context);
    await tester.pumpAndSettle();

    expect(find.text('Continue your conversation'), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
  });

  testWidgets('female accounts never receive the messaging paywall',
      (tester) async {
    final auth = _SeededAuthCubit('female');
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final context = tester.element(find.byType(SizedBox).first);
    await PaywallGateSheet.show(context);
    await tester.pump();
    expect(find.text('Continue your conversation'), findsNothing);
  });

  test('server applies separate female and male messaging rules', () {
    final migration = File(
      'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
    ).readAsStringSync();
    final female = migration.indexOf("IF v_gender = 'female' THEN");
    final premium = migration.indexOf('IF NOT v_paid_active', female);

    expect(female, greaterThan(0));
    expect(premium, greaterThan(female));
    expect(migration, contains('v_gender IS NULL'));
    expect(migration, contains("RAISE EXCEPTION 'profile_gender_required'"));
    expect(migration, contains("RAISE EXCEPTION 'subscription_required'"));
    final triggerMigration = File(
      'supabase/migrations/208_gender_messaging_and_verified_phone_change.sql',
    ).readAsStringSync();
    expect(
      triggerMigration,
      contains(
          'PERFORM private.assert_outgoing_chat_entitlement(NEW.sender_id)'),
    );
  });

  test('phone removal cannot alter subscription entitlement', () {
    final migration = File(
      'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
    ).readAsStringSync();
    expect(
        File('lib/core/services/phone_verification_service.dart').existsSync(),
        isFalse);
    expect(
        File('supabase/functions/verify-firebase-phone').existsSync(), isFalse);
    expect(migration,
        contains('DROP TABLE IF EXISTS private.phone_verification_intents'));
    expect(migration, isNot(contains("subscription_status = 'inactive'")));
  });

  test('end-match and Premium CTAs select readable theme foregrounds', () {
    final chat =
        File('lib/features/home/screens/chat_screen.dart').readAsStringSync();
    final paywall = File(
      'lib/features/home/screens/paywall_gate_screen.dart',
    ).readAsStringSync();
    expect(chat, contains('AppColors.readableOn(confirmBackground)'));
    expect(chat, contains('AppColors.readableOn(disabledBackground)'));
    expect(paywall, contains('AppColors.readableOn(AppColors.champagneGold)'));
  });
}

class _SeededAuthCubit extends AuthCubit {
  _SeededAuthCubit(String gender) {
    emit(AuthAuthenticated(
      userId: 'test-user',
      onboardingStep: 4,
      gender: gender,
      onboardingCompleted: true,
    ));
  }
}

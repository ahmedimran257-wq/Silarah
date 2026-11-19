import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/features/home/screens/paywall_gate_screen.dart';

// Women message free, so the messaging paywall never shows to them. Premium
// features (the daily profile limit, the private shortlist, compatibility
// insights) are Premium for everyone, and their gate used to be the same
// silent sheet: a woman tapping "Upgrade Now" got no response at all.
void main() {
  Future<BuildContext> pumpFor(WidgetTester tester, String gender) async {
    AppColors.activate(SilarahThemeMode.ivoryEmerald);
    final auth = _SeededAuthCubit(gender);
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    return tester.element(find.byType(SizedBox).first);
  }

  testWidgets('a woman sees the Premium sheet for a Premium feature',
      (tester) async {
    final context = await pumpFor(tester, 'female');
    PaywallGateSheet.show(context, gate: PremiumGate.feature);
    await tester.pumpAndSettle();
    expect(find.text('Unlock Silarah Premium'), findsOneWidget);
    expect(find.text('Unlimited profile browsing'), findsOneWidget);
    expect(find.text('Continue your conversation'), findsNothing);
    // Only one Premium sheet may be open at a time; close it so the next
    // test starts clean.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('a woman never sees the messaging paywall', (tester) async {
    final context = await pumpFor(tester, 'female');
    PaywallGateSheet.show(context);
    await tester.pumpAndSettle();
    expect(find.text('Continue your conversation'), findsNothing);
    expect(find.text('Unlock Silarah Premium'), findsNothing);
  });

  testWidgets('a man still gets the messaging paywall for chat',
      (tester) async {
    final context = await pumpFor(tester, 'male');
    PaywallGateSheet.show(context);
    await tester.pumpAndSettle();
    expect(find.text('Continue your conversation'), findsOneWidget);
  });

  test('every Premium feature entry uses the feature gate', () {
    String read(String path) => File(path).readAsStringSync();
    final discovery = read('lib/features/home/screens/discovery_feed_screen.dart');
    final detail = read('lib/features/home/screens/profile_detail_screen.dart');
    final viewed = read('lib/features/home/screens/viewed_profiles_screen.dart');
    // Daily view limit: opening a profile and the "Upgrade Now" button.
    expect(
      RegExp(r'PaywallGateSheet\.show\(context, gate: PremiumGate\.feature\)')
          .allMatches(discovery)
          .length,
      2,
    );
    // Private shortlist and compatibility insights.
    expect(
      RegExp(r'PaywallGateSheet\.show\(context, gate: PremiumGate\.feature\)')
          .allMatches(detail)
          .length,
      2,
    );
    expect(viewed, contains('gate: PremiumGate.feature'));
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

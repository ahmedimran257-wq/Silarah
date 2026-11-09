import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';

// The Home banner and the Profile "Account standing" card pick their text
// from a switch and hand it over as a variable, so the literal-string scan in
// localization_quality_test.dart cannot see it. Someone who has just been
// suspended must be able to read why, in their own language.
const _standingCopy = <String>[
  // Home banner
  'Profile paused',
  'You are hidden from discovery.',
  'Profile suspended',
  'Discovery access is restricted. Support can review this decision.',
  'Account banned',
  'Your account has an enforced restriction. Contact support to appeal.',
  'Profile unavailable',
  'Contact support for help restoring your profile.',
  'Get help',
  'Resume',
  // Profile card
  'Profile deactivated',
  'Primary photo required',
  'Incognito discovery',
  'Live in discovery',
  'Checking account status',
  'An enforced account restriction is active. Your profile is not shown and protected actions are unavailable. You can contact Support to appeal.',
  'Your profile is hidden while the account is under review. This status remains here until the restriction is resolved.',
  'Your profile is not active. Support can guide you through restoring access.',
  'You are hidden from discovery. Resume whenever you are ready—your profile information and matches remain intact.',
  'Your profile is hidden and needs a safe primary photo before it can return to discovery.',
  'Add a primary photo that passes the safety scan to publish your profile.',
  'You are hidden from general discovery and remain visible only to people you contact or already know.',
  'Your profile is visible and eligible to appear in discovery.',
  'We are confirming your current visibility with Silarah.',
  'Contact support',
  'Resume profile',
  'Manage photos',
  'ACCOUNT STANDING',
  'RESTRICTED',
  'PRIVATE',
  'ACTIVE',
  'ATTENTION',
  // Status messages shown in the banner and card
  'No internet connection. Showing your last known account status.',
  'Account status could not be refreshed.',
  'Your profile could not be resumed. Please try again.',
];

const _sources = [
  'lib/features/home/home_screen.dart',
  'lib/features/home/screens/my_profile_screen.dart',
  'lib/core/cubits/account_standing/account_standing_cubit.dart',
];

void main() {
  test('this list still matches the text the app shows', () {
    final source = _sources.map((p) => File(p).readAsStringSync()).join('\n');
    final stale = _standingCopy.where((s) => !source.contains("'$s'"));
    expect(stale, isEmpty);
  });

  test('"Live in discovery" means visible, not "go and live"', () {
    final catalog = File('lib/l10n/ui_copy_supplement.dart').readAsStringSync();
    for (final wrong in const [
      'Lebe in der Entdeckung',
      'Vivre en découverte',
      'Hidup dalam penemuan',
      'Keşifte yaşa',
      'खोज में जियो',
    ]) {
      expect(catalog, isNot(contains(wrong)));
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == 'en') continue;

    testWidgets('account standing text is translated: ${locale.languageCode}',
        (tester) async {
      final missing = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              missing
                ..clear()
                ..addAll(_standingCopy.where((s) => context.uiCopy(s) == s));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(missing, isEmpty);
    });
  }
}

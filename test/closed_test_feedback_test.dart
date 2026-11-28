// Closed-test feedback (Testers Community, 25 Nov 2026): Back on Discover
// asks for a second press before leaving; Settings can share and rate
// Silarah; the new copy exists in every language.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/legal/public_site_links.dart';
import 'package:silarah/core/router/home_tab.dart';
import 'package:silarah/core/router/notification_navigation.dart';
import 'package:silarah/l10n/app_shell_ui_copy.dart';
import 'package:silarah/l10n/ui_copy.dart';

void main() {
  group('Back on Discover', () {
    Future<List<int>> open(WidgetTester tester, HomeTab tab) async {
      final armed = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => HomeTabBackScope(
                    currentTab: tab,
                    onReturnToPrimaryTab: () {},
                    onExitArmed: () => armed.add(1),
                    child: const Scaffold(body: Text('Home')),
                  ),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return armed;
    }

    testWidgets('the first Back stays and asks; a second Back leaves',
        (tester) async {
      final armed = await open(tester, HomeTab.discover);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget,
          reason: 'a single Back never leaves');
      expect(armed, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing,
          reason: 'Back again within 2 s leaves');
    });

    testWidgets('after 2 seconds Back asks again', (tester) async {
      final armed = await open(tester, HomeTab.discover);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(armed, hasLength(2));
    });

    testWidgets('on another tab Back goes to Discover, without the message',
        (tester) async {
      final armed = await open(tester, HomeTab.profile);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(armed, isEmpty);
    });
  });

  test('Settings shares with the invite code and rates on Google Play', () {
    final settings = File('lib/features/home/screens/settings_screen.dart')
        .readAsStringSync();
    expect(settings, contains("ValueKey('settings-share-silarah')"));
    expect(settings, contains("ValueKey('settings-rate-silarah')"));
    expect(settings, contains('ReferralService.instance.getCodeOrNull()'));
    expect(settings, contains('l10n.referral_shareText(code)'));
    expect(settings, contains('PublicSiteLinks.googlePlayAppListing'));
    expect(settings, isNot(contains('requestReview')),
        reason: 'a button must not trigger the in-app review card');
    expect(PublicSiteLinks.googlePlayAppListing.toString(),
        'market://details?id=com.silarah.app');
    expect(PublicSiteLinks.googlePlayWebListing.queryParameters['id'],
        'com.silarah.app');
  });

  test('only women are told answering is free; men need Premium to answer', () {
    final paywall =
        File('lib/features/home/screens/paywall_gate_screen.dart').readAsStringSync();
    final women = paywall.indexOf('Answering a call is always free.');
    final men = paywall.indexOf(
        'Premium members call and answer their matches inside Silarah, with no phone numbers shared.');
    expect(women, greaterThan(0));
    expect(men, greaterThan(women), reason: 'the men line is the other branch');
    expect(paywall.substring(paywall.lastIndexOf('female', women), women),
        contains('?'), reason: 'the free-answer line sits behind the female check');
    for (final lang in ['ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur']) {
      expect(
          UiCopy.hasTranslation(lang,
              'Premium members call and answer their matches inside Silarah, with no phone numbers shared.'),
          isTrue,
          reason: lang);
    }
  });

  test('policy date and version keep their order in Urdu and Arabic', () {
    final screen =
        File('lib/features/home/screens/legal_doc_screen.dart').readAsStringSync();
    expect(screen, contains(r'\u2066${LegalDocuments.effectiveDate}\u2069'));
    expect(screen, contains(r'\u2066${LegalDocuments.version}\u2069'));
    final settings =
        File('lib/features/home/screens/settings_screen.dart').readAsStringSync();
    expect(settings,
        contains(r'\u2066${info.version} (${info.buildNumber})\u2069'));
  });

  test('the new copy is translated in every language', () {
    final keys = appShellUiCopy['hi']!.keys.toSet();
    expect(
        keys,
        containsAll(
            ['Press back again to exit', 'Share Silarah', 'Rate Silarah']));
    for (final lang in ['ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur']) {
      expect(appShellUiCopy[lang]!.keys.toSet(), keys, reason: lang);
      for (final key in keys) {
        expect(UiCopy.hasTranslation(lang, key), isTrue, reason: '$lang: $key');
      }
    }
  });
}

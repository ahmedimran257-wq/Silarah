// Live minute-pack purchase status (owner, 25 Nov 2026): every stage is shown
// at the top of the minutes sheet, a pending payment survives until the
// minutes land, and a decline never says "charged twice".
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_pack_pending.dart';
import 'package:silarah/features/calls/widgets/call_minutes_sheet.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, PackBuyStage stage, {VoidCallback? onRetry, String lang = 'en'}) =>
    tester.pumpWidget(MaterialApp(
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: Scaffold(body: PackBuyStatus(stage: stage, minutes: 20, onRetry: onRetry)),
    ));

void main() {
  testWidgets('each stage says where the purchase is', (tester) async {
    final expected = {
      PackBuyStage.opening: 'Opening Google Play…',
      PackBuyStage.confirming: 'Payment received · adding 20 minutes…',
      PackBuyStage.added: '20 minutes added',
      PackBuyStage.pending: 'Payment pending. Your 20 minutes are added automatically when Google Play confirms it.',
      PackBuyStage.failed: "Payment didn't go through. You weren't charged.",
    };
    for (final entry in expected.entries) {
      await _pump(tester, entry.key);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
    }
    await _pump(tester, PackBuyStage.idle);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('pack-status-idle')), findsOneWidget);
  });

  testWidgets('a decline offers Try again', (tester) async {
    var retried = 0;
    await _pump(tester, PackBuyStage.failed, onRetry: () => retried++);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('pack-status-retry')));
    expect(retried, 1);
    await _pump(tester, PackBuyStage.pending, onRetry: () => retried++);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('pack-status-retry')), findsNothing,
        reason: 'no retry while Google still has the payment');
  });

  testWidgets('the status is translated', (tester) async {
    await _pump(tester, PackBuyStage.pending, lang: 'hi');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Google Play'), findsOneWidget);
    expect(find.textContaining('Payment pending'), findsNothing);
  });

  test('a pending payment is kept until the pack balance rises', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CallPackPending.instance;
    await store.save(20, 34);
    expect(store.current.value?.minutes, 20);
    expect(await store.settleWith(34), isFalse, reason: 'balance unchanged: still pending');
    expect(store.current.value, isNotNull);
    expect(await store.settleWith(54), isTrue, reason: 'the minutes landed');
    expect(store.current.value, isNull);
  });

  test('the sheet never tells a declined buyer they were not charged "twice"', () {
    final sheet = File('lib/features/calls/widgets/call_minutes_sheet.dart').readAsStringSync();
    expect(sheet, isNot(contains('charged twice')));
    expect(sheet, contains('CallPackPending.instance.save(pack.minutes, before)'));
    expect(sheet, contains('PackBuyStatus('));
    expect(sheet, isNot(contains("you need Premium to use them")));
  });
}

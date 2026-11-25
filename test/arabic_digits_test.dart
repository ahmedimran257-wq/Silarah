// In Arabic every number is shown in Arabic digits (owner's rule, 25 Nov
// 2026); digits that belong to a word, an email or a link stay as written.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/l10n/calling_ui_copy.dart';
import 'package:silarah/l10n/digits.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';

void main() {
  group('localizeDigits', () {
    test('Arabic: numbers, times, decimals and thousands in Arabic digits', () {
      expect(localizeDigits('72', 'ar'), '٧٢');
      expect(localizeDigits('9:30', 'ar'), '٩:٣٠');
      expect(localizeDigits('12.5', 'ar'), '١٢٫٥');
      expect(localizeDigits('1,299', 'ar'), '١٬٢٩٩');
      expect(localizeDigits('تبقّى 22 من 30 دقيقة', 'ar'), 'تبقّى ٢٢ من ٣٠ دقيقة');
      expect(localizeDigits('24 · Hyderabad', 'ar'), '٢٤ · Hyderabad', reason: 'an age beside a Latin city');
      expect(localizeDigits(' (2)', 'ar'), ' (٢)');
      expect(localizeDigits('+91 98765', 'ar'), '+٩١ ٩٨٧٦٥');
      expect(localizeDigits('2, 3', 'ar'), '٢, ٣', reason: 'a comma before a space is punctuation');
    });

    test('digits inside a word, an email or a link stay as written', () {
      for (final text in [
        'imran8341@gmail.com',
        'v1.0.0',
        'silarah.com/p/12',
        '#3a',
        'Room5',
        'H2O',
        'a_1',
        'privacy-reference-123',
        '123-abc',
      ]) {
        expect(localizeDigits(text, 'ar'), text, reason: text);
      }
    });

    test('other languages are unchanged, Urdu included', () {
      for (final code in ['en', 'ur', 'hi', 'bn', 'de', 'fr', 'id', 'ms', 'tr']) {
        expect(localizeDigits('22 of 30 · 9:30 · 12.5', code), '22 of 30 · 9:30 · 12.5', reason: code);
      }
    });

    test('call notifications in Arabic use Arabic digits', () {
      expect(callingCopyWith('ar', '{count}', {'count': 3}), contains('٣'));
      expect(callingCopyWith('en', '{count}', {'count': 3}), '3');
    });
  });

  group('UiText', () {
    Future<void> pump(WidgetTester tester, String code, Widget child) => tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
          ],
          home: Scaffold(body: child),
        ));

    testWidgets('shows Arabic digits in Arabic, and only there', (tester) async {
      await pump(tester, 'ar', const Column(children: [UiText.verbatim('72'), UiText.verbatim('2:05 · 3')]));
      expect(find.text('٧٢'), findsOneWidget);
      expect(find.text('٢:٠٥ · ٣'), findsOneWidget);
      await pump(tester, 'en', const UiText.verbatim('72'));
      expect(find.text('72'), findsOneWidget);
    });

    testWidgets('a Latin run keeps its direction after its digits change', (tester) async {
      await pump(tester, 'ar', const UiText.verbatim('24 · Hyderabad'));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, '٢٤ · Hyderabad');
      expect(text.textDirection, TextDirection.ltr, reason: 'decided on the text as written');
    });
  });
}

// Policy 2.7.0 calling, minute-pack and refund terms in Hindi, Urdu and
// Bengali (DPDP s.5(3)). They must stay complete, carry the same facts as the
// English text, use the app's own words for settings, and show on the policy
// screen in that language only.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/legal/legal_documents.dart';
import 'package:silarah/core/legal/legal_translations.dart';
import 'package:silarah/features/home/screens/legal_doc_screen.dart';
import 'package:silarah/l10n/calling_ui_copy.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

String _all(LegalTranslation t) => [
      t.heading,
      t.note,
      for (final s in t.sections) '${s.title} ${s.body}'
    ].join(' ');

void main() {
  test('translations follow the current English bundle', () {
    expect(LegalTranslations.version, LegalDocuments.version,
        reason:
            'English policy changed: update legal_translations.dart in the same release');
  });

  for (final lang in LegalTranslations.languages) {
    group(lang, () {
      test('every calling policy is translated', () {
        for (final slug in LegalTranslations.slugs) {
          expect(LegalTranslations.of(slug, lang), isNotNull,
              reason: '$lang $slug');
        }
        expect(LegalTranslations.of('privacy', lang)!.sections, hasLength(6));
        expect(LegalTranslations.of('terms', lang)!.sections, hasLength(1));
        final refund = LegalTranslations.of('refund-policy', lang)!.sections;
        expect(refund, hasLength(LegalDocuments.refund.sections.length));
        for (var i = 0; i < refund.length; i++) {
          expect(refund[i].title, startsWith('${i + 1}. '),
              reason: 'refund sections line up with the English numbering');
        }
      });

      test('carries the same facts as the English text', () {
        final privacy = _all(LegalTranslations.of('privacy', lang)!);
        final terms = _all(LegalTranslations.of('terms', lang)!);
        final refund = _all(LegalTranslations.of('refund-policy', lang)!);
        expect(privacy, contains('Stream (Stream.io, Inc.)'));
        // 2.8.0: Continue with Google, with the same facts as the English.
        expect(privacy, contains('Google'));
        expect(privacy, contains('Silarah'));
        expect(privacy, contains('(ID)'));
        expect(privacy, contains('RevenueCat'));
        expect(privacy, contains('12'));
        expect(terms, contains('Premium'));
        for (final fact in [
          'support@silarah.com',
          'grievance@silarah.com',
          'GPA.',
          '30',
          '48',
          '2019',
          'Payments & subscriptions',
          'Manage Subscription'
        ]) {
          expect(refund, contains(fact), reason: '$lang refund: $fact');
        }
        for (final text in [privacy, terms, refund]) {
          expect(text, isNot(contains(' the ')),
              reason: 'no untranslated English');
          expect(text, isNot(contains('can no longer be bought')));
        }
      });

      test('uses the app\'s own words for calling settings', () {
        final privacy = _all(LegalTranslations.of('privacy', lang)!);
        final copy = callingUiCopy[lang]!;
        expect(privacy, contains(copy['Calling…']!));
        expect(privacy, contains(copy['Ringing…']!));
        expect(privacy, contains(copy['Calls off']!));
      });
    });
  }

  Future<void> pump(WidgetTester tester, String code, String type) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: Locale(code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: LegalDocScreen(type: type),
    ));
    await tester.pump();
  }

  testWidgets('the refund policy shows in Urdu above the English text',
      (tester) async {
    await pump(tester, 'ur', 'refund-policy');
    expect(find.byKey(const ValueKey('legal-translation')), findsOneWidget);
    expect(find.text(LegalTranslations.of('refund-policy', 'ur')!.heading),
        findsOneWidget);
    expect(
        find.text(LegalDocuments.refund.sections.first.title), findsOneWidget,
        reason: 'the English text stays below');
  });

  testWidgets('other languages and other policies show no translation',
      (tester) async {
    await pump(tester, 'en', 'privacy');
    expect(find.byKey(const ValueKey('legal-translation')), findsNothing);
    await pump(tester, 'ar', 'refund-policy');
    expect(find.byKey(const ValueKey('legal-translation')), findsNothing);
    await pump(tester, 'hi', 'community-guidelines');
    expect(find.byKey(const ValueKey('legal-translation')), findsNothing);
  });
}

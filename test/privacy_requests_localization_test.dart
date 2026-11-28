import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/features/home/screens/privacy_requests_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/digits.dart';
import 'package:silarah/l10n/privacy_requests_ui_copy.dart';
import 'package:silarah/l10n/ui_copy.dart';

const _locales = ['en', 'ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur'];
const _submit = ValueKey('privacy-request-submit');
const _details = ValueKey('privacy-request-details');
const _kind = ValueKey('privacy-request-kind');
const _validation = 'Please describe your request in at least 10 characters.';
const _loadError =
    'Requests could not be loaded. Retry or contact privacy@silarah.com.';
const _submitError =
    'We could not confirm receipt. Retry safely, or contact privacy@silarah.com. A maximum of five new requests can be submitted per day.';
const _success =
    'Request received. Keep the reference below to follow its progress.';

/// The line as the screen shows it (Arabic shows Arabic digits).
String copy(String locale, String source) =>
    localizeDigits(privacyRequestsUiCopy[locale]![source]!, locale);

class _Provider implements PrivacyRequestsProvider {
  List<Map<String, dynamic>> rows = [];
  final calls = <({String requestKey, String kind, String details})>[];
  bool failLoad = false;
  bool failSubmit = false;
  Completer<void>? submitGate;
  Completer<List<Map<String, dynamic>>>? loadGate;
  int loads = 0;

  @override
  Future<List<Map<String, dynamic>>> load() async {
    loads++;
    if (loadGate != null) return loadGate!.future;
    if (failLoad) throw StateError('private backend load details');
    return rows;
  }

  @override
  Future<void> submit({
    required String requestKey,
    required String kind,
    required String details,
  }) async {
    calls.add((requestKey: requestKey, kind: kind, details: details));
    if (submitGate != null) await submitGate!.future;
    if (failSubmit) throw StateError('private backend submit details');
    rows = [request(kind: kind, reference: requestKey), ...rows];
  }
}

Map<String, dynamic> request({
  String kind = 'access',
  String status = 'received',
  String reference = 'privacy-reference-123',
  String response = 'Access',
}) =>
    {
      'id': reference,
      'kind': kind,
      'status': status,
      'response': response,
      'due_at': '2026-09-27T12:00:00Z',
    };

Future<void> pumpScreen(
  WidgetTester tester,
  PrivacyRequestsProvider provider, {
  String locale = 'en',
  SilarahThemeMode mode = SilarahThemeMode.ivoryEmerald,
  double scale = 1,
  double width = 390,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.forMode(mode),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: PrivacyRequestsScreen(provider: provider),
  ));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // ListView builds offscreen children lazily; search from the start rather
    // than assuming every localized/large-text row already has an element.
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await reveal(tester, find.byKey(_submit));
  await tester.tap(find.byKey(_submit));
  await tester.pumpAndSettle();
}

Future<void> selectKind(WidgetTester tester, String label) async {
  await reveal(tester, find.byKey(_kind));
  await tester.tap(find.byKey(_kind));
  await tester.pumpAndSettle();
  final option = find.text(label).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  test('catalog is complete with matching placeholders in all ten locales', () {
    expect(privacyRequestsUiCopy.keys.toSet(), _locales.toSet());
    final english = privacyRequestsUiCopy['en']!;
    final placeholders = RegExp(r'\{[^}]+\}');
    for (final locale in _locales) {
      final translated = privacyRequestsUiCopy[locale]!;
      expect(translated.keys.toSet(), english.keys.toSet(), reason: locale);
      for (final entry in translated.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: '$locale ${entry.key}');
        expect(UiCopy.hasTranslation(locale, entry.key), isTrue);
        expect(
          placeholders.allMatches(entry.value).map((m) => m.group(0)).toSet(),
          placeholders.allMatches(entry.key).map((m) => m.group(0)).toSet(),
          reason: '$locale ${entry.key}',
        );
      }
    }
  });

  for (final locale in _locales) {
    for (final mode in SilarahThemeMode.values) {
      testWidgets(
          '$locale / ${mode.name}: narrow large-text intake and history',
          (tester) async {
        final provider = _Provider()..rows = [request(status: 'reviewing')];
        await pumpScreen(tester, provider,
            locale: locale, mode: mode, scale: 2, width: 360);
        expect(find.text(copy(locale, 'Privacy requests')), findsOneWidget);
        final context = tester.element(find.byType(PrivacyRequestsScreen));
        expect(
            Directionality.of(context),
            ['ar', 'ur'].contains(locale)
                ? TextDirection.rtl
                : TextDirection.ltr);
        for (final entry in privacyRequestsUiCopy[locale]!.entries) {
          expect(UiCopy.localize(context, entry.key), entry.value);
        }
        expect(tester.takeException(), isNull);
        await submit(tester);
        expect(find.text(copy(locale, _validation)), findsOneWidget);
        expect(provider.calls, isEmpty);
        expect(tester.takeException(), isNull);
        for (final label in [
          'Correction',
          'Erasure',
          'Withdrawal',
          'Nomination',
          'Grievance',
          'Access'
        ]) {
          await selectKind(tester, copy(locale, label));
          expect(tester.takeException(), isNull, reason: '$locale $label');
        }
        final refresh = find.byTooltip(copy(locale, 'Refresh requests'));
        await reveal(tester, refresh);
        expect(refresh, findsOneWidget);
        final history = find.byType(Card);
        await reveal(tester, history);
        expect(
            find.text(
                '${copy(locale, 'Access')} · ${copy(locale, 'Under review')}'),
            findsOneWidget);
        expect(
            find.text(copy(locale, 'Reference: {reference}').replaceAll(
                '{reference}', '\u2068privacy-reference-123\u2069')),
            findsOneWidget);
        final due = MaterialLocalizations.of(context)
            .formatMediumDate(DateTime.parse('2026-09-27T12:00:00Z').toLocal());
        expect(
            find.text(localizeDigits(
                copy(locale, 'Response target: {date}').replaceAll('{date}', due),
                locale)),
            findsOneWidget);
        expect(find.descendant(of: history, matching: find.text('Access')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$locale: loading, failure, refresh and empty state',
        (tester) async {
      final provider = _Provider()
        ..loadGate = Completer<List<Map<String, dynamic>>>();
      await pumpScreen(tester, provider, locale: locale);
      await reveal(tester, find.text(copy(locale, 'Loading requests…')));
      expect(find.text(copy(locale, 'Loading requests…')), findsOneWidget);
      expect(
          find.text(copy(locale, 'No requests to show. Pull down to refresh.')),
          findsNothing);
      provider.loadGate!.completeError(StateError('private error'));
      await tester.pumpAndSettle();
      expect(find.text(copy(locale, _loadError)), findsOneWidget);
      expect(find.textContaining('private error'), findsNothing);
      expect(
          find.text(copy(locale, 'No requests to show. Pull down to refresh.')),
          findsNothing);
      provider.loadGate = null;
      await reveal(tester, find.byTooltip(copy(locale, 'Refresh requests')));
      await tester.tap(find.byTooltip(copy(locale, 'Refresh requests')));
      await tester.pumpAndSettle();
      expect(provider.loads, 2);
      expect(find.text(copy(locale, _loadError)), findsNothing);
      expect(
          find.text(copy(locale, 'No requests to show. Pull down to refresh.')),
          findsOneWidget);
    });

    testWidgets('$locale: submit state, safe retry and success',
        (tester) async {
      final provider = _Provider()
        ..failSubmit = true
        ..submitGate = Completer<void>();
      await pumpScreen(tester, provider, locale: locale);
      await tester.enterText(
          find.byKey(_details), '  Please export my data.  ');
      await submit(tester);
      expect(find.text(copy(locale, 'Submitting…')), findsOneWidget);
      expect(
          tester.widget<FilledButton>(find.byKey(_submit)).onPressed, isNull);
      expect(tester.widget<TextField>(find.byKey(_details)).enabled, isFalse);
      expect(
          tester
              .widget<DropdownButtonFormField<String>>(find.byKey(_kind))
              .onChanged,
          isNull);
      await tester.tap(find.byKey(_submit));
      expect(provider.calls, hasLength(1));
      provider.submitGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(copy(locale, _submitError)), findsOneWidget);
      expect(find.textContaining('private backend'), findsNothing);
      expect(tester.widget<TextField>(find.byKey(_details)).controller!.text,
          '  Please export my data.  ');
      provider
        ..failSubmit = false
        ..submitGate = null;
      await submit(tester);
      expect(provider.calls, hasLength(2));
      expect(provider.calls[0], provider.calls[1]);
      expect(provider.calls.last.details, 'Please export my data.');
      expect(find.text(copy(locale, _success)), findsOneWidget);
      expect(
          tester.widget<TextField>(find.byKey(_details)).controller!.text, '');
      expect(provider.loads, 2);
      expect(
          find.text('${copy(locale, 'Access')} · ${copy(locale, 'Received')}'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changed payload rotates retry key; success starts a new key',
      (tester) async {
    final provider = _Provider()..failSubmit = true;
    await pumpScreen(tester, provider);
    await tester.enterText(find.byKey(_details), 'Please export my data.');
    await submit(tester);
    final first = provider.calls.last.requestKey;
    await tester.enterText(find.byKey(_details), 'Please correct my data.');
    await submit(tester);
    final changedDetails = provider.calls.last.requestKey;
    expect(changedDetails, isNot(first));
    await selectKind(tester, 'Correction');
    await submit(tester);
    final changedKind = provider.calls.last.requestKey;
    expect(changedKind, isNot(changedDetails));
    expect(provider.calls.last.kind, 'correction');
    provider.failSubmit = false;
    await submit(tester);
    expect(provider.calls.last.requestKey, changedKind);
    await tester.enterText(find.byKey(_details), 'Please correct my data.');
    await submit(tester);
    expect(provider.calls.last.requestKey, isNot(changedKind));
  });

  testWidgets('reload failure after success is not a submission failure',
      (tester) async {
    final provider = _Provider();
    await pumpScreen(tester, provider);
    provider.failLoad = true;
    await tester.enterText(find.byKey(_details), 'Please export my data.');
    await submit(tester);
    expect(find.text(_success), findsOneWidget);
    expect(find.text(_loadError), findsOneWidget);
    expect(find.text(_submitError), findsNothing);
    expect(tester.widget<TextField>(find.byKey(_details)).controller!.text, '');
  });

  testWidgets('resolved and unknown history values have localized safe labels',
      (tester) async {
    final provider = _Provider()
      ..rows = [
        request(kind: 'erasure', status: 'resolved'),
        {...request(kind: 'new_kind', status: 'new_status'), 'due_at': null},
      ];
    await pumpScreen(tester, provider, locale: 'ar');
    await reveal(
        tester,
        find.text(
            '${copy('ar', 'Privacy request')} · ${copy('ar', 'Status unavailable')}'));
    expect(find.text('${copy('ar', 'Erasure')} · ${copy('ar', 'Resolved')}'),
        findsOneWidget);
    expect(
        find.text(
            '${copy('ar', 'Privacy request')} · ${copy('ar', 'Status unavailable')}'),
        findsOneWidget);
    expect(
        find.text(copy('ar', 'Response target: {date}')
            .replaceAll('{date}', copy('ar', 'Date unavailable'))),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose during load or submit does not update unmounted state',
      (tester) async {
    final loading = _Provider()
      ..loadGate = Completer<List<Map<String, dynamic>>>();
    await pumpScreen(tester, loading);
    await tester.pumpWidget(const SizedBox());
    loading.loadGate!.completeError(StateError('late load'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final submitting = _Provider()..submitGate = Completer<void>();
    await pumpScreen(tester, submitting);
    await tester.enterText(find.byKey(_details), 'Please export my data.');
    await submit(tester);
    await tester.pumpWidget(const SizedBox());
    submitting.submitGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

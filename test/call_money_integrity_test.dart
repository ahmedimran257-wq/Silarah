// Call minutes money rules on the phone (docs/voice_calling_spec.md 6.1-6.6):
// what the minutes card promises, the store identity check before a pack is
// bought, the per-started-minute meter, the calling-terms messages and the
// pause / deletion notes. The server side is tested in
// supabase/tests/call_money_integrity_test.sql.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:silarah/features/calls/call_log.dart';
import 'package:silarah/features/calls/call_models.dart';
import 'package:silarah/features/calls/call_notifications.dart';
import 'package:silarah/features/calls/widgets/call_minutes_sheet.dart';
import 'package:silarah/features/calls/widgets/calls_tab_widgets.dart';
import 'package:silarah/features/calls/widgets/chat_call_widgets.dart';
import 'package:silarah/features/calls/widgets/paid_call_minutes_note.dart';
import 'package:silarah/l10n/calling_ui_copy.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

final _periodEnd = DateTime.utc(2026, 12, 20);

CallMinutesTerms _terms({bool premium = true, DateTime? until, bool renews = true, int packs = 0}) =>
    CallMinutesTerms(
      premium: premium,
      periodEnd: premium ? _periodEnd : null,
      premiumUntil: until,
      willRenew: renews,
      packMinutes: packs,
    );

const _newCopy = [
  callingTermsCopy,
  'Review and accept the updated terms to receive calls.',
  'Available until {date}',
  "Unused included minutes don't carry over; they reset on {date}.",
  'Your {minutes} pack minutes are saved. Renew Premium to use them.',
  'Pack minutes never expire; you need Premium to use them.',
  "We couldn't confirm your account with Google Play yet. Please try again in a moment. You were not charged.",
  "Your payment is pending. Minutes are added automatically when it completes; you won't be charged twice.",
  'Paid call minutes',
  'You have {minutes} paid call minutes. They will be lost and cannot be refunded after deletion.',
  'Your {minutes} paid call minutes are kept while your profile is paused.',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the minutes card never promises a renewal (6.4)', () {
    test('renewing Premium that outlasts the period: reset date only', () {
      final t = _terms(until: DateTime.utc(2027, 1, 19));
      expect(t.availableUntil, isNull);
      expect(t.resetsOn, _periodEnd);
    });

    test('Premium with no end date: reset date only', () {
      final t = _terms(until: null);
      expect(t.availableUntil, isNull);
      expect(t.resetsOn, _periodEnd);
    });

    test('will not renew: the end date, and the reset while Premium lasts past it', () {
      final until = DateTime.utc(2027, 3, 1);
      final t = _terms(until: until, renews: false);
      expect(t.availableUntil, until);
      expect(t.resetsOn, _periodEnd);
    });

    test('Premium ends before the period: the end date and no reset', () {
      final until = DateTime.utc(2026, 12, 10);
      final t = _terms(until: until, renews: true);
      expect(t.availableUntil, until);
      expect(t.resetsOn, isNull);
    });

    test('lapsed with pack minutes: they are kept, nothing about dates', () {
      final t = _terms(premium: false, until: null, renews: false, packs: 40);
      expect(t.packsSavedWhileLapsed, isTrue);
      expect(t.availableUntil, isNull);
      expect(t.resetsOn, isNull);
      expect(_terms(premium: false, packs: 0).packsSavedWhileLapsed, isFalse);
    });

    test('the overview and the wallet read the same fields from the server', () {
      final overview = CallOverview.fromJson(const {
        'premium': true,
        'included_period_end': '2026-12-20T00:00:00Z',
        'premium_until': '2026-12-10T00:00:00Z',
        'will_renew': false,
        'consent_required': true,
        'pack_minutes': 5,
        'plans': [],
      });
      expect(overview.terms.availableUntil, DateTime.utc(2026, 12, 10).toLocal());
      expect(overview.consentRequired, isTrue);
      final wallet = CallWallet.fromJson(const {
        'premium': true,
        'included_period_end': '2026-12-20T00:00:00Z',
        'premium_until': '2026-12-10T00:00:00Z',
        'will_renew': false,
      });
      expect(wallet.terms.availableUntil, DateTime.utc(2026, 12, 10));
      expect(wallet.terms.resetsOn, isNull);
    });

    testWidgets('the card lines name the dates in the member\'s language', (tester) async {
      late List<String> lines;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        lines = callMinutesTermLines(
          context,
          _terms(until: DateTime.utc(2027, 3, 1), renews: false),
          DateFormat.MMMd('en'),
        );
        return const SizedBox();
      })));
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('Available until'));
      expect(lines.last, contains("don't carry over"));
    });
  });

  group('a pack is bought only for the signed-in member (6.3)', () {
    test('the store must already know this member', () async {
      expect(await callPackBuyerConfirmed('member-1', () async => 'member-1'), isTrue);
      expect(await callPackBuyerConfirmed('member-1', () async => r'$RCAnonymousID:abc'), isFalse);
      expect(await callPackBuyerConfirmed(null, () async => 'member-1'), isFalse);
      expect(await callPackBuyerConfirmed('member-1', () async => throw StateError('offline')), isFalse);
    });
  });

  group('the meter uses the settlement maths (6, 4)', () {
    test('every started minute counts, never more than the hold', () {
      expect(chargedMinutesSoFar(0, 10), 0);
      expect(chargedMinutesSoFar(1, 10), 1);
      expect(chargedMinutesSoFar(60, 10), 1);
      expect(chargedMinutesSoFar(61, 10), 2);
      expect(chargedMinutesSoFar(721, 30), 13);
      expect(chargedMinutesSoFar(5000, 10), 10);
      expect(chargedMinutesSoFar(30, 0), 0);
    });
  });

  group('calling terms (6.5)', () {
    test('the server answer has its own outcome and message', () {
      expect(CallStartOutcome.parse('consent_required'), CallStartOutcome.consentRequired);
    });

    test('a member who could not be rung is told to accept the terms', () {
      final push = MissedCallPush.fromData(const {
        'type': 'call_missed',
        'caller_id': 'c1',
        'for_user': 'u1',
        'caller_name': 'Arif',
        'variant': 'consent',
      })!;
      final text = missedCallText('en', push);
      expect(text.title, 'Arif tried to call you');
      expect(text.body, 'Review and accept the updated terms to receive calls.');
      expect(missedCallText('ur', push).body, callingUiCopy['ur']!['Review and accept the updated terms to receive calls.']);
    });
  });

  group('pause and deletion say what happens to paid minutes (6.6)', () {
    Future<void> pump(WidgetTester tester, PaidCallMinutesContext kind, int? minutes) =>
        tester.pumpWidget(_app(PaidCallMinutesNote(
          kind: kind,
          load: () async => minutes,
          builder: (context, text) => Text(text),
        )));

    testWidgets('deletion warns when there are paid minutes', (tester) async {
      await pump(tester, PaidCallMinutesContext.deletion, 45);
      await tester.pump();
      expect(find.text('You have 45 paid call minutes. They will be lost and cannot be refunded after deletion.'),
          findsOneWidget);
    });

    testWidgets('pause says they are kept', (tester) async {
      await pump(tester, PaidCallMinutesContext.pause, 12);
      await tester.pump();
      expect(find.text('Your 12 paid call minutes are kept while your profile is paused.'), findsOneWidget);
    });

    testWidgets('nothing when there are none, or the balance is negative', (tester) async {
      for (final minutes in [0, -3, null]) {
        await pump(tester, PaidCallMinutesContext.deletion, minutes);
        await tester.pump();
        expect(find.byType(Text), findsNothing, reason: '$minutes');
      }
    });
  });

  test('every new money line exists in all 10 languages with its placeholders', () {
    for (final code in callingUiCopy.keys) {
      for (final key in _newCopy) {
        final translated = callingUiCopy[code]![key];
        expect(translated, isNotNull, reason: '$code: $key');
        for (final placeholder in RegExp(r'\{[a-z_]+\}').allMatches(key)) {
          expect(translated, contains(placeholder.group(0)), reason: '$code: $key');
        }
      }
    }
  });
}

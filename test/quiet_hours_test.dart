// Quiet hours (migration 333, owner's rule 25 Nov 2026): the caller is told
// it is the other member's quiet hours and when calls ring again, and such a
// call never counts towards the unanswered-call limit. Every other refusal
// keeps the neutral words.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_models.dart';
import 'package:silarah/features/calls/widgets/chat_call_widgets.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the start reply', () {
    Future<CallStartResult> start(Map<String, dynamic> reply) =>
        CallApi(invoke: (_) async => reply, rpc: (_, __) async => null).start('m1');

    test('quiet hours carry when calls ring again', () async {
      final result = await start({
        'outcome': 'unavailable',
        'request_id': 'r1',
        'reason': 'quiet_hours',
        'quiet_until': '2026-11-26T02:30:00Z',
      });
      expect(result.outcome, CallStartOutcome.unavailable);
      expect(result.quietUntil, DateTime.utc(2026, 11, 26, 2, 30));
    });

    test('any other refusal carries nothing', () async {
      final result = await start({'outcome': 'unavailable', 'request_id': 'r1', 'quiet_until': '2026-11-26T02:30:00Z'});
      expect(result.quietUntil, isNull, reason: 'only with the quiet_hours reason');
    });
  });

  group('the caller is told', () {
    Future<BuildContext> host(WidgetTester tester, String code) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ));
      return captured;
    }

    testWidgets('when calls ring again today, on the caller\'s own clock', (tester) async {
      final context = await host(tester, 'en');
      final now = DateTime(2026, 11, 25, 7, 45);
      final text = quietHoursCopy(context, 'Aisha', DateTime(2026, 11, 25, 8), now: now);
      expect(text, contains('Aisha'));
      expect(text, contains('quiet hours now. Calls ring again at'));
      expect(text, contains('8:00'));
      expect(text, isNot(contains('tomorrow')));
    });

    testWidgets("in the phone's own time format (24 hours here)", (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ));
      final text = quietHoursCopy(captured, 'Aisha', DateTime(2026, 11, 25, 20, 30), now: DateTime(2026, 11, 25, 20));
      expect(text, contains('20:30'));
      expect(text, isNot(contains('PM')));
    });

    testWidgets('"tomorrow" when that is another day for the caller', (tester) async {
      final context = await host(tester, 'en');
      final now = DateTime(2026, 11, 25, 23, 30);
      final text = quietHoursCopy(context, 'Aisha', DateTime(2026, 11, 26, 8), now: now);
      expect(text, contains('Calls ring again tomorrow at'));
    });

    testWidgets('in every language', (tester) async {
      for (final code in ['ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur']) {
        final context = await host(tester, code);
        final text = quietHoursCopy(context, 'Aisha', DateTime(2026, 11, 25, 8), now: DateTime(2026, 11, 25, 7));
        expect(text, isNot(contains('quiet hours now')), reason: '$code is translated');
        expect(text, contains('Aisha'), reason: code);
      }
    });
  });

  test('the server tells quiet hours and nothing else, and quiet hours never count', () {
    final sql = _read('supabase/migrations/333_quiet_hours_told_not_counted.sql');
    final notice = sql.substring(sql.indexOf('CREATE FUNCTION public.call_service_unrung_notice'));
    final body = notice.substring(0, notice.indexOf(r'$function$;'));
    expect(body, contains("v_request.reason <> 'quiet_hours' THEN\n    RETURN '{}'::jsonb;"));
    expect(body, contains('WHERE id = p_request_id AND caller_id = p_caller'), reason: 'only the caller of that call');
    expect(sql, contains("AND r.reason IN ('calls_off', 'silent', 'muted', 'calls_blocked')"));
    expect(sql.substring(sql.indexOf('CREATE OR REPLACE FUNCTION private.call_unanswered_block_until')),
        isNot(contains("'quiet_hours'")));
    final calls = _read('supabase/functions/calls/index.ts');
    expect(calls, contains('notice.reason === "quiet_hours" ? { reason: "quiet_hours", quiet_until: notice.quiet_until } : {}'));
  });
}

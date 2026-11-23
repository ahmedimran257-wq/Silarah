// Findings from the two-phone test of build 48103 (23 Nov 2026):
//  1. The "Tap to return" bar showed on top of the live call screen and never
//     redrew: the call screen changed a notifier the bar listens to while the
//     tree was building.
//  2. Right after a call the Calls tab showed it as "No answer" with its hold
//     still spent: the app read the call before the server settled it.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/call_log.dart';
import 'package:silarah/features/calls/call_notifications.dart';
import 'package:silarah/features/calls/calls_hub.dart';
import 'package:silarah/features/calls/screens/call_screen.dart';
import 'package:silarah/features/calls/widgets/call_details_sheet.dart';
import 'package:silarah/features/calls/widgets/call_return_bar.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

/// Stands in for the call screen: opens and closes like it does.
class _FakeCallScreen extends StatefulWidget {
  const _FakeCallScreen();

  @override
  State<_FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<_FakeCallScreen> {
  @override
  void initState() {
    super.initState();
    CallScreen.opened();
  }

  @override
  void dispose() {
    CallScreen.closed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('call screen'));
}

Map<String, Object?> _rules() => {
      'calls_enabled': true,
      'unanswered_call_limit': 3,
      'included_minutes': 30,
      'included_period_days': 30,
      'max_call_minutes': 60,
      'ring_seconds': 30,
      'max_pack_refunds': 2,
      'min_minutes_to_call': 1,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the return bar hides on the call screen and redraws after it', (tester) async {
    final semantics = tester.ensureSemantics();
    final call = CallController(api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      navigatorKey: navigator,
      builder: (context, child) => CallReturnBarHost(controller: call, onOpenCall: () {}, child: child!),
      home: const Scaffold(body: Text('home')),
    ));

    call
      ..phase = CallPhase.outgoing
      ..otherName = 'Aisha';
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const _FakeCallScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no listener above changed while building');
    expect(find.textContaining('Tap to return'), findsNothing, reason: 'hidden on the call screen');

    // Connected, then the member leaves the call screen: the bar shows the
    // live call, not the "Calling…" it last drew.
    call
      ..phase = CallPhase.active
      ..connectedAt = DateTime.now();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Aisha · Tap to return to call'), findsOneWidget);
    expect(find.textContaining('Calling…'), findsNothing);
    // Screen readers find it too (a page route used to hide it from them).
    expect(find.bySemanticsLabel(RegExp('^Aisha, Tap to return to call')), findsOneWidget);
    semantics.dispose();
    call.dispose();
  });

  testWidgets('after a call the Calls tab checks again until the call is settled', (tester) async {
    var overviewCalls = 0;
    var settledAfter = 2;
    final api = CallApi(
      invoke: (_) async => const {},
      rpc: (name, _) async => switch (name) {
        'get_calling_rules' => _rules(),
        'get_my_call_overview' => {
            'calls_enabled': true,
            'premium': true,
            'included_minutes': ++overviewCalls > settledAfter ? 16 : 0,
            'settling': overviewCalls <= settledAfter,
            'plans': const [],
          },
        _ => null,
      },
    );
    final hub = CallsHub(api: api);
    final before = CallController.historyVersion.value;
    await hub.start();
    expect(hub.overview?.settling, isTrue);
    await tester.pump(CallsHub.settleCheckEvery);
    await tester.pump(CallsHub.settleCheckEvery);
    await tester.pump(const Duration(milliseconds: 10));
    expect(hub.overview?.settling, isFalse);
    expect(hub.overview?.includedMinutes, 16);
    expect(CallController.historyVersion.value, greaterThan(before),
        reason: 'the call log and chats reload once the call is settled');
    final checks = overviewCalls;
    await tester.pump(CallsHub.settleCheckEvery * 3);
    expect(overviewCalls, lessThanOrEqualTo(checks + 1), reason: 'no more checks once settled');
    await hub.stop();
    settledAfter = 0;
  });

  test('a never-settling call stops being checked after a minute', () {
    expect(CallsHub.settleCheckEvery * CallsHub.settleChecks, const Duration(seconds: 60));
  });

  // 3. The callee's call screen showed only the caller's initial: the ring
  //    carried no caller id, and the screen showed a photo only when the
  //    opener passed one.
  test('the ring says who is calling, and the call keeps it', () {
    final push = IncomingCallPush.fromData({
      'type': 'call_incoming',
      'request_id': 'r1',
      'match_id': 'm1',
      'caller_id': 'caller-1',
      'caller_name': 'Imran',
      'ring_seconds': '30',
      'for_user': 'u1',
    })!;
    expect(push.callerId, 'caller-1');
    expect(IncomingCallPush.fromPayload(push.toPayload())!.callerId, 'caller-1',
        reason: 'Answer from the notification keeps it');
    final call = CallController(api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null));
    call.presentIncoming(push);
    expect(call.otherUserId, 'caller-1');
    call.dispose();
  });

  test('a ring from an older server still works without the id', () {
    final push = IncomingCallPush.fromData({
      'type': 'call_incoming',
      'request_id': 'r1',
      'caller_name': 'Imran',
      'ring_seconds': '30',
      'for_user': 'u1',
    })!;
    expect(push.callerId, isEmpty);
  });

  testWidgets('the call screen loads the photo of the other member itself', (tester) async {
    final requested = <String>[];
    // A live call, so the screen stays open.
    CallController.instance
      ..phase = CallPhase.active
      ..otherName = 'Imran';
    addTearDown(() => CallController.instance.phase = CallPhase.idle);
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: CallScreen(
        otherUserId: 'caller-1',
        photoLoader: (ids) async {
          requested.addAll(ids);
          return const {};
        },
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(requested, ['caller-1'], reason: 'asked once, only for this member');
  });

  // 4. The call list for one member did not close on a swipe down: its list
  //    took the gesture. A swipe down from the top of the list closes it.
  testWidgets('a swipe down closes the call list of a member', (tester) async {
    final entries = [
      for (var i = 0; i < 30; i++)
        CallLogEntry(
          requestId: 'r$i',
          createdAt: DateTime(2026, 11, 23, 14).subtract(Duration(hours: i)),
          outgoing: true,
          outcome: CallLogOutcome.answered,
          talkSeconds: 60,
          minutesUsed: 1,
          matchId: null,
          otherUserId: null,
          firstName: 'Aisha',
          lastName: 'Testing',
          memberUnavailable: true,
          unseen: false,
        ),
    ];
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: Scaffold(body: Builder(builder: (context) {
        host = context;
        return const SizedBox.expand();
      })),
    ));
    unawaited(showCallDetailsSheet(
      host,
      row: CallLogRow(entries),
      photoUrl: null,
      api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Calls'), findsOneWidget);
    await tester.fling(find.text('Calls'), const Offset(0, 500), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Calls'), findsNothing, reason: 'the sheet closed');
  });

  // 5. With Silarah open, "Call time accepted" never reached the proposer's
  //    Calls tab: every notification type starting with call_ was routed to
  //    the call-push handler, which knows only the calling system's own
  //    pushes, so plan and pack-minutes notifications were dropped.
  group('call pushes and notifications about calls', () {
    Set<String> typesIn(String path, RegExp pattern) =>
        pattern.allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!).toSet();

    test('the call push list is exactly what the calling functions send', () {
      final sent = <String>{
        for (final path in [
          'supabase/functions/calls/index.ts',
          'supabase/functions/call-worker/index.ts',
          'supabase/functions/_shared/call_push.ts',
        ])
          ...typesIn(path, RegExp(r'type: "(call_[a-z_]+)"')),
      };
      expect(sent, CallNotifications.pushTypes);
    });

    test('call notifications from the notification system are not call pushes, and reload the Calls tab', () {
      final notes = <String>{
        ...typesIn('supabase/functions/revenuecat-webhook/index.ts', RegExp(r'type: "(call_[a-z_]+)"')),
        for (final f in Directory('supabase/migrations').listSync().whereType<File>())
          ...RegExp(r"queue_notification\(\s*\w+,\s*'(call_[a-z_]+)'")
              .allMatches(f.readAsStringSync())
              .map((m) => m.group(1)!),
      };
      expect(notes, containsAll(['call_plan', 'call_minutes_added', 'call_minutes_refunded']));
      for (final type in notes) {
        expect(CallNotifications.isCallPush(type), isFalse, reason: type);
        expect(CallNotifications.concernsCalls(type), isTrue, reason: type);
      }
    });

    test('both push handlers route by the call push list, not by name', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, isNot(contains("startsWith('call_')")));
      expect(RegExp(r'CallNotifications\.isCallPush\(type\)').allMatches(main).length, 2);
      expect(main, contains('if (CallNotifications.concernsCalls(type)) CallController.historyChanged();'));
    });
  });
}

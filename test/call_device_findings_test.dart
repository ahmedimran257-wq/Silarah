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
import 'package:silarah/features/calls/widgets/call_layer.dart';
import 'package:silarah/features/calls/widgets/call_details_sheet.dart';
import 'package:silarah/features/calls/widgets/call_return_bar.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Map<String, Object?> _rules() => {
      'calls_enabled': true,
      'unanswered_call_limit': 3,
      'included_minutes': 30,
      'included_period_days': 30,
      'max_call_minutes': 60,
      'ring_seconds': 30,
      'min_minutes_to_call': 1,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the return bar hides on the call screen and redraws after it', (tester) async {
    final semantics = tester.ensureSemantics();
    final call = CallController(api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null));
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      builder: (context, child) => CallLayer(
        controller: call,
        screen: const Scaffold(body: Text('call screen')),
        child: CallReturnBarHost(controller: call, child: child!),
      ),
      home: const Scaffold(body: Text('home')),
    ));

    call
      ..phase = CallPhase.outgoing
      ..otherName = 'Aisha';
    call.showCallScreen();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no listener above changed while building');
    expect(find.text('call screen'), findsOneWidget);
    expect(find.textContaining('Tap to return'), findsNothing, reason: 'hidden on the call screen');

    // Connected, then the member leaves the call screen: the bar shows the
    // live call, not the "Calling…" it last drew.
    call
      ..phase = CallPhase.active
      ..connectedAt = DateTime.now();
    await tester.runAsync(call.leaveCallScreen);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('call screen'), findsNothing);
    expect(find.textContaining('Aisha · Tap to return to call'), findsOneWidget);
    expect(find.textContaining('Calling…'), findsNothing);
    // Screen readers find it too.
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
      ..otherName = 'Imran'
      ..otherUserId = 'caller-1';
    addTearDown(() => CallController.instance
      ..phase = CallPhase.idle
      ..otherUserId = null);
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: CallScreen(
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

  // 6. A free woman's missed call on the Calls tab had no "Ask him to call
  //    back" (spec 12.5.9); only the chat's call tile had it.
  group('a free woman asks him to call back from the Calls tab', () {
    CallLogEntry entry({required bool outgoing, required CallLogOutcome outcome}) => CallLogEntry(
          requestId: 'r1',
          createdAt: DateTime(2026, 11, 24, 20, 39),
          outgoing: outgoing,
          outcome: outcome,
          talkSeconds: null,
          minutesUsed: null,
          matchId: 'm1',
          otherUserId: 'u1',
          firstName: 'Imran',
          lastName: 'Ahmed',
          memberUnavailable: false,
          unseen: false,
        );

    Future<void> openSheet(WidgetTester tester, CallLogEntry latest, {required bool female, required bool premium}) async {
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
        row: CallLogRow([latest]),
        photoUrl: null,
        api: CallApi(
          invoke: (_) async => const {},
          rpc: (name, _) async => switch (name) {
            'get_chat_call_state' => {'calls_enabled': true, 'i_am_female': female, 'i_am_premium': premium},
            _ => const <Object?>[],
          },
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shown for a free woman whose latest call with him was missed', (tester) async {
      await openSheet(tester, entry(outgoing: false, outcome: CallLogOutcome.missed), female: true, premium: false);
      expect(find.text('Ask him to call back'), findsOneWidget);
    });

    testWidgets('not for a Premium woman, a man, or a call that was not missed', (tester) async {
      await openSheet(tester, entry(outgoing: false, outcome: CallLogOutcome.missed), female: true, premium: true);
      expect(find.text('Ask him to call back'), findsNothing, reason: 'Premium: she can call back');
      await openSheet(tester, entry(outgoing: false, outcome: CallLogOutcome.missed), female: false, premium: false);
      expect(find.text('Ask him to call back'), findsNothing, reason: 'a man');
      await openSheet(tester, entry(outgoing: false, outcome: CallLogOutcome.answered), female: true, premium: false);
      expect(find.text('Ask him to call back'), findsNothing, reason: 'answered');
    });

    test('it opens the chat with the message waiting in the box, never in the link', () {
      final sheet = File('lib/features/calls/widgets/call_details_sheet.dart').readAsStringSync();
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(sheet, contains('_message(draft: context.uiCopy(askToCallBackMessage))'));
      expect(sheet, contains("router.push('/chat/\$matchId', extra: draft == null ? null : ChatDraft(draft))"));
      expect(router, contains('draft: extra is ChatDraft ? extra.text : null'));
    });
  });

  // 7. Gate 3 (25 Nov 2026): after the caller added minutes, the callee's
  //    phone still warned at the old time and hung up for both at the old
  //    limit; only the caller's phone learned the new numbers.
  group('added minutes reach the callee', () {
    ({CallController call, List<String> asked}) live({required bool caller}) {
      final asked = <String>[];
      final call = CallController(
        api: CallApi(
          invoke: (body) async {
            asked.add(body['action'].toString());
            return {'outcome': 'active', 'hold_minutes': 60, 'max_duration_seconds': 3630};
          },
          rpc: (_, __) async => null,
        ),
      )
        ..requestId = 'r1'
        ..isCaller = caller
        ..phase = CallPhase.active
        ..holdMinutes = 30
        ..maxDurationSeconds = 1830;
      return (call: call, asked: asked);
    }

    testWidgets('the callee takes the new paid time and limit when Stream raises the limit', (tester) async {
      final (:call, :asked) = live(caller: false);
      call.streamLimitChanged(1806); // first seen, after both joined
      expect(asked, isEmpty);
      call.streamLimitChanged(3606); // the caller added minutes
      await tester.pump();
      expect(asked, ['status']);
      expect(call.holdMinutes, 60);
      expect(call.maxDurationSeconds, 3630);
    });

    testWidgets('a limit that shrinks, or the caller\'s own phone, asks for nothing', (tester) async {
      final callee = live(caller: false);
      callee.call
        ..streamLimitChanged(1830)
        ..streamLimitChanged(1806); // tightened once both joined
      final caller = live(caller: true);
      caller.call
        ..streamLimitChanged(1806)
        ..streamLimitChanged(3606); // its own extend() already took the numbers
      await tester.pump();
      expect(callee.asked, isEmpty);
      expect(caller.asked, isEmpty);
      expect(callee.call.maxDurationSeconds, 1830);
    });
  });

  // 8. 25 Nov 2026: a missed call that came while Silarah was in the
  //    background showed in the badge and the Missed filter, but the Calls
  //    tab's list stayed as it was when the member came back.
  testWidgets('coming back to Silarah reloads the call history, not only the badge', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final hub = CallsHub(api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null));
    await hub.start();
    addTearDown(hub.stop);
    final before = CallController.historyVersion.value;
    hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(CallController.historyVersion.value, before + 1,
        reason: 'the history, open chats and this overview reload on one signal');
    hub.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(CallController.historyVersion.value, before + 1, reason: 'only on coming back');
    await tester.pump();
  });

  // 9. 25 Nov 2026: during a call the OnePlus status-bar chip showed
  //    Silarah's crescent shrunk to a sliver that read as "!". Like
  //    WhatsApp, call notifications carry a handset, missed calls a
  //    missed-call arrow.
  test('the ring and the call show a handset in the status bar, a missed call its arrow', () {
    const kotlin = 'packages/silarah_calls/android/src/main/kotlin/com/silarah/calls';
    final notifier = File('$kotlin/CallNotifier.kt').readAsStringSync();
    final service = File('$kotlin/CallService.kt').readAsStringSync();
    final ring = notifier.substring(notifier.indexOf('fun showIncoming('), notifier.indexOf('private fun wakeScreenForRing'));
    expect(RegExp(r'\.setSmallIcon\(callIcon\)').allMatches(ring).length, 2, reason: 'ring and its lock-screen version');
    expect(ring, isNot(contains('smallIcon(context)')));
    final missed = notifier.substring(notifier.indexOf('fun showMissed('), notifier.indexOf('fun showPlanReminder('));
    expect(RegExp(r'\.setSmallIcon\(missedCallIcon\)').allMatches(missed).length, 2);
    expect(service, contains('.setSmallIcon(CallNotifier.callIcon)'));
    for (final icon in ['silarah_calls_ic_call', 'silarah_calls_ic_call_missed']) {
      expect(File('packages/silarah_calls/android/src/main/res/drawable/$icon.xml').readAsStringSync(),
          contains('android:fillColor="#FFFFFFFF"'), reason: '$icon: one colour, as Android draws it from alpha');
    }
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

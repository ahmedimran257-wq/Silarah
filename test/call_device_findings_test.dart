// Findings from the two-phone test of build 48103 (23 Nov 2026):
//  1. The "Tap to return" bar showed on top of the live call screen and never
//     redrew: the call screen changed a notifier the bar listens to while the
//     tree was building.
//  2. Right after a call the Calls tab showed it as "No answer" with its hold
//     still spent: the app read the call before the server settled it.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/calls_hub.dart';
import 'package:silarah/features/calls/screens/call_screen.dart';
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
}

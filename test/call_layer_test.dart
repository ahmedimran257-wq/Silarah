// The call screen as a layer above the app, the WhatsApp/Telegram model
// (docs/voice_calling_spec.md 12.1). Device findings of 24 Nov 2026 on the
// Redmi (Android 10):
//  1. With Silarah open and the phone asleep, a ring a minute after an earlier
//     ring had run out reached the app (the full-screen intent and the new
//     intent were delivered) but no ring screen showed: only the status-bar
//     icon, ringing and vibrating.
//  2. With Silarah closed, a ring opened the whole app (start-up) instead of
//     the call.
// The call screen was a page of the app's navigation, opened through
// start-up and guarded by a count of open call screens. It is now a layer
// driven by the call itself.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/call_notifications.dart';
import 'package:silarah/features/calls/call_platform.dart';
import 'package:silarah/features/calls/widgets/call_layer.dart';

/// The phone, as far as the call screen needs it.
class _Phone extends CallPlatform {
  bool locked = false;
  int movedToBack = 0;

  @override
  Future<bool> isDeviceLocked() async => locked;

  @override
  Future<bool> moveToBack() async {
    movedToBack++;
    return true;
  }
}

IncomingCallPush _ring(String id) => IncomingCallPush.fromData({
      'type': 'call_incoming',
      'request_id': id,
      'match_id': 'm',
      'caller_name': 'Imran',
      'decline_token': 'a' * 48,
      'ring_seconds': '30',
      'for_user': 'me',
    })!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Phone phone;
  late CallController call;
  late RootBackButtonDispatcher router;
  late int pagesPoppedUnderneath;

  setUp(() {
    phone = _Phone();
    call = CallController(
      api: CallApi(invoke: (_) async => {'outcome': 'ringing'}, rpc: (_, __) async => null),
      platform: phone,
    );
    // Stands in for the app's router: Back that reaches it pops a page of
    // the app underneath the call.
    pagesPoppedUnderneath = 0;
    Future<bool> popUnderneath() async {
      pagesPoppedUnderneath++;
      return true;
    }

    router = RootBackButtonDispatcher()..addCallback(popUnderneath);
    // Leave no stand-in router behind for the next test.
    addTearDown(() => router.removeCallback(popUnderneath));
  });

  Future<void> pumpApp(WidgetTester tester, {Widget? screen}) => tester.pumpWidget(MaterialApp(
        builder: (context, child) => CallLayer(
          controller: call,
          backButtonDispatcher: router,
          screen: screen ?? const Scaffold(body: Text('call screen')),
          child: child!,
        ),
        home: const Scaffold(body: Text('the app')),
      ));

  Future<void> back(WidgetTester tester) async {
    await tester.runAsync(tester.binding.handlePopRoute);
    await tester.pumpAndSettle();
  }

  testWidgets('a ring shows the call screen over the app at once', (tester) async {
    await pumpApp(tester);
    expect(find.text('call screen'), findsNothing);
    call.presentIncoming(_ring('r1'));
    await tester.pump();
    expect(find.text('call screen'), findsOneWidget);
    expect(find.text('the app'), findsOneWidget, reason: 'the app keeps its place underneath');
    await tester.runAsync(() => call.hangUp());
  });

  testWidgets('a ring after an earlier ring ran out shows again (device finding 1)', (tester) async {
    await pumpApp(tester);
    call.presentIncoming(_ring('r1'));
    await tester.pump();
    call.onRingCancelled('r1');
    await tester.pump();
    // "Missed" shows for a moment, then the screen goes.
    await tester.pump(const Duration(seconds: 3));
    expect(call.phase, CallPhase.idle);
    expect(find.text('call screen'), findsNothing);

    call.presentIncoming(_ring('r2'));
    await tester.pump();
    expect(call.phase, CallPhase.incoming);
    expect(find.text('call screen'), findsOneWidget);
    await tester.runAsync(() => call.hangUp());
  });

  testWidgets('Back during a ring waits for Answer or Decline, and never reaches the app', (tester) async {
    await pumpApp(tester);
    call.presentIncoming(_ring('r1'));
    await tester.pump();
    await back(tester);
    expect(find.text('call screen'), findsOneWidget);
    expect(pagesPoppedUnderneath, 0);
    await tester.runAsync(() => call.hangUp());
  });

  testWidgets('Back during a call leaves the call screen and the call goes on', (tester) async {
    await pumpApp(tester);
    call
      ..phase = CallPhase.active
      ..connectedAt = DateTime.now();
    call.showCallScreen();
    await tester.pump();
    await back(tester);
    expect(find.text('call screen'), findsNothing);
    expect(call.phase, CallPhase.active);
    expect(pagesPoppedUnderneath, 0, reason: 'the page under the call is not popped');

    // Without the call screen, Back is the app's again.
    await back(tester);
    expect(pagesPoppedUnderneath, 1);
  });

  testWidgets('on a locked phone Back steps back to the lock screen; the app is never shown', (tester) async {
    phone.locked = true;
    await pumpApp(tester);
    call
      ..phase = CallPhase.active
      ..connectedAt = DateTime.now();
    call.showCallScreen();
    await tester.pump();
    await back(tester);
    expect(phone.movedToBack, 1);
    expect(find.text('call screen'), findsOneWidget, reason: 'it is the call screen that shows when they come back');
  });

  testWidgets('Back closes a dialog of the call screen first', (tester) async {
    await pumpApp(
      tester,
      screen: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const Text('dialog')),
            child: const Text('open'),
          ),
        ),
      ),
    );
    call
      ..phase = CallPhase.active
      ..connectedAt = DateTime.now();
    call.showCallScreen();
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    await back(tester);
    expect(find.text('dialog'), findsNothing);
    expect(find.text('open'), findsOneWidget, reason: 'still on the call screen');
  });

  testWidgets('a ring that brought Silarah up from another app hands the phone back when it ends', (tester) async {
    await pumpApp(tester);
    call.presentIncoming(_ring('r1'), fromAnotherApp: true);
    await tester.pump();
    call.onRingCancelled('r1');
    await tester.pump(const Duration(seconds: 3));
    expect(phone.movedToBack, 1, reason: 'back to the lock screen or the app they were using');

    // A ring while Silarah was in front (the screen had only turned off).
    call.presentIncoming(_ring('r2'));
    await tester.pump();
    call.onRingCancelled('r2');
    await tester.pump(const Duration(seconds: 3));
    expect(phone.movedToBack, 1, reason: 'Silarah stays where the member left it');
  });

  testWidgets('a member who left the call screen stays in Silarah when the call ends', (tester) async {
    await pumpApp(tester);
    call.presentIncoming(_ring('r1'), fromAnotherApp: true);
    await tester.pump();
    call
      ..phase = CallPhase.active
      ..connectedAt = DateTime.now();
    await tester.runAsync(call.leaveCallScreen);
    await tester.runAsync(() => call.hangUp());
    await tester.pump(const Duration(seconds: 3));
    expect(phone.movedToBack, 0);
  });

  testWidgets("the notification's Answer is taken once, by the call screen", (tester) async {
    call.presentIncoming(_ring('r1'), answer: true);
    expect(call.takeAnswerOnShow(), 'r1');
    expect(call.takeAnswerOnShow(), isNull);
    // The same ring again with Answer (the screen is already up).
    call.presentIncoming(_ring('r1'), answer: true);
    expect(call.takeAnswerOnShow(), 'r1');
    await tester.runAsync(() => call.hangUp());
  });
}

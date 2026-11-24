import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/call_models.dart';
import 'package:silarah/features/calls/call_notifications.dart';
import 'package:silarah/features/calls/call_platform.dart';
import 'package:silarah/l10n/calling_ui_copy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'silarah_device_id': 'device-1'}));

  group('server outcomes', () {
    test('every server outcome maps to a screen answer', () {
      expect(CallStartOutcome.parse('ringing'), CallStartOutcome.ringing);
      expect(CallStartOutcome.parse('glare'), CallStartOutcome.glare);
      expect(CallStartOutcome.parse('unavailable'), CallStartOutcome.unavailable);
      expect(CallStartOutcome.parse('premium_required'), CallStartOutcome.premiumRequired);
      expect(CallStartOutcome.parse('no_minutes'), CallStartOutcome.noMinutes);
      expect(CallStartOutcome.parse('balance_negative'), CallStartOutcome.balanceNegative);
      expect(CallStartOutcome.parse('limit_reached'), CallStartOutcome.limitReached);
      expect(CallStartOutcome.parse('calls_disabled'), CallStartOutcome.callsDisabled);
      expect(CallStartOutcome.parse('capacity'), CallStartOutcome.capacity);
      expect(CallStartOutcome.parse('busy_self'), CallStartOutcome.busySelf);
      expect(CallStartOutcome.parse('not_allowed'), CallStartOutcome.notAllowed);
      expect(CallStartOutcome.parse('account_restricted'), CallStartOutcome.notAllowed);
      expect(CallStartOutcome.parse('rate_limited'), CallStartOutcome.rateLimited);
      expect(CallStartOutcome.parse('anything else'), CallStartOutcome.failed);
      expect(CallStartOutcome.parse(null), CallStartOutcome.failed);
    });

    test('the caller is told the same neutral words whatever the reason', () {
      expect(neutralUnavailableCopy, "{name} isn't taking calls right now.");
      expect(callingUiCopy['ur']![neutralUnavailableCopy], contains('{name}'));
    });
  });

  group('minute meter', () {
    final start = DateTime(2026, 11, 22, 10);

    test('paid time is the hold, not the 30 s connect allowance', () {
      // hold 30 min -> max duration 1830 s
      expect(secondsLeft(holdMinutes: 30, connectedAt: start, now: start), 1800);
      expect(
        secondsLeft(holdMinutes: 30, connectedAt: start, now: start.add(const Duration(minutes: 29))),
        60,
      );
      expect(
        secondsLeft(holdMinutes: 30, connectedAt: start, now: start.add(const Duration(hours: 2))),
        0,
      );
    });

    test('warnings at 2 minutes and 30 seconds; "still talking?" at the hour (12.9)', () {
      expect(warningFor(121, holdWasFull: false), CallTimeWarning.none);
      expect(warningFor(120, holdWasFull: false), CallTimeWarning.twoMinutes);
      expect(warningFor(31, holdWasFull: false), CallTimeWarning.twoMinutes);
      expect(warningFor(30, holdWasFull: false), CallTimeWarning.thirtySeconds);
      expect(warningFor(0, holdWasFull: false), CallTimeWarning.thirtySeconds);
      expect(warningFor(120, holdWasFull: true), CallTimeWarning.stillTalking);
      expect(warningFor(121, holdWasFull: true), CallTimeWarning.none);
    });

    test('durations read like a phone', () {
      expect(formatCallDuration(0), '0:00');
      expect(formatCallDuration(65), '1:05');
      expect(formatCallDuration(3725), '1:02:05');
      expect(formatCallDuration(-4), '0:00');
    });
  });

  group('server payloads', () {
    test('wallet', () {
      final wallet = CallWallet.fromJson({
        'calls_enabled': true,
        'premium': true,
        'included_minutes': 27,
        'included_granted': 30,
        'included_period_end': '2026-12-22T10:00:00Z',
        'pack_minutes': -15,
        'held_minutes': 0,
        'available_minutes': 0,
        'can_buy_packs': false,
        'packs': [
          {'product_id': 'silarah_calls_20', 'minutes': 20},
          {'product_id': 'silarah_calls_350', 'minutes': 350},
        ],
      });
      expect(wallet.negative, isTrue);
      expect(wallet.packs.map((p) => p.minutes), [20, 350]);
      expect(wallet.includedPeriodEnd, isNotNull);
    });

    test('join info keeps the token only from an active call', () {
      expect(CallJoinInfo.fromJson('r', {'outcome': 'connecting'}), isNull);
      final info = CallJoinInfo.fromJson('r', {
        'outcome': 'active',
        'role': 'caller',
        'other_name': 'Aisha Q.',
        'hold_minutes': 30,
        'max_duration_seconds': 1830,
        'stream': {
          'api_key': 'k',
          'token': 't',
          'call_type': 'silarah_voice',
          'call_id': 'abc',
          'user_id': 'u',
        },
      })!;
      expect(info.isCaller, isTrue);
      expect(info.callType, 'silarah_voice');
      expect(info.maxDurationSeconds, 1830);
    });

    test('chat call state and history', () {
      final state = ChatCallState.fromJson({
        'calls_enabled': true,
        'can_call': false,
        'reason': 'premium_required',
        'i_am_female': true,
        'i_am_premium': false,
        'events': [
          {
            'id': 'a',
            'created_at': '2026-11-22T10:00:00Z',
            'direction': 'incoming',
            'outcome': 'missed',
          },
          {
            'id': 'b',
            'created_at': '2026-11-22T11:00:00Z',
            'direction': 'outgoing',
            'outcome': 'answered',
            'duration_seconds': 125,
          },
          {'broken': true},
        ],
      });
      expect(state.showCallButton, isTrue);
      expect(state.events, hasLength(2));
      expect(state.events.first.outcome, CallEventOutcome.missed);
      expect(state.events.last.durationSeconds, 125);
      expect(ChatCallState.hidden.showCallButton, isFalse);
    });
  });

  group('ringing on a shared phone (spec 9 gate 7)', () {
    final now = DateTime.utc(2026, 11, 22, 10);
    IncomingCallPush push({String forUser = 'me', DateTime? expires}) =>
        IncomingCallPush.fromData({
          'type': 'call_incoming',
          'request_id': '0f7c2d3e-4b5a-4c6d-8e7f-9a0b1c2d3e4f',
          'match_id': 'm',
          'caller_name': 'Ahmed Q.',
          'decline_token': 'a' * 48,
          'expires_at': (expires ?? now.add(const Duration(seconds: 20))).toIso8601String(),
          'for_user': forUser,
        })!;

    test('rings only for the account signed in now', () {
      expect(shouldRing(push(), signedInUserId: 'me', now: now), isTrue);
      expect(shouldRing(push(), signedInUserId: 'previous-account', now: now), isFalse);
      expect(shouldRing(push(), signedInUserId: null, now: now), isFalse);
      expect(shouldRing(push(), signedInUserId: '', now: now), isFalse);
    });

    test('a late push after the ring time never rings', () {
      expect(
        shouldRing(push(expires: now.subtract(const Duration(seconds: 1))), signedInUserId: 'me', now: now),
        isFalse,
      );
    });

    test('a push without an owner is ignored', () {
      expect(
        IncomingCallPush.fromData({'type': 'call_incoming', 'request_id': 'x', 'expires_at': now.toIso8601String()}),
        isNull,
      );
      expect(IncomingCallPush.fromData({'type': 'new_message'}), isNull);
    });

    test('notification payload round-trips', () {
      final original = push();
      final back = IncomingCallPush.fromPayload(original.toPayload())!;
      expect(back.requestId, original.requestId);
      expect(back.forUser, 'me');
      expect(back.declineToken, original.declineToken);
      expect(IncomingCallPush.fromPayload('not json'), isNull);
    });

  });

  group('missed-call notifications (spec 12.3)', () {
    MissedCallPush? missed(Map<String, dynamic> extra) => MissedCallPush.fromData({
          'type': 'call_missed',
          'request_id': 'r1',
          'match_id': 'm1',
          'caller_id': 'u1',
          'caller_name': 'Abdul',
          'count': '1',
          'variant': 'missed',
          'silent': '0',
          'for_user': 'me',
          ...extra,
        });

    test('one missed call: "Missed call from Abdul"', () {
      final text = missedCallText('en', missed({})!);
      expect(text.title, 'Missed call from Abdul');
      expect(text.body, 'Tap to see your calls');
    });

    test('several collapse into one notification with the server count', () {
      final text = missedCallText('en', missed({'count': '3'})!);
      expect(text.title, '3 missed calls from Abdul');
    });

    test('a free man is told who called and that Premium lets him talk', () {
      final text = missedCallText('en', missed({'variant': 'premium'})!);
      expect(text.title, 'Abdul tried to call you');
      expect(text.body, 'Get Premium to talk with your matches');
    });

    test('Arabic and Urdu: a Latin name never sets the direction of the line', () {
      // Android lays a notification out by its first strong letter; the name
      // is isolated so the Urdu or Arabic sentence stays right to left.
      for (final code in rightToLeftLanguages) {
        final text = missedCallText(code, missed({'count': '3'})!);
        expect(text.title, contains(isolateBidi('Abdul')), reason: code);
        expect(text.title, isNot(startsWith('Abdul')), reason: code);
      }
      expect(callingCopyWith('ur', 'Your call with {name} is soon', {'name': 'Aisha'}),
          contains(isolateBidi('Aisha')));
      expect(callingCopyWith('en', 'Your call with {name} is soon', {'name': 'Aisha'}),
          'Your call with Aisha is soon');
    });

    test('silent flag, bounded count, and pushes for nobody are dropped', () {
      expect(missed({'silent': '1'})!.silent, isTrue);
      expect(missed({'count': '500'})!.count, 99);
      expect(missed({'count': 'x'})!.count, 1);
      expect(missed({'for_user': ''}), isNull);
      expect(missed({'type': 'call_incoming'}), isNull);
    });

    test('every language has the missed-call lines', () {
      for (final code in callingUiCopy.keys) {
        for (final key in [
          'Missed call from {name}',
          '{count} missed calls from {name}',
          '{name} tried to call you',
          'Get Premium to talk with your matches',
          'Tap to see your calls',
          '{name} · Silarah voice call',
          'Your call with {name} is soon',
          'Tap to open your calls',
          '{minutes} min left',
          'Silarah voice call',
          'Mute',
          'Unmute',
        ]) {
          expect(callingUiCopy[code]![key], isNotNull, reason: '$code: $key');
        }
      }
    });
  });

  group('call controller', () {
    test('only a ringing answer opens the call; others are explained by the chat', () async {
      for (final outcome in ['unavailable', 'premium_required', 'no_minutes', 'calls_disabled']) {
        final controller = CallController(
          api: CallApi(invoke: (body) async => {'outcome': outcome}, rpc: (_, __) async => null),
        );
        final result = await controller.startOutgoing(toMatchId: 'm', name: 'Aisha');
        expect(result.outcome, CallStartOutcome.parse(outcome));
        expect(controller.phase, CallPhase.idle, reason: outcome);
      }
    });

    test('ringing shows the outgoing call', () async {
      final calls = <Map<String, Object?>>[];
      final controller = CallController(
        api: CallApi(
          invoke: (body) async {
            calls.add(body);
            return body['action'] == 'start'
                ? {
                    'outcome': 'ringing',
                    'request_id': 'r1',
                    'ring_expires_at': DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
                  }
                : {'outcome': 'cancelled'};
          },
          rpc: (_, __) async => null,
        ),
      );
      final result = await controller.startOutgoing(toMatchId: 'm', name: 'Aisha');
      expect(result.outcome, CallStartOutcome.ringing);
      expect(controller.phase, CallPhase.outgoing);
      expect(controller.isCaller, isTrue);
      await controller.hangUp();
      expect(calls.last['action'], 'end');
      expect(calls.last['reason'], 'cancelled');
      expect(controller.phase, CallPhase.ended);
      expect(controller.endedCopy, CallEndCopy.ended);
    });

    test('a second call is refused while one is ringing', () async {
      final controller = CallController(
        api: CallApi(
          invoke: (body) async => {
            'outcome': 'ringing',
            'request_id': 'r1',
            'ring_expires_at': DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
          },
          rpc: (_, __) async => null,
        ),
      );
      await controller.startOutgoing(toMatchId: 'm', name: 'A');
      final second = await controller.startOutgoing(toMatchId: 'n', name: 'B');
      expect(second.outcome, CallStartOutcome.busySelf);
      await controller.hangUp();
    });

    test('a second tap while the server is still answering the first rings once', () async {
      final calls = <Map<String, Object?>>[];
      final answer = Completer<Map<String, dynamic>>();
      final controller = CallController(
        api: CallApi(
          invoke: (body) {
            calls.add(body);
            return body['action'] == 'start' ? answer.future : Future.value({'outcome': 'cancelled'});
          },
          rpc: (_, __) async => null,
        ),
      );
      final first = controller.startOutgoing(toMatchId: 'm', name: 'Aisha');
      final second = await controller.startOutgoing(toMatchId: 'm', name: 'Aisha');
      expect(second.outcome, CallStartOutcome.busySelf);
      answer.complete({
        'outcome': 'ringing',
        'request_id': 'r1',
        'ring_expires_at': DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
      });
      expect((await first).outcome, CallStartOutcome.ringing);
      // The first call goes on ringing: never cancelled, never asked twice.
      expect(calls.map((c) => c['action']), ['start']);
      expect(controller.phase, CallPhase.outgoing);
      expect(controller.requestId, 'r1');
      await controller.hangUp();
    });
  });

  group('call controller: one attempt at a time', () {
    IncomingCallPush ring(String id) => IncomingCallPush.fromData({
          'type': 'call_incoming',
          'request_id': id,
          'match_id': 'm',
          'caller_name': 'Ahmed Q.',
          'decline_token': 'a' * 48,
          'ring_seconds': '30',
          'for_user': 'me',
        })!;

    test('a repeated ring never resets a call that is being answered', () async {
      final controller = CallController(
        api: CallApi(invoke: (body) async => {'outcome': 'ringing'}, rpc: (_, __) async => null),
      );
      controller.presentIncoming(ring('r1'));
      expect(controller.phase, CallPhase.incoming);
      controller.phase = CallPhase.connecting; // answer under way
      controller.presentIncoming(ring('r1'));
      expect(controller.phase, CallPhase.connecting);
      controller.presentIncoming(ring('r2'));
      expect(controller.requestId, 'r1');
      await controller.onSignedOut();
    });

    test('decline ends the ring and tells the server once', () async {
      final calls = <Map<String, Object?>>[];
      final controller = CallController(
        api: CallApi(
          invoke: (body) async {
            calls.add(body);
            return {'outcome': 'declined'};
          },
          rpc: (_, __) async => null,
        ),
      );
      controller.presentIncoming(ring('r1'));
      await controller.decline();
      await controller.decline();
      expect(calls.where((c) => c['action'] == 'end'), hasLength(1));
      expect(calls.single['reason'], 'declined');
      expect(controller.endedCopy, CallEndCopy.declined);
    });

    test('a late answer for an old call does nothing to the new one', () async {
      final controller = CallController(
        api: CallApi(
          invoke: (body) async => body['action'] == 'accept'
              ? (await Future<void>.delayed(const Duration(milliseconds: 20)).then((_) => {'outcome': 'missed'}))
              : {'outcome': 'cancelled'},
          rpc: (_, __) async => null,
        ),
      );
      controller.presentIncoming(ring('r1'));
      final answering = controller.answer(forRequestId: 'r1');
      await controller.onSignedOut(); // a new attempt starts
      controller.presentIncoming(ring('r2'));
      await answering;
      expect(controller.requestId, 'r2');
      expect(controller.phase, CallPhase.incoming);
      await controller.onSignedOut();
    });
  });

  group("ring timing uses this phone's clock", () {
    test('ring_seconds counts from when the push arrived', () {
      final received = DateTime(2030, 1, 1, 12);
      final push = IncomingCallPush.fromData({
        'type': 'call_incoming',
        'request_id': 'r',
        'for_user': 'me',
        'ring_seconds': '28',
        // A server clock far away from this phone's clock is ignored.
        'expires_at': '2026-11-22T10:00:30Z',
      }, receivedAt: received)!;
      expect(push.expiresAt, received.add(const Duration(seconds: 28)));
      expect(shouldRing(push, signedInUserId: 'me', now: received), isTrue);
    });
  });

  test('auto-start tip only for phone makers that need it', () {
    expect(needsAutoStartTip('Xiaomi'), isTrue);
    expect(needsAutoStartTip('OnePlus'), isTrue);
    expect(needsAutoStartTip('google'), isFalse);
    expect(needsAutoStartTip('samsung'), isFalse);
  });

  group('copy', () {
    final placeholder = RegExp(r'\{[a-z]+\}');

    test('every call line exists in all 9 other languages with its placeholders', () {
      expect(callingUiCopy.keys.toSet(), {'ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur'});
      final keys = callingUiCopy['ar']!.keys.toSet();
      for (final entry in callingUiCopy.entries) {
        expect(entry.value.keys.toSet(), keys, reason: entry.key);
        entry.value.forEach((source, translated) {
          expect(translated.trim(), isNotEmpty, reason: '${entry.key}: $source');
          expect(
            placeholder.allMatches(translated).map((m) => m[0]).toSet(),
            placeholder.allMatches(source).map((m) => m[0]).toSet(),
            reason: '${entry.key}: $source',
          );
        });
      }
    });

    test('the ring notification is translated without a BuildContext', () {
      expect(callingCopyFor('de', 'Answer'), 'Annehmen');
      expect(callingCopyFor('en', 'Answer'), 'Answer');
      expect(callingCopyFor('xx', 'Decline'), 'Decline');
    });
  });

  group('contracts with the server and the spec', () {
    final migration = File('supabase/migrations/323_voice_calling.sql').readAsStringSync();
    final webhook = File('supabase/functions/revenuecat-webhook/index.ts').readAsStringSync();
    final spec = File('docs/voice_calling_spec.md').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    test('calling ships switched off', () {
      expect(migration, contains('calls_enabled boolean NOT NULL DEFAULT false'));
    });

    test('pack products and minutes agree in spec, database and webhook', () {
      for (final pack in const {'20': 20, '60': 60, '150': 150, '350': 350}.entries) {
        final id = 'silarah_calls_${pack.key}';
        expect(spec, contains('`$id`'));
        expect(migration, contains("('$id', ${pack.value},"));
        expect(webhook, contains('"$id"'));
      }
    });

    test('minutes are granted only by the server', () {
      expect(migration, contains('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated'));
      expect(migration, contains("GRANT EXECUTE ON FUNCTION %s TO service_role"));
      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(lib, isNot(contains('call_service_credit_pack')));
      expect(lib, isNot(contains('call_service_')));
    });

    test('sign-out forgets the account for ringing before the push token goes', () {
      final logout = main.indexOf('CallNotifications.forgetSignedInUser()');
      final retire = main.indexOf('.whenComplete(FcmService.instance.onUserLogout)');
      expect(logout, greaterThan(0));
      expect(retire, greaterThan(logout));
    });

    test('ringing is ours: no Stream ringing or push package', () {
      final calls = File('supabase/functions/_shared/stream_video.ts').readAsStringSync();
      expect(calls, contains('ring: false'));
      expect(calls, contains('notify: false'));
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('stream_video_push_notification')));
    });

    test('a ring lights a sleeping screen: the window is set as Android opens Silarah', () {
      // Android only turns the screen on when the activity is next resumed,
      // so waiting for Flutter left a sleeping phone dark while it rang. The
      // call module attaches during the activity's onCreate and sees new
      // intents before the activity resumes.
      const kotlin = 'packages/silarah_calls/android/src/main/kotlin/com/silarah/calls';
      final plugin = File('$kotlin/SilarahCallsPlugin.kt').readAsStringSync();
      final window = File('$kotlin/CallWindow.kt').readAsStringSync();
      final attach = plugin.substring(plugin.indexOf('override fun onAttachedToActivity('),
          plugin.indexOf('override fun onReattachedToActivityForConfigChanges('));
      expect(attach, contains('consumeLaunch(binding.activity.intent, initial = true)'));
      // A screen Android recreates after its process was killed comes back
      // with the launch it was first opened by: never shown again. Launches
      // wait for Dart to listen (banner tap on a killed app, 24 Nov 2026).
      expect(plugin, contains('if (initial && prefs.getString(KEY_LAST_LAUNCH, null) == key) return'));
      expect(plugin, contains('if (dartListening) {'));
      final take = plugin.substring(plugin.indexOf('"takeLaunchAction" -> {'));
      expect(take.substring(0, take.indexOf('}')), contains('dartListening = true'));
      expect(plugin, contains('override fun onNewIntent(intent: Intent): Boolean'));
      expect(plugin, contains('if (CallWindow.isRingLaunch(intent)) activity?.let { CallWindow.apply(it, true) }'));
      expect(window, contains('setTurnScreenOn(active)'));
      expect(window, contains('setShowWhenLocked(active)'));
      // A ring that is not shown gives the lock screen back.
      final main = File('lib/main.dart').readAsStringSync();
      final handler = main.substring(main.indexOf('void _onRingLaunch('),
          main.indexOf('void _startPostFirstFrameWork('));
      expect('releaseRingWindow()'.allMatches(handler).length, 3);
    });

    test('one native call module: CallStyle, Telecom, three channels, no old plugin', () {
      const kotlin = 'packages/silarah_calls/android/src/main/kotlin/com/silarah/calls';
      final notifier = File('$kotlin/CallNotifier.kt').readAsStringSync();
      final service = File('$kotlin/CallService.kt').readAsStringSync();
      final telecom = File('$kotlin/CallTelecom.kt').readAsStringSync();
      expect(notifier, contains('CallStyle.forIncomingCall('));
      expect(service, contains('CallStyle.forOngoingCall('));
      expect(service, contains('setUsesChronometer(true)'));
      for (final channel in ['"silarah_calls"', '"silarah_calls_missed"', '"silarah_call_ongoing"']) {
        expect(notifier, contains(channel));
      }
      expect(notifier, contains('NotificationManager.IMPORTANCE_HIGH'));
      expect(notifier, contains('NotificationManager.IMPORTANCE_DEFAULT'));
      expect(notifier, contains('NotificationManager.IMPORTANCE_LOW'));
      expect(telecom, contains('CallsManager.CAPABILITY_BASELINE'));
      expect(telecom, contains('onSetInactive'));
      expect(service, contains('FOREGROUND_SERVICE_TYPE_PHONE_CALL'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('flutter_local_notifications')));
      expect(pubspec, contains('path: packages/silarah_calls'));
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:launchMode="singleTop"'));
      expect(manifest, isNot(contains('flutterlocalnotifications')));
      expect(manifest, contains('android.permission.MANAGE_OWN_CALLS'));
    });
  });
}

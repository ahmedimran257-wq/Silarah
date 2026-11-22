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
      expect(secondsLeft(maxDurationSeconds: 1830, connectedAt: start, now: start), 1800);
      expect(
        secondsLeft(maxDurationSeconds: 1830, connectedAt: start, now: start.add(const Duration(minutes: 29))),
        60,
      );
      expect(
        secondsLeft(maxDurationSeconds: 1830, connectedAt: start, now: start.add(const Duration(hours: 2))),
        0,
      );
    });

    test('warnings at 5 minutes and 1 minute; "still talking?" at the hour', () {
      expect(warningFor(301, holdWasFull: false), CallTimeWarning.none);
      expect(warningFor(300, holdWasFull: false), CallTimeWarning.fiveMinutes);
      expect(warningFor(60, holdWasFull: false), CallTimeWarning.oneMinute);
      expect(warningFor(60, holdWasFull: true), CallTimeWarning.stillTalking);
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

    test('one stable notification id per call, away from other notifications', () {
      const id = '0f7c2d3e-4b5a-4c6d-8e7f-9a0b1c2d3e4f';
      expect(callNotificationId(id), callNotificationId(id));
      expect(callNotificationId(id), greaterThanOrEqualTo(900000000));
      expect(callNotificationId(id), lessThan(1000000000));
      expect(callNotificationId(id), isNot(callNotificationId('1f7c2d3e-4b5a-4c6d-8e7f-9a0b1c2d3e4f')));
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
      // so waiting for Flutter left a sleeping phone dark while it rang.
      final activity = File('android/app/src/main/kotlin/com/silarah/app/MainActivity.kt')
          .readAsStringSync();
      final channel = File('android/app/src/main/kotlin/com/silarah/app/CallPlatformChannel.kt')
          .readAsStringSync();
      final onCreate = activity.substring(activity.indexOf('override fun onCreate('),
          activity.indexOf('override fun configureFlutterEngine('));
      expect(onCreate, contains('wakeForIncomingRing(intent)'));
      expect(activity, contains('override fun onNewIntent(intent: Intent)'));
      expect(activity, contains('if (isIncomingRingLaunch(intent)) applyCallWindow(this, true)'));
      // The native check reads the same payload the Dart side writes.
      final payload = IncomingCallPush(
        requestId: 'r', matchId: 'm', callerName: 'A', declineToken: 't',
        expiresAt: DateTime(2030), forUser: 'u',
      ).toPayload();
      for (final key in ['request_id', 'for_user', 'expires_at']) {
        expect(channel, contains('"$key"'));
        expect(payload, contains('"$key"'));
      }
      expect(channel, contains('"SELECT_NOTIFICATION"'));
      // A ring that is not shown gives the lock screen back.
      final main = File('lib/main.dart').readAsStringSync();
      final handler = main.substring(main.indexOf('void _onCallNotification('),
          main.indexOf('void _openCallScreen('));
      expect('releaseRingWindow()'.allMatches(handler).length, 3);
    });
  });
}

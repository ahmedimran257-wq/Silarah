// Late ring pushes (docs/voice_calling_spec.md 12.2, staging gate 10): a
// ring that reaches the phone after its ring time is shown as a missed call
// and never rings; a ring that reaches the phone after its call was
// cancelled, declined or answered never rings.
//
// How each case is held:
//  * Older than its ring: FCM drops it (TTL = ring time, on Google's clock,
//    so a wrong phone clock does not matter). The server's watchdog ends the
//    ring and sends the missed-call push (kept a day) and a cancel push.
//  * After its call ended: the phone remembers every ring that ended here
//    (cancel, ended, missed, answered or declined here) and drops a ring push
//    for one of them, whatever order FCM delivers the pushes in.
//  * The ring time on the phone counts from arrival on the phone's own clock.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_notifications.dart';

const _me = 'me';

Map<String, dynamic> _ringData(String requestId, {String? ringSeconds = '30', String? expiresAt}) => {
      'type': 'call_incoming',
      'request_id': requestId,
      'match_id': 'm',
      'caller_id': 'caller',
      'caller_name': 'Ahmed',
      'decline_token': 'a' * 48,
      if (ringSeconds != null) 'ring_seconds': ringSeconds,
      'expires_at': expiresAt ?? DateTime.now().toUtc().add(const Duration(seconds: 30)).toIso8601String(),
      'for_user': _me,
    };

Map<String, dynamic> _cancelData(String requestId, {String type = 'call_cancel'}) =>
    {'type': type, 'request_id': requestId, 'for_user': _me};

Map<String, dynamic> _missedData(String requestId) => {
      'type': 'call_missed',
      'request_id': requestId,
      'match_id': 'm',
      'caller_id': 'caller',
      'caller_name': 'Ahmed',
      'count': '1',
      'variant': 'missed',
      'silent': '0',
      'for_user': _me,
    };

String _read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CallNotifications.rememberSignedInUser(_me);
  });

  test('a fresh ring push rings (the baseline for every case below)', () async {
    final push = await CallNotifications.handlePushData(_ringData('r-fresh'));
    expect(push?.requestId, 'r-fresh');
  });

  group('a ring push older than its ring time', () {
    test('the server lets a ring push live only as long as the ring', () {
      final calls = _read('supabase/functions/calls/index.ts');
      final ring = calls.substring(calls.indexOf('type: "call_incoming"'));
      // The TTL is the ring time; only phones that can ring get it.
      expect(ring.substring(0, ring.indexOf(');') + 2), contains('}, ringSeconds, { ringOnly: true });'));
      expect(_read('supabase/functions/_shared/fcm_push.ts'), contains(r'ttl: `${Math.max(1, ttlSeconds)}s`'));
    });

    test('when the ring runs out the server sends the missed call (kept a day) and a cancel', () {
      final sql = _read('supabase/migrations/323_voice_calling.sql');
      final sweep = sql.substring(sql.indexOf('CREATE FUNCTION private.call_expire_ringing'));
      final body = sweep.substring(0, sweep.indexOf(r'$function$;'));
      expect(body, contains("SET status = 'missed', reason = 'timeout'"));
      expect(body, contains('private.call_queue_missed_note(v_id)'));
      expect(body, contains("private.call_enqueue_job('cancel_ring'"));
      expect(sql, contains("SELECT cron.schedule('voice_call_watchdog_10s', '10 seconds'"));
      expect(_read('supabase/functions/_shared/call_push.ts'),
          contains('export const MISSED_PUSH_TTL_SECONDS = 24 * 3600;'));
      final worker = _read('supabase/functions/call-worker/index.ts');
      expect(worker, contains('missedCallPush(info), MISSED_PUSH_TTL_SECONDS'));
    });

    test('a ring read after its time never rings (a tapped payload, or a server without ring_seconds)', () async {
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 1)).toIso8601String();
      expect(await CallNotifications.handlePushData(_ringData('r-old', ringSeconds: null, expiresAt: past)), isNull);
      final tapped = IncomingCallPush.fromPayload(
          IncomingCallPush.fromData(_ringData('r-old'), receivedAt: DateTime.now().subtract(const Duration(minutes: 1)))!
              .toPayload())!;
      expect(shouldRing(tapped, signedInUserId: _me, now: DateTime.now()), isFalse);
    });

    test('the missed call shows, and its ring push coming after it never rings', () async {
      expect(await CallNotifications.handlePushData(_missedData('r-late')), isNull);
      expect(await CallNotifications.handlePushData(_ringData('r-late')), isNull);
      // Another call still rings.
      expect((await CallNotifications.handlePushData(_ringData('r-next')))?.requestId, 'r-next');
    });

    test('the missed-call notice reads as a missed call from the caller', () {
      final missed = MissedCallPush.fromData(_missedData('r-late'))!;
      expect(missed.requestId, 'r-late');
      expect(missed.forUser, _me);
      final text = missedCallText('en', missed);
      expect(text.title, 'Missed call from Ahmed');
      expect(text.body, 'Tap to see your calls');
    });
  });

  group('a ring push after its call already ended', () {
    test('cancelled by the caller, declined, or answered on another phone (call_cancel first)', () async {
      await CallNotifications.handlePushData(_cancelData('r-cancel'));
      expect(await CallNotifications.handlePushData(_ringData('r-cancel')), isNull);
    });

    test('ended by the server (call_ended first)', () async {
      await CallNotifications.handlePushData(_cancelData('r-ended', type: 'call_ended'));
      expect(await CallNotifications.handlePushData(_ringData('r-ended')), isNull);
    });

    test('answered or declined on this phone: a repeated ring push never rings again', () async {
      expect(await CallNotifications.handlePushData(_ringData('r-here')), isNotNull);
      // What the call screen does as it answers or declines.
      await CallNotifications.cancel('r-here');
      expect(await CallNotifications.handlePushData(_ringData('r-here')), isNull);
    });

    test('in the app, a cancel that came first wins even while the ring is still being read', () async {
      // The app does not wait between pushes: both start at once.
      final cancelling = CallNotifications.handlePushData(_cancelData('r-race'));
      final ringing = CallNotifications.handlePushData(_ringData('r-race'));
      await cancelling;
      expect(await ringing, isNull);
    });

    test('pushes are handled in the order they came: ring, then its cancel', () async {
      // A cancel finished before its ring was shown would leave the ring
      // ringing to its end.
      final done = <String>[];
      final ringing = CallNotifications.handlePushData(_ringData('r-order'))
          .then((push) => done.add(push == null ? 'ring dropped' : 'rang'));
      final cancelling = CallNotifications.handlePushData(_cancelData('r-order')).then((_) => done.add('cancelled'));
      await Future.wait([ringing, cancelling]);
      expect(done, ['rang', 'cancelled']);
      expect(await CallNotifications.handlePushData(_ringData('r-order')), isNull);
    });

    test('an unreadable ring push is dropped and the next still rings', () async {
      final broken = CallNotifications.handlePushData({'type': 'call_incoming'});
      expect(await broken, isNull);
      expect((await CallNotifications.handlePushData(_ringData('r-after')))?.requestId, 'r-after');
    });

    test('the list of ended rings stays short and keeps the newest', () async {
      for (var i = 0; i < 70; i++) {
        await CallNotifications.cancel('r-$i');
      }
      final prefs = await SharedPreferences.getInstance();
      final ended = prefs.getStringList('silarah_call_ended_rings_v1')!;
      expect(ended.length, 50);
      expect(ended.last, 'r-69');
      expect(ended, isNot(contains('r-0')));
      expect(await CallNotifications.handlePushData(_ringData('r-69')), isNull);
      // Ending the same ring twice keeps one entry.
      await CallNotifications.cancel('r-69');
      expect(prefs.getStringList('silarah_call_ended_rings_v1')!.where((id) => id == 'r-69'), hasLength(1));
    });

    test('another account is still never rung', () async {
      await CallNotifications.rememberSignedInUser('someone-else');
      expect(await CallNotifications.handlePushData(_ringData('r-other')), isNull);
    });
  });

  group("a wrong phone clock (the ring counts from arrival on this phone's clock)", () {
    // The server's own idea of the ring's end, far from the phone's clock.
    const serverExpiry = '2026-11-22T10:00:30Z';

    for (final offset in [const Duration(hours: 3), -const Duration(hours: 3), const Duration(days: 400)]) {
      test('phone clock off by $offset still rings the full ring_seconds, then stops', () {
        final received = DateTime.utc(2026, 11, 22, 10).add(offset);
        final push = IncomingCallPush.fromData(
          _ringData('r-skew', ringSeconds: '30', expiresAt: serverExpiry),
          receivedAt: received,
        )!;
        expect(push.expiresAt, received.add(const Duration(seconds: 30)));
        expect(shouldRing(push, signedInUserId: _me, now: received.add(const Duration(seconds: 29))), isTrue);
        expect(shouldRing(push, signedInUserId: _me, now: received.add(const Duration(seconds: 31))), isFalse);
      });
    }

    test('a ring tapped later keeps the end on the phone clock it rang by', () {
      final received = DateTime(2031, 5, 1, 9); // a phone years ahead
      final push = IncomingCallPush.fromData(_ringData('r-tap', expiresAt: serverExpiry), receivedAt: received)!;
      final back = IncomingCallPush.fromPayload(push.toPayload())!;
      expect(back.expiresAt, push.expiresAt);
      expect(shouldRing(back, signedInUserId: _me, now: received.add(const Duration(seconds: 31))), isFalse);
    });

    test('a broken ring time never rings longer than two minutes', () {
      final received = DateTime.utc(2026, 11, 22, 10);
      final push = IncomingCallPush.fromData(_ringData('r-long', ringSeconds: '99999'), receivedAt: received)!;
      expect(push.expiresAt, received.add(const Duration(seconds: 120)));
    });

    test('a cancel needs no clock: it drops the ring on a phone whose clock is far off', () async {
      await CallNotifications.handlePushData(_cancelData('r-skew-cancel'));
      final data = _ringData('r-skew-cancel', expiresAt: serverExpiry);
      expect(await CallNotifications.handlePushData(data), isNull);
    });
  });
}

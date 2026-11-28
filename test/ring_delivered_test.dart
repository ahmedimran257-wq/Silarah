// "Calling…" until the ring reaches the other phone, "Ringing…" after, and
// only a ring that reached it counts towards the unanswered-call limit
// (migration 332; found on the phones 25 Nov 2026 with the callee's mobile
// data off).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/call_notifications.dart';

const _me = 'me';

Map<String, dynamic> _ring(String requestId) => {
      'type': 'call_incoming',
      'request_id': requestId,
      'match_id': 'm',
      'caller_id': 'caller',
      'caller_name': 'Ahmed',
      'decline_token': 'b' * 48,
      'ring_seconds': '30',
      'expires_at': DateTime.now().toUtc().add(const Duration(seconds: 30)).toIso8601String(),
      'for_user': _me,
    };

String _read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("the callee's phone sends the ring's receipt", () {
    final sent = <Map<String, dynamic>>[];
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CallNotifications.rememberSignedInUser(_me);
      sent.clear();
      CallNotifications.receiptEndpoint = 'https://example.test/functions/v1/calls';
      CallNotifications.post = (url, headers, body) async {
        expect(headers.containsKey('Authorization'), isFalse, reason: 'no session needed');
        sent.add(jsonDecode(body) as Map<String, dynamic>);
        return 200;
      };
    });
    tearDown(() => CallNotifications.receiptEndpoint = null);

    test('once the ring shows, proven with the ring token', () async {
      final push = await CallNotifications.handlePushData(_ring('r1'));
      expect(push, isNotNull);
      await CallNotifications.receiptsSent();
      expect(sent, [
        {'action': 'ring_delivered', 'request_id': 'r1', 'token': 'b' * 48},
      ]);
    });

    test('never for a ring that does not show (another account, already ended)', () async {
      await CallNotifications.handlePushData({..._ring('r2'), 'for_user': 'someone else'});
      await CallNotifications.cancel('r3');
      await CallNotifications.handlePushData(_ring('r3'));
      await CallNotifications.receiptsSent();
      expect(sent, isEmpty);
    });

    test('one retry when the first try fails', () async {
      var tries = 0;
      CallNotifications.post = (url, headers, body) async => ++tries == 1 ? 503 : 200;
      await CallNotifications.handlePushData(_ring('r4'));
      await CallNotifications.receiptsSent();
      expect(tries, 2);
    });

    test('the background handler waits for it before Android may stop Silarah', () {
      final main = _read('lib/main.dart');
      final handler = main.substring(main.indexOf('Future<void> silarahFirebaseMessagingBackgroundHandler('));
      expect(handler.substring(0, handler.indexOf('\n}\n')), contains('await CallNotifications.receiptsSent();'));
    });
  });

  group("the caller's screen", () {
    ({CallController call, void Function(Map<String, dynamic>) reply}) ringing() {
      var next = <String, dynamic>{'outcome': 'ringing', 'delivered': false};
      final call = CallController(
        api: CallApi(invoke: (body) async => next, rpc: (_, __) async => null),
      )
        ..requestId = 'r1'
        ..isCaller = true
        ..phase = CallPhase.outgoing
        ..ringEndsAt = DateTime.now().add(const Duration(seconds: 30));
      return (call: call, reply: (value) => next = value);
    }

    testWidgets('"Calling…" until the ring reaches the other phone, then "Ringing…"', (tester) async {
      final (:call, :reply) = ringing();
      expect(call.outgoingStatus, 'Calling…');
      call.nudge('r1');
      await tester.pump();
      expect(call.outgoingStatus, 'Calling…', reason: 'not delivered yet');
      reply({'outcome': 'ringing', 'delivered': true});
      call.nudge('r1');
      await tester.pump();
      expect(call.outgoingStatus, 'Ringing…');
    });

    testWidgets("a ring that never arrived ends as \"Couldn't reach their phone\"", (tester) async {
      final (:call, :reply) = ringing();
      reply({'outcome': 'missed', 'delivered': false});
      call.nudge('r1');
      await tester.pump();
      expect(call.endedCopy, CallEndCopy.unreachable);
      await tester.pump(const Duration(seconds: 3)); // "Call ended" goes after 2 s
    });

    testWidgets('every other ending stays "Not answered" (declined, silenced, refused are never told)', (tester) async {
      for (final ended in [
        {'outcome': 'missed', 'delivered': true},
        {'outcome': 'declined', 'delivered': false},
        {'outcome': 'unavailable', 'delivered': false},
      ]) {
        final (:call, :reply) = ringing();
        reply(ended);
        call.nudge('r1');
        await tester.pump();
        expect(call.endedCopy, CallEndCopy.notAnswered, reason: '$ended');
        await tester.pump(const Duration(seconds: 3)); // "Call ended" goes after 2 s
      }
    });
  });

  test('the server: a receipt with the ring token, and the limit counts only rings that arrived', () {
    final sql = _read('supabase/migrations/332_ring_delivered.sql');
    expect(sql, contains('ADD COLUMN delivered_at timestamptz'));
    expect(sql, contains("encode(extensions.digest(p_token, 'sha256'), 'hex') <> v_request.decline_token_hash"));
    expect(sql, isNot(contains('decline_token_hash = NULL')), reason: 'the receipt never uses up the Decline token');
    expect(sql, contains("OR (r.status IN ('cancelled', 'missed') AND r.delivered_at IS NOT NULL)"));
    final calls = _read('supabase/functions/calls/index.ts');
    expect(calls, contains('if (action === "ring_delivered") {'));
    expect(
      calls.indexOf('if (action === "ring_delivered") {'),
      lessThan(calls.indexOf('const userId = await authenticatedUserId(req);')),
      reason: 'no session: Silarah may be closed',
    );
  });
}

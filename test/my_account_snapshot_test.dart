import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:silarah/core/services/my_account_snapshot.dart';

http.Request _request(String method, String path) =>
    http.Request(method, Uri.parse('https://project.supabase.co$path'));

void main() {
  tearDown(MyAccountSnapshot.invalidate);

  group('AccountScopedRead', () {
    test('concurrent and recent readers share one request', () async {
      var loads = 0;
      final read = AccountScopedRead<int>(
        freshness: const Duration(minutes: 1),
        load: (_) async => ++loads,
      );

      final results = await Future.wait([read.read('a'), read.read('a')]);
      expect(results, [1, 1]);
      expect(await read.read('a'), 1);
      expect(loads, 1);
    });

    test('force and another member always reach the server', () async {
      var loads = 0;
      final read = AccountScopedRead<int>(
        freshness: const Duration(minutes: 1),
        load: (_) async => ++loads,
      );

      expect(await read.read('a'), 1);
      expect(await read.read('a', force: true), 2);
      expect(await read.read('b'), 3);
      expect(loads, 3);
    });

    test('zero freshness only joins a request still in flight', () async {
      var loads = 0;
      final read = AccountScopedRead<int>(load: (_) async => ++loads);

      final results = await Future.wait([read.read('a'), read.read('a')]);
      expect(results, [1, 1]);
      expect(await read.read('a'), 2);
    });

    test('a read in flight across a write is neither joined nor cached',
        () async {
      final gates = <Completer<int>>[];
      final read = AccountScopedRead<int>(
        freshness: const Duration(minutes: 1),
        load: (_) {
          final gate = Completer<int>();
          gates.add(gate);
          return gate.future;
        },
      );

      final beforeWrite = read.read('a');
      MyAccountSnapshot.invalidate();
      final afterWrite = read.read('a');
      expect(gates, hasLength(2));

      gates[0].complete(1);
      gates[1].complete(2);
      expect(await beforeWrite, 1);
      expect(await afterWrite, 2);
      expect(await read.read('a'), 2);
      expect(gates, hasLength(2));
    });
  });

  group('AccountSnapshotInvalidatingClient', () {
    test('classifies only account-changing requests as writes', () {
      bool write(String method, String path) =>
          AccountSnapshotInvalidatingClient.isAccountWrite(
              _request(method, path));

      expect(write('GET', '/rest/v1/users'), isFalse);
      expect(write('HEAD', '/rest/v1/photos'), isFalse);
      expect(write('POST', '/rest/v1/rpc/get_my_premium_entitlement'), isFalse);
      expect(write('POST', '/rest/v1/rpc/record_user_presence'), isFalse);
      expect(write('POST', '/rest/v1/rpc/register_my_fcm_token'), isFalse);
      expect(write('POST', '/auth/v1/token'), isFalse);

      // The snapshot holds deletion_status, which this RPC changes.
      expect(write('POST', '/rest/v1/rpc/cancel_my_account_deletion'), isTrue);
      expect(write('POST', '/rest/v1/rpc/patch_my_user'), isTrue);
      expect(write('POST', '/rest/v1/rpc/save_my_profile_bundle'), isTrue);
      expect(write('POST', '/rest/v1/rpc/set_profile_pause'), isTrue);
      expect(write('PATCH', '/rest/v1/notification_prefs'), isTrue);
      expect(write('POST', '/functions/v1/photo-verification'), isTrue);
      expect(write('POST', '/storage/v1/object/profile-photos/a.jpg'), isTrue);
    });

    test('a locale-only user patch keeps the snapshot', () {
      bool patch(Map<String, Object?> fields) =>
          AccountSnapshotInvalidatingClient.isAccountWrite(
            _request('POST', '/rest/v1/rpc/patch_my_user')
              ..body = jsonEncode({'p_fields': fields}),
          );

      expect(patch({'preferred_language': 'en', 'timezone': 'Asia/Kolkata'}),
          isFalse);
      expect(patch({'preferred_language': 'en', 'country_code': 'IN'}), isTrue);
      expect(patch({'onboarding_completed': true}), isTrue);
      expect(patch({}), isTrue);
    });

    test('a completed write makes the next read go to the server', () async {
      var loads = 0;
      final read = AccountScopedRead<int>(
        freshness: const Duration(minutes: 1),
        load: (_) async => ++loads,
      );
      final client = AccountSnapshotInvalidatingClient(
        MockClient((request) async => http.Response('[]', 200)),
      );
      addTearDown(client.close);

      expect(await read.read('a'), 1);
      await client.send(_request('POST', '/rest/v1/rpc/get_chat_inbox'));
      expect(await read.read('a'), 1);
      await client.send(_request('POST', '/rest/v1/rpc/patch_my_user'));
      expect(await read.read('a'), 2);
    });
  });

  test('the shared users read never selects moderation-only columns', () {
    expect(MyAccountSnapshot.userColumns, isNot(contains('shadow')));
    expect(MyAccountSnapshot.userColumns, isNot(contains('*')));
    expect(MyAccountSnapshot.profileColumns, isNot(contains('*')));
    expect(MyAccountSnapshot.profileColumns,
        isNot(contains('guardian_phone_encrypted')));
  });

  test('Supabase traffic goes through the invalidating client', () {
    final service =
        File('lib/core/services/supabase_service.dart').readAsStringSync();
    expect(service, contains('httpClient: AccountSnapshotInvalidatingClient('));
  });
}

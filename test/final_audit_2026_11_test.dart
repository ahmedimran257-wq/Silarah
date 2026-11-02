// Regression tests for the final pre-launch audit (November 2026).
// See docs/final_audit_2026-11.md.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/models/discovery_profile.dart';
import 'package:silarah/core/services/request_timeout_client.dart';
import 'package:silarah/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _me = '00000000-0000-0000-0000-00000000000a';
const _them = DiscoveryProfile(
  id: '00000000-0000-0000-0000-00000000000b',
  firstName: 'Member',
  lastNameInitial: 'S',
  age: 28,
  cityName: 'Kurnool',
);

Map<String, dynamic> _session(String userId) => {
      'access_token': 'fixture-access-token',
      'refresh_token': 'fixture-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': userId,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      },
    };

String _migration(String name) =>
    File('supabase/migrations/$name').readAsStringSync();

String _source(String path) => File(path).readAsStringSync();

/// The body of one CREATE FUNCTION statement in [sql].
String _function(String sql, String name) {
  final start = sql.indexOf('CREATE OR REPLACE FUNCTION public.$name(');
  expect(start, isNonNegative, reason: '$name is defined');
  final end = sql.indexOf(r'$function$;', start);
  return sql.substring(start, end);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('interest sends', () {
    late SupabaseClient client;
    late InterestsCubit cubit;
    late List<http.Request> requests;
    late FutureOr<http.Response> Function(http.Request) sendInterestReply;

    http.Response json(Object body, http.Request request, [int status = 200]) =>
        http.Response(jsonEncode(body), status,
            request: request, headers: {'content-type': 'application/json'});

    setUp(() async {
      requests = [];
      sendInterestReply = (request) => json('interest-1', request);
      client = SupabaseClient('https://audit.example.invalid', 'fixture-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/rpc/send_interest')) {
          return sendInterestReply(request);
        }
        return json(<Object>[], request);
      }));
      await client.auth.setInitialSession(jsonEncode(_session(_me)));
      SupabaseService.initializeForTesting(client);
      cubit = InterestsCubit();
    });

    tearDown(() async {
      await cubit.close();
      SupabaseService.reset();
      await client.dispose();
    });

    int sendCount() =>
        requests.where((r) => r.url.path.endsWith('/rpc/send_interest')).length;

    test('a double tap sends one interest, not two', () async {
      final gate = Completer<void>();
      sendInterestReply = (request) async {
        await gate.future;
        return json('interest-1', request);
      };

      final first = cubit.sendInterest(_them);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.isSendingInterest(_them.id), isTrue);
      final second = cubit.sendInterest(_them);
      gate.complete();

      expect(await second, isFalse, reason: 'the second tap is not a new send');
      expect(await first, isTrue);
      expect(sendCount(), 1);
      expect(cubit.isSendingInterest(_them.id), isFalse);
    });

    test('an interest the server already has refreshes the screen', () async {
      sendInterestReply = (request) => json({
            'code': 'P0001',
            'message': 'interest_already_active',
            'details': null,
            'hint': null,
          }, request, 400);

      expect(await cubit.sendInterest(_them), isFalse);
      final afterSend =
          requests.indexWhere((r) => r.url.path.endsWith('/rpc/send_interest'));
      final reloads = requests
          .skip(afterSend + 1)
          .where((r) => r.url.path.endsWith('/rest/v1/interests'));
      expect(reloads, isNotEmpty,
          reason: 'the stale button is replaced by the server state');
    });

    test('server error codes for an existing relationship are recognised', () {
      for (final code in ['interest_already_active', 'already_matched']) {
        expect(
          InterestsCubit.isRelationshipAlreadyActive(
              PostgrestException(message: code, code: 'P0001')),
          isTrue,
          reason: code,
        );
      }
      expect(
        InterestsCubit.isRelationshipAlreadyActive(
            const PostgrestException(message: 'profile_unavailable')),
        isFalse,
      );
    });
  });

  group('migration 288: a block ends profile reads', () {
    final sql = _migration('288_member_reads_honour_blocks.sql');

    test('every member read closes once the owner has blocked you', () {
      for (final name in [
        'get_authorized_member_profiles',
        'get_member_trust_summaries',
        'get_photo_access_context',
      ]) {
        final body = _function(sql, name);
        expect(body, contains('owner_block.blocker_id = p.user_id'),
            reason: name);
      }
      final preferences =
          _function(sql, 'get_discovery_compatibility_preferences');
      expect(preferences, contains('b.blocker_id = p.user_id'));
      expect(preferences, contains('can_access_incognito_profile'));
    });

    test('"they blocked me" is no longer a route to their profile', () {
      final body = _function(sql, 'get_authorized_member_profiles');
      expect(body, isNot(contains('b.blocked_id = v_me AND b.blocker_id')));
      // The blocked-members list still names the people you blocked.
      expect(
          body, contains('b.blocker_id = v_me AND b.blocked_id = p.user_id'));
      // A guardian reading for a ward is closed when the ward is blocked.
      expect(body, contains('ward_block.blocked_id = gcm.ward_id'));
    });

    test('grants stay members and service role only', () {
      for (final signature in [
        'get_authorized_member_profiles(uuid[])',
        'get_member_trust_summaries(uuid[])',
        'get_discovery_compatibility_preferences(uuid[])',
        'get_photo_access_context(uuid)',
      ]) {
        expect(
            sql,
            contains(
                'REVOKE ALL ON FUNCTION public.$signature FROM PUBLIC, anon;'));
        expect(
            sql,
            contains(
                'GRANT EXECUTE ON FUNCTION public.$signature TO authenticated, service_role;'));
      }
    });
  });

  group('stalled connections end in an error, not a spinner', () {
    http.Request request(String path) =>
        http.Request('POST', Uri.parse('https://x.supabase.co$path'));

    test('limits follow the kind of request', () {
      expect(
          RequestTimeoutClient.timeoutFor(
              request('/rest/v1/rpc/send_interest')),
          RequestTimeoutClient.rest);
      expect(
          RequestTimeoutClient.timeoutFor(
              request('/functions/v1/validate-photo-upload')),
          RequestTimeoutClient.functions);
      expect(
          RequestTimeoutClient.timeoutFor(
              request('/storage/v1/object/upload/sign/profile-photos/a.jpg')),
          RequestTimeoutClient.storage);
      expect(RequestTimeoutClient.storage,
          greaterThan(RequestTimeoutClient.functions));
      expect(RequestTimeoutClient.functions,
          greaterThan(RequestTimeoutClient.rest));
    });

    test('a request with no answer fails after its limit', () {
      fakeAsync((clock) {
        final never = Completer<http.Response>();
        final client = RequestTimeoutClient(MockClient((_) => never.future));
        Object? failure;
        client
            .send(request('/rest/v1/rpc/get_chat_inbox'))
            .then<void>((_) {}, onError: (Object error) => failure = error);
        clock.elapse(RequestTimeoutClient.rest - const Duration(seconds: 1));
        expect(failure, isNull);
        clock.elapse(const Duration(seconds: 2));
        expect(failure, isA<TimeoutException>());
      });
    });

    test('the app client uses the limit beneath the snapshot invalidation', () {
      final service = _source('lib/core/services/supabase_service.dart');
      expect(
          service,
          contains(
              'AccountSnapshotInvalidatingClient(RequestTimeoutClient())'));
    });
  });

  group('write buttons ignore a second tap', () {
    test('who-viewed-me does not send twice or show a false error', () {
      final screen =
          _source('lib/features/home/screens/profile_views_screen.dart');
      expect(screen, contains('.isSendingInterest('));
    });

    test('profile detail opens one note sheet per send', () {
      final screen =
          _source('lib/features/home/screens/profile_detail_screen.dart');
      expect(screen, contains('if (_sendingInterest) return;'));
    });

    test('account deletion sends one request and cannot hang', () {
      final screen =
          _source('lib/features/home/screens/delete_account_screen.dart');
      expect(screen, contains('if (_submitting) return;'));
      expect(screen, contains("'request_my_account_deletion'"));
      expect(screen, contains('.timeout(const Duration(seconds: 20))'));
    });
  });
}

// Regression tests for the interest, chat suspension, notification and
// sharing fixes from the pre-testing audit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';
import 'package:silarah/core/cubits/notifications/notifications_cubit.dart';
import 'package:silarah/core/models/discovery_profile.dart';
import 'package:silarah/core/services/referral_service.dart';
import 'package:silarah/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _me = '00000000-0000-0000-0000-00000000000a';
const _sender = '00000000-0000-0000-0000-00000000000b';
const _interestId = '00000000-0000-0000-0000-0000000000c1';
const _matchId = '00000000-0000-0000-0000-0000000000d1';
const _them = DiscoveryProfile(
  id: _sender,
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

Map<String, dynamic> _pgError(String message) => {
      'code': 'P0001',
      'message': message,
      'details': null,
      'hint': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;
  late List<http.Request> requests;
  late FutureOr<http.Response?> Function(http.Request) reply;

  http.Response json(Object body, http.Request request, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          request: request, headers: {'content-type': 'application/json'});

  bool isPath(http.Request request, String suffix) =>
      request.url.path.endsWith(suffix);

  int countOf(String suffix) =>
      requests.where((request) => isPath(request, suffix)).length;

  setUp(() async {
    requests = [];
    reply = (_) => null;
    client = SupabaseClient('https://audit.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requests.add(request);
      return await reply(request) ?? json(<Object>[], request);
    }));
    await client.auth.setInitialSession(jsonEncode(_session(_me)));
    SupabaseService.initializeForTesting(client);
  });

  tearDown(() async {
    SupabaseService.reset();
    await client.dispose();
  });

  /// Answers the Interests load with one interest from [_sender] and, when
  /// [matched], an active match with them.
  http.Response? interestsLoad(
    http.Request request, {
    String interestStatus = 'pending',
    bool matched = false,
  }) {
    if (isPath(request, '/rest/v1/interests') &&
        request.url.queryParameters.containsKey('receiver_id')) {
      return json([
        {
          'id': _interestId,
          'sender_id': _sender,
          'note': null,
          'status': interestStatus,
          'created_at': '2026-11-01T00:00:00Z',
          'expires_at': '2026-12-01T00:00:00Z',
        }
      ], request);
    }
    if (isPath(request, '/rpc/get_my_matches')) {
      return json([
        if (matched)
          {
            'id': _matchId,
            'user_a': _me,
            'user_b': _sender,
            'status': 'active',
            'created_at': '2026-11-02T00:00:00Z',
          }
      ], request);
    }
    if (isPath(request, '/rpc/get_authorized_member_profiles')) {
      return json([
        {
          'id': 'profile-1',
          'user_id': _sender,
          'first_name': 'Member',
          'last_name_initial': 'S',
          'age': 28,
          'city_name': 'Kurnool',
        }
      ], request);
    }
    if (isPath(request, '/rest/v1/photos')) {
      return json([
        {'profile_id': 'profile-1', 'blurhash': 'hash'}
      ], request);
    }
    return null;
  }

  group('interest send failures', () {
    late InterestsCubit cubit;

    setUp(() => cubit = InterestsCubit());
    tearDown(() => cubit.close());

    test('server rejections map to a clear reason', () {
      const expected = {
        'rematch_cooldown': InterestSendFailure.rematchCooldown,
        'interest_note_too_long': InterestSendFailure.noteTooLong,
        'new row violates check constraint "interests_note_check"':
            InterestSendFailure.noteTooLong,
        'interest_already_active': InterestSendFailure.alreadyConnected,
        'already_matched': InterestSendFailure.alreadyConnected,
        'profile_unavailable': InterestSendFailure.profileUnavailable,
        'account_restricted': InterestSendFailure.accountRestricted,
        'Failed host lookup': InterestSendFailure.generic,
      };
      expected.forEach((message, failure) {
        expect(
          InterestsCubit.classifySendFailure(
            PostgrestException(message: message),
          ),
          failure,
          reason: message,
        );
      });
    });

    test('a rejected send reports its reason once', () async {
      reply = (request) => isPath(request, '/rpc/send_interest')
          ? json(_pgError('rematch_cooldown'), request, 400)
          : null;

      expect(await cubit.sendInterest(_them), isFalse);
      expect(cubit.takeSendFailure(), InterestSendFailure.rematchCooldown);
      expect(cubit.takeSendFailure(), isNull);
    });

    test('the daily limit stays with its own sheet', () async {
      reply = (request) => isPath(request, '/rpc/send_interest')
          ? json(_pgError('interest_quota_exhausted'), request, 400)
          : null;

      expect(await cubit.sendInterest(_them), isFalse);
      expect(cubit.takeSendFailure(), isNull);
      expect(cubit.state.limitError, isTrue);
    });

    test('starting a new attempt forgets an unread failure', () async {
      reply = (request) => isPath(request, '/rpc/send_interest')
          ? json(_pgError('profile_unavailable'), request, 400)
          : null;
      await cubit.sendInterest(_them);

      await cubit.canStartInterest();

      expect(cubit.takeSendFailure(), isNull);
    });
  });

  group('interests loading', () {
    late InterestsCubit cubit;

    setUp(() => cubit = InterestsCubit());
    tearDown(() => cubit.close());

    test('a photo-signing failure still loads interests', () async {
      reply = (request) {
        if (isPath(request, '/functions/v1/get-signed-url')) {
          return json({'error': 'signing down'}, request, 500);
        }
        return interestsLoad(request);
      };

      await cubit.loadData(force: true);

      expect(cubit.state.received.single.id, _interestId);
      expect(cubit.state.received.single.profile.photoUrl, isNull);
      expect(countOf('/functions/v1/get-signed-url'), 1);
    });

    test('a failed load is not treated as fresh', () async {
      var fail = true;
      reply = (request) {
        if (fail && isPath(request, '/rpc/get_my_matches')) {
          return json(_pgError('boom'), request, 500);
        }
        return interestsLoad(request);
      };

      await cubit.loadData();
      expect(countOf('/rpc/get_my_matches'), 1);

      fail = false;
      await cubit.loadData();
      expect(countOf('/rpc/get_my_matches'), 2,
          reason: 'the failed load must be retried');
      expect(cubit.state.received, hasLength(1));

      await cubit.loadData();
      expect(countOf('/rpc/get_my_matches'), 2,
          reason: 'a successful load stays fresh');
    });
  });

  group('accepting interests', () {
    late InterestsCubit cubit;

    setUp(() => cubit = InterestsCubit());
    tearDown(() => cubit.close());

    test('accepted on a second device reports the match', () async {
      var acceptedElsewhere = false;
      reply = (request) {
        if (isPath(request, '/rpc/respond_to_interest')) {
          acceptedElsewhere = true;
          return json(_pgError('interest_unavailable'), request, 400);
        }
        return interestsLoad(
          request,
          interestStatus: acceptedElsewhere ? 'accepted' : 'pending',
          matched: acceptedElsewhere,
        );
      };
      await cubit.loadData(force: true);

      expect(await cubit.acceptInterest(_interestId), isTrue);
      expect(cubit.state.matches.single.id, _matchId);
    });

    test('withdrawn elsewhere is still a failure', () async {
      reply = (request) {
        if (isPath(request, '/rpc/respond_to_interest')) {
          return json(_pgError('interest_unavailable'), request, 400);
        }
        return interestsLoad(request, interestStatus: 'expired');
      };
      await cubit.loadData(force: true);

      expect(await cubit.acceptInterest(_interestId), isFalse);
      expect(cubit.state.matches, isEmpty);
    });

    test('a locally accepted match carries the match id', () async {
      var accepted = false;
      reply = (request) {
        if (isPath(request, '/rpc/respond_to_interest')) {
          accepted = true;
          return json('accepted', request);
        }
        return interestsLoad(request, matched: accepted);
      };
      await cubit.loadData(force: true);

      expect(await cubit.acceptInterest(_interestId), isTrue);

      expect(cubit.state.matches.single.id, _matchId);
      expect(cubit.state.received.single.id, _interestId);

      cubit.markMatchClosed(_matchId);
      expect(cubit.state.matches, isEmpty);
    });
  });

  test('copyWith can clear a suspension lifted early', () {
    final suspended = ChatState(
      messagingSuspendedUntil: DateTime.now().add(const Duration(days: 3)),
    );
    expect(suspended.isSuspended, isTrue);

    expect(suspended.copyWith(isLoading: true).isSuspended, isTrue);
    final lifted = suspended.copyWith(clearMessagingSuspendedUntil: true);
    expect(lifted.messagingSuspendedUntil, isNull);
    expect(lifted.isSuspended, isFalse);
  });

  test('a failed notification fetch keeps the loaded items', () async {
    final cubit = NotificationsCubit();
    addTearDown(cubit.close);
    var fail = false;
    reply = (request) {
      if (!isPath(request, '/rest/v1/notifications')) return null;
      if (fail) return json(_pgError('boom'), request, 500);
      return json([
        {
          'id': 'notification-1',
          'type': 'new_message',
          'title': 'New message',
          'body': 'Hello',
          'read_at': null,
          'created_at': '2026-11-01T00:00:00Z',
          'deep_link': 'silarah://chat/abc',
        }
      ], request);
    };

    await cubit.loadNotifications(force: true);
    expect(cubit.state.items, hasLength(1));

    fail = true;
    await cubit.loadNotifications(force: true);
    expect(cubit.state.items, hasLength(1));
  });

  group('source contracts', () {
    String source(String path) => File(path).readAsStringSync();

    test('the note limit matches the database constraint', () {
      expect(
        source('lib/features/home/widgets/interest_note_sheet.dart'),
        contains('_maxLength = 150'),
      );
    });

    test('the open chat clears its own message notifications', () {
      final chat = source('lib/features/home/screens/chat_screen.dart');
      expect(chat, contains('notifications.stream.listen'));
      expect(chat, contains('isViewingConversationLink(n.deepLink)'));
    });

    test('shares never advertise a page that does not exist', () {
      final detail =
          source('lib/features/home/screens/profile_detail_screen.dart');
      final referral = source('lib/core/services/referral_service.dart');
      for (final text in [detail, referral]) {
        expect(text, isNot(contains('silarah.com/profile/')));
        expect(text, isNot(contains('silarah.com/r/')));
      }
    });

    test('Community and Mother tongue carry the Premium label', () {
      final sheet =
          source('lib/features/home/widgets/discovery_filter_sheet.dart');
      for (final label in ['MOTHER TONGUE', 'COMMUNITY / BIRADARI']) {
        final at = sheet.indexOf("label: '$label'");
        expect(at, isNonNegative, reason: label);
        expect(
          sheet.substring(at, at + 80),
          contains('premium: true'),
          reason: label,
        );
      }
    });
  });

  test('profile share text is honest and includes the code when known', () {
    final withCode =
        ReferralService.profileShareText(firstName: 'Aisha', code: 'ABC123');
    expect(withCode, contains('Aisha'));
    expect(withCode, contains('https://silarah.com'));
    expect(withCode, contains('ABC123'));
    expect(withCode, isNot(contains('/profile/')));

    final withoutCode = ReferralService.profileShareText(firstName: 'Aisha');
    expect(withoutCode, isNot(contains('Referral code')));
  });
}

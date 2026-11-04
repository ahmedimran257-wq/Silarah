import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:silarah/core/utils/expected_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // These were the four "crashes" Crashlytics showed for a stable build: a
  // phone without signal and a login ended on another device. They must be
  // recorded as non-fatal codes so real crashes stand out.
  group('expectedErrorCode', () {
    test('ended login is auth_session_ended', () {
      final error = AuthApiException(
        'Invalid Refresh Token: Refresh Token Not Found',
        statusCode: '400',
        code: 'refresh_token_not_found',
      );
      expect(expectedErrorCode(error), 'auth_session_ended');
      expect(isInvalidRefreshToken(error), isTrue);
    });

    test('offline token refresh is network_unreachable', () {
      final error = AuthRetryableFetchException(
        message:
            "ClientException with SocketException: Failed host lookup: 'example.supabase.co'",
      );
      expect(expectedErrorCode(error), 'network_unreachable');
    });

    test('failed host lookup from an http call is network_unreachable', () {
      final error = http.ClientException(
        "SocketException: Failed host lookup: 'example.supabase.co' (OS Error: No address associated with hostname, errno = 7)",
      );
      expect(expectedErrorCode(error), 'network_unreachable');
    });

    test('socket and timeout errors are network_unreachable', () {
      expect(expectedErrorCode(const SocketException('down')),
          'network_unreachable');
      expect(
          expectedErrorCode(TimeoutException('slow')), 'network_unreachable');
    });

    test('real bugs are still reported as crashes', () {
      expect(expectedErrorCode(StateError('bad state')), isNull);
      expect(expectedErrorCode(const FormatException('bad json')), isNull);
      expect(expectedErrorCode(http.ClientException('HTTP 500')), isNull);
      expect(
        expectedErrorCode(AuthApiException('Email not confirmed',
            statusCode: '400', code: 'email_not_confirmed')),
        isNull,
      );
    });
  });

  test('crash handlers and the auth listener use the classification', () {
    final main = File('lib/main.dart').readAsStringSync();
    final auth =
        File('lib/core/cubits/auth/auth_cubit.dart').readAsStringSync();
    expect(main, contains('expectedErrorCode(error)'));
    expect(main, contains('expectedErrorCode(details.exception)'));
    expect(main,
        contains("OperationalTelemetryService.record('uncaught', expected)"));
    expect(auth, contains('onError: _handleAuthStreamError'));
  });
}

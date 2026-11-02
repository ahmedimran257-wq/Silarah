import 'dart:async';

import 'package:http/http.dart' as http;

/// Gives every Supabase request an upper bound on waiting for a response.
///
/// Dart's HTTP client has no request timeout. On a stalled mobile connection
/// (a captive portal, or the phone moving between networks) a request whose
/// response never arrives waits until the operating system abandons the
/// socket, which can take many minutes, and the screen keeps its spinner the
/// whole time. A [TimeoutException] instead reaches the caller's existing
/// error path, the same way a dropped connection does.
///
/// The limit covers sending the request and receiving the response headers.
/// Photo uploads send up to 2 MB before the server can answer, and edge
/// functions do their own network work, so both get longer than table reads.
class RequestTimeoutClient extends http.BaseClient {
  RequestTimeoutClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  static const rest = Duration(seconds: 30);
  static const functions = Duration(seconds: 60);
  static const storage = Duration(seconds: 120);

  static Duration timeoutFor(http.BaseRequest request) {
    final segments = request.url.pathSegments;
    final service = segments.isEmpty ? '' : segments.first;
    return switch (service) {
      'storage' => storage,
      'functions' => functions,
      _ => rest,
    };
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final limit = timeoutFor(request);
    return _inner.send(request).timeout(
          limit,
          onTimeout: () => throw TimeoutException(
            'No response from ${request.url.host} within ${limit.inSeconds} s',
            limit,
          ),
        );
  }

  @override
  void close() => _inner.close();
}

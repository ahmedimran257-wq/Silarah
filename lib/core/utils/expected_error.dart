import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Errors the app expects in normal use and recovers from on its own.
///
/// A phone losing signal or a login that was ended on another device is not a
/// crash. Reporting these as fatal made Crashlytics show 0% crash-free users
/// for a stable app and would hide a real crash among them. The crash handlers
/// record these as rate-limited non-fatal codes instead.
///
/// Returns a stable, privacy-safe code, or null for anything unexpected.
String? expectedErrorCode(Object error) {
  if (isInvalidRefreshToken(error)) return 'auth_session_ended';
  if (error is AuthRetryableFetchException) return 'network_unreachable';
  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException) {
    return 'network_unreachable';
  }
  if (error is http.ClientException &&
      _looksLikeNetworkFailure(error.message)) {
    return 'network_unreachable';
  }
  return null;
}

/// A refresh token the server no longer accepts: the login was signed out
/// elsewhere, the account was deleted, or the token was already rotated.
bool isInvalidRefreshToken(Object error) {
  if (error is! AuthException) return false;
  if (error.code == 'refresh_token_not_found' ||
      error.code == 'refresh_token_already_used') {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('invalid refresh token') ||
      message.contains('refresh token not found') ||
      message.contains('refresh_token_not_found') ||
      message.contains('already used');
}

bool _looksLikeNetworkFailure(String message) {
  final text = message.toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('connection closed') ||
      text.contains('network is unreachable') ||
      text.contains('handshake');
}

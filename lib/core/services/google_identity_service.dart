// SILARAH - Google identity (Android Credential Manager)
// Returns a Google ID token bound to a fresh nonce. Supabase verifies the
// token and the nonce; this class never talks to Supabase itself.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

/// A Google ID token and the raw nonce whose SHA-256 it carries.
class GoogleIdToken {
  const GoogleIdToken({
    required this.idToken,
    required this.email,
    required this.rawNonce,
  });

  final String idToken;
  final String email;

  /// Sent to Supabase, which hashes it and compares with the token's claim.
  final String rawNonce;
}

enum GoogleIdTokenFailure {
  /// The member closed the account chooser.
  canceled,

  /// No Google account on the phone, no network, or the sheet could not open.
  unavailable,

  /// OAuth client, package name or signing certificate do not match.
  misconfigured,
}

class GoogleIdTokenException implements Exception {
  const GoogleIdTokenException(this.failure, [this.detail]);

  final GoogleIdTokenFailure failure;
  final String? detail;

  @override
  String toString() => 'GoogleIdTokenException($failure, $detail)';
}

abstract class GoogleIdTokenSource {
  /// Opens the Google account chooser and returns a fresh ID token.
  Future<GoogleIdToken> obtain();

  /// Clears the remembered Google choice when the member signs out, so the
  /// next sign-in asks which account to use.
  Future<void> forget();
}

class GoogleIdentityService implements GoogleIdTokenSource {
  GoogleIdentityService._();

  static final instance = GoogleIdentityService._();

  bool _initialized = false;

  /// The button shows only where native Google sign-in is configured: the
  /// Android app with a web client ID in this build's configuration.
  static bool get isAvailable =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      AppConfig.googleWebClientId.isNotEmpty;

  @override
  Future<GoogleIdToken> obtain() async {
    if (!isAvailable) {
      throw const GoogleIdTokenException(GoogleIdTokenFailure.misconfigured);
    }
    final rawNonce = generateRawNonce();
    try {
      // Every attempt needs its own nonce. The Android implementation only
      // stores these parameters for the next Credential Manager request, so
      // initialising again per attempt is how a fresh nonce reaches it.
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
        nonce: hashNonce(rawNonce),
      );
      _initialized = true;
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleIdTokenException(
          GoogleIdTokenFailure.misconfigured,
          'no_id_token',
        );
      }
      return GoogleIdToken(
        idToken: idToken,
        email: account.email,
        rawNonce: rawNonce,
      );
    } on GoogleSignInException catch (e) {
      throw GoogleIdTokenException(failureFor(e.code), e.code.name);
    }
  }

  @override
  Future<void> forget() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleIdentityService: clearing the Google choice failed: $e');
    }
  }

  @visibleForTesting
  static GoogleIdTokenFailure failureFor(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
        return GoogleIdTokenFailure.canceled;
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return GoogleIdTokenFailure.misconfigured;
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
        return GoogleIdTokenFailure.unavailable;
    }
  }

  /// 32 random bytes, URL-safe. Only its hash goes to Google.
  static String generateRawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String hashNonce(String rawNonce) =>
      sha256.convert(utf8.encode(rawNonce)).toString();
}

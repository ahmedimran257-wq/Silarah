// SILARAH - Continue with Google
//
// The same consent rule as the email code path: a new account exists only
// after the member accepted the terms in the app, and that acceptance is
// bound to the exact address before Supabase creates the user. The
// before-user-created hook (migrations 315-317) enforces it on the server for
// Google too: signInWithIdToken for an unknown address with no bound
// acceptance is refused, so tapping Google on the Sign in screen can never
// create an account. Existing members (email-code or Google) just sign in;
// Supabase links a Google identity to the account with the same verified
// address, so the two ways in always reach one account.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/expected_error.dart';
import 'email_address_validation.dart';
import 'google_identity_service.dart';
import 'legal_consent_service.dart';
import 'supabase_service.dart';

enum GoogleSignInOutcomeKind { signedIn, canceled, consentRequired, failed }

class GoogleSignInOutcome {
  const GoogleSignInOutcome._(
    this.kind, {
    this.userId,
    this.email,
    this.message,
    this.provisionedWithConsent = false,
  });

  const GoogleSignInOutcome.signedIn({
    required String userId,
    required String email,
    required bool provisionedWithConsent,
  }) : this._(
          GoogleSignInOutcomeKind.signedIn,
          userId: userId,
          email: email,
          provisionedWithConsent: provisionedWithConsent,
        );

  const GoogleSignInOutcome.canceled()
      : this._(GoogleSignInOutcomeKind.canceled);

  const GoogleSignInOutcome.consentRequired(String message)
      : this._(GoogleSignInOutcomeKind.consentRequired, message: message);

  const GoogleSignInOutcome.failed(String message)
      : this._(GoogleSignInOutcomeKind.failed, message: message);

  final GoogleSignInOutcomeKind kind;
  final String? userId;
  final String? email;
  final String? message;

  /// The bound acceptance was finalised for this account (a new account, or
  /// a member who chose Create profile and accepted again).
  final bool provisionedWithConsent;
}

/// Everything the flow needs from the outside world, so the consent rules
/// can be tested without Google or Supabase.
abstract class GoogleSignInBackend {
  Future<GoogleIdToken> obtainIdToken();
  Future<bool> hasPendingConsent();
  Future<bool> bindPendingConsent(String email);

  /// Signs in with the ID token and returns the Supabase user id.
  Future<String> signInWithIdToken(GoogleIdToken token);

  /// Commits the bound acceptance and the member row together.
  Future<bool> finalizeConsentAndProvision();

  /// Creates or refreshes the member row of an existing account.
  Future<void> syncExistingMember();

  Future<void> endSession();
}

class GoogleSignInFlow {
  GoogleSignInFlow(this._backend);

  final GoogleSignInBackend _backend;

  static const consentExpiredMessage =
      'Your legal acceptance has expired. Please review and accept it again.';
  static const newMemberMessage =
      'New to Silarah? Please accept the terms to create your profile, then continue with Google.';
  static const unavailableMessage =
      'Google sign-in is not available right now. Check your connection, or use your email instead.';
  static const networkMessage =
      'No internet connection. Please check your network and try again.';
  static const genericMessage =
      'We could not sign you in with Google. Please try again, or use your email instead.';
  static const saveFailedMessage = 'Could not save. Please try again.';

  /// [signup] is true on the Create profile screen, which the member reaches
  /// only through the legal gate.
  Future<GoogleSignInOutcome> run({required bool signup}) async {
    final GoogleIdToken token;
    try {
      token = await _backend.obtainIdToken();
    } on GoogleIdTokenException catch (e) {
      switch (e.failure) {
        case GoogleIdTokenFailure.canceled:
          return const GoogleSignInOutcome.canceled();
        case GoogleIdTokenFailure.unavailable:
          return const GoogleSignInOutcome.failed(unavailableMessage);
        case GoogleIdTokenFailure.misconfigured:
          debugPrint('GoogleSignInFlow: configuration problem: ${e.detail}');
          return const GoogleSignInOutcome.failed(genericMessage);
      }
    } catch (e) {
      debugPrint('GoogleSignInFlow: Google account step failed: $e');
      return const GoogleSignInOutcome.failed(unavailableMessage);
    }

    final email = EmailAddressValidation.normalize(token.email);
    if (email.isEmpty || !email.contains('@')) {
      return const GoogleSignInOutcome.failed(genericMessage);
    }

    // An acceptance given on this device is bound to the Google address
    // before Supabase sees it, exactly like the email path binds before it
    // asks for a code. It binds only to its first address.
    var consentBound = false;
    if (await _backend.hasPendingConsent()) {
      consentBound = await _backend.bindPendingConsent(email);
    }
    if (signup && !consentBound) {
      return const GoogleSignInOutcome.consentRequired(consentExpiredMessage);
    }

    final String userId;
    try {
      userId = await _backend.signInWithIdToken(token);
    } on AuthException catch (e) {
      if (isSignupConsentRefusal(e)) {
        return const GoogleSignInOutcome.consentRequired(newMemberMessage);
      }
      final hookMessage = userSafeHookMessage(e);
      if (hookMessage != null) return GoogleSignInOutcome.failed(hookMessage);
      if (expectedErrorCode(e) == 'network_unreachable') {
        return const GoogleSignInOutcome.failed(networkMessage);
      }
      debugPrint('GoogleSignInFlow: Supabase refused the Google token: '
          '${e.statusCode} ${e.code}');
      return const GoogleSignInOutcome.failed(genericMessage);
    } catch (e) {
      if (expectedErrorCode(e) == 'network_unreachable') {
        return const GoogleSignInOutcome.failed(networkMessage);
      }
      debugPrint('GoogleSignInFlow: Google token exchange failed: $e');
      return const GoogleSignInOutcome.failed(genericMessage);
    }

    if (consentBound) {
      final saved = await _backend.finalizeConsentAndProvision();
      if (!saved) {
        await _backend.endSession();
        return const GoogleSignInOutcome.failed(saveFailedMessage);
      }
      return GoogleSignInOutcome.signedIn(
        userId: userId,
        email: email,
        provisionedWithConsent: true,
      );
    }

    try {
      await _backend.syncExistingMember();
    } catch (e) {
      await _backend.endSession();
      // Only reachable if the server hook is off: the account was created
      // without an acceptance. It stays unusable until the member accepts;
      // the next Google sign-in then finalises it.
      if (e.toString().contains('required_signup_consents_missing')) {
        return const GoogleSignInOutcome.consentRequired(newMemberMessage);
      }
      if (expectedErrorCode(e) == 'network_unreachable') {
        return const GoogleSignInOutcome.failed(networkMessage);
      }
      debugPrint('GoogleSignInFlow: member sync failed: $e');
      return const GoogleSignInOutcome.failed(genericMessage);
    }
    return GoogleSignInOutcome.signedIn(
      userId: userId,
      email: email,
      provisionedWithConsent: false,
    );
  }

  /// The before-user-created hook refuses an address with no bound
  /// acceptance (migration 317).
  @visibleForTesting
  static bool isSignupConsentRefusal(AuthException e) =>
      e.message.toLowerCase().contains('accept the terms');

  /// The hook's other refusals are written for members; show them as-is.
  @visibleForTesting
  static String? userSafeHookMessage(AuthException e) {
    final message = e.message;
    if (message.contains('Temporary or disposable email addresses') ||
        message.contains('cannot be used to create a Silarah account')) {
      return message;
    }
    return null;
  }
}

class SupabaseGoogleSignInBackend implements GoogleSignInBackend {
  SupabaseGoogleSignInBackend({
    GoogleIdTokenSource? tokens,
    LegalConsentService? consent,
    required Future<void> Function() syncMember,
  })  : _tokens = tokens ?? GoogleIdentityService.instance,
        _consent = consent ?? LegalConsentService.instance,
        _syncMember = syncMember;

  final GoogleIdTokenSource _tokens;
  final LegalConsentService _consent;
  final Future<void> Function() _syncMember;

  @override
  Future<GoogleIdToken> obtainIdToken() => _tokens.obtain();

  @override
  Future<bool> hasPendingConsent() => _consent.hasPendingOnboardingConsents();

  @override
  Future<bool> bindPendingConsent(String email) =>
      _consent.bindPendingTransactionToEmail(email);

  @override
  Future<String> signInWithIdToken(GoogleIdToken token) async {
    final auth = SupabaseService.client.auth;
    final response = await auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      nonce: token.rawNonce,
    );
    final user = response.user ?? auth.currentUser;
    if (user == null || auth.currentSession == null) {
      throw const AuthException('Authentication failed. No user ID.');
    }
    return user.id;
  }

  @override
  Future<bool> finalizeConsentAndProvision() =>
      _consent.finalizeSignupAndProvision();

  @override
  Future<void> syncExistingMember() => _syncMember();

  @override
  Future<void> endSession() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      debugPrint('GoogleSignInFlow: ending the session failed: $e');
    }
    await _tokens.forget();
  }
}

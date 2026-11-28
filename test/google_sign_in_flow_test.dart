import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/services/google_identity_service.dart';
import 'package:silarah/core/services/google_sign_in_flow.dart';
import 'package:silarah/core/widgets/buttons/continue_with_google_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

const _token = GoogleIdToken(
  idToken: 'header.payload.signature',
  email: '  Member@Gmail.com ',
  rawNonce: 'raw-nonce',
);

/// Hook refusal text from migration 317.
const _hookConsentRefusal = AuthException(
  'Please create your account in the Silarah app and accept the terms before requesting a code.',
  statusCode: '403',
);

class _FakeBackend implements GoogleSignInBackend {
  _FakeBackend({
    this.tokenError,
    this.pendingConsent = false,
    this.bindSucceeds = true,
    this.signInError,
    this.finalizeSucceeds = true,
    this.syncError,
  });

  final Object? tokenError;
  final bool pendingConsent;
  final bool bindSucceeds;
  final Object? signInError;
  final bool finalizeSucceeds;
  final Object? syncError;

  final calls = <String>[];
  String? boundEmail;
  GoogleIdToken? exchanged;

  @override
  Future<GoogleIdToken> obtainIdToken() async {
    calls.add('google');
    if (tokenError != null) throw tokenError!;
    return _token;
  }

  @override
  Future<bool> hasPendingConsent() async {
    calls.add('hasConsent');
    return pendingConsent;
  }

  @override
  Future<bool> bindPendingConsent(String email) async {
    calls.add('bind');
    boundEmail = email;
    return bindSucceeds;
  }

  @override
  Future<String> signInWithIdToken(GoogleIdToken token) async {
    calls.add('signIn');
    exchanged = token;
    if (signInError != null) throw signInError!;
    return 'user-1';
  }

  @override
  Future<bool> finalizeConsentAndProvision() async {
    calls.add('finalize');
    return finalizeSucceeds;
  }

  @override
  Future<void> syncExistingMember() async {
    calls.add('sync');
    if (syncError != null) throw syncError!;
  }

  @override
  Future<void> endSession() async => calls.add('endSession');
}

void main() {
  group('Continue with Google: consent gate', () {
    test('a member who closes the chooser is left exactly where they were',
        () async {
      final backend = _FakeBackend(
        tokenError:
            const GoogleIdTokenException(GoogleIdTokenFailure.canceled),
      );
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.canceled);
      expect(backend.calls, ['google']);
    });

    test('an existing member signs in without being asked to accept again',
        () async {
      final backend = _FakeBackend();
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.signedIn);
      expect(outcome.userId, 'user-1');
      expect(outcome.email, 'member@gmail.com');
      expect(outcome.provisionedWithConsent, isFalse);
      expect(backend.calls, ['google', 'hasConsent', 'signIn', 'sync']);
      expect(backend.exchanged!.rawNonce, 'raw-nonce');
    });

    test('Sign in with an unknown Google address never creates an account',
        () async {
      // The server hook refuses: no acceptance is bound to the address.
      final backend = _FakeBackend(signInError: _hookConsentRefusal);
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.consentRequired);
      expect(outcome.message, GoogleSignInFlow.newMemberMessage);
      expect(backend.calls, isNot(contains('finalize')));
      expect(backend.calls, isNot(contains('sync')));
    });

    test('Create profile binds the acceptance to the Google address first',
        () async {
      final backend = _FakeBackend(pendingConsent: true);
      final outcome = await GoogleSignInFlow(backend).run(signup: true);

      expect(outcome.kind, GoogleSignInOutcomeKind.signedIn);
      expect(outcome.provisionedWithConsent, isTrue);
      expect(backend.boundEmail, 'member@gmail.com');
      // Bound before Supabase can create the account, finalised after.
      expect(
        backend.calls,
        ['google', 'hasConsent', 'bind', 'signIn', 'finalize'],
      );
    });

    test('Create profile without a valid acceptance goes back to the terms',
        () async {
      final backend = _FakeBackend();
      final outcome = await GoogleSignInFlow(backend).run(signup: true);

      expect(outcome.kind, GoogleSignInOutcomeKind.consentRequired);
      expect(outcome.message, GoogleSignInFlow.consentExpiredMessage);
      expect(backend.calls, isNot(contains('signIn')));
    });

    test('an acceptance bound to another address is not reused', () async {
      final backend = _FakeBackend(pendingConsent: true, bindSucceeds: false);
      final outcome = await GoogleSignInFlow(backend).run(signup: true);

      expect(outcome.kind, GoogleSignInOutcomeKind.consentRequired);
      expect(backend.calls, isNot(contains('signIn')));
    });

    test('an acceptance given before tapping Sign in still counts', () async {
      final backend = _FakeBackend(pendingConsent: true);
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.signedIn);
      expect(outcome.provisionedWithConsent, isTrue);
      expect(backend.calls, containsAllInOrder(['bind', 'signIn', 'finalize']));
    });

    test('a failed consent save ends the session instead of half an account',
        () async {
      final backend = _FakeBackend(pendingConsent: true, finalizeSucceeds: false);
      final outcome = await GoogleSignInFlow(backend).run(signup: true);

      expect(outcome.kind, GoogleSignInOutcomeKind.failed);
      expect(outcome.message, GoogleSignInFlow.saveFailedMessage);
      expect(backend.calls.last, 'endSession');
    });

    test('an account created without acceptance is closed and sent to terms',
        () async {
      // Only possible while the server hook is switched off.
      final backend = _FakeBackend(
        syncError: const PostgrestException(
          message: 'required_signup_consents_missing',
          code: 'P0001',
        ),
      );
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.consentRequired);
      expect(backend.calls.last, 'endSession');
    });
  });

  group('Continue with Google: failures', () {
    test('no network at the Supabase step says so', () async {
      final backend = _FakeBackend(
        signInError: AuthRetryableFetchException(message: 'offline'),
      );
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.failed);
      expect(outcome.message, GoogleSignInFlow.networkMessage);
    });

    test('a socket failure at the Supabase step says so', () async {
      final backend = _FakeBackend(
        signInError: const SocketException('Failed host lookup'),
      );
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.message, GoogleSignInFlow.networkMessage);
    });

    test('Google unavailable (offline, no account) offers the email way',
        () async {
      final backend = _FakeBackend(
        tokenError:
            const GoogleIdTokenException(GoogleIdTokenFailure.unavailable),
      );
      final outcome = await GoogleSignInFlow(backend).run(signup: false);

      expect(outcome.kind, GoogleSignInOutcomeKind.failed);
      expect(outcome.message, GoogleSignInFlow.unavailableMessage);
      expect(backend.calls, ['google']);
    });

    test('a blocked address shows the hook\'s own member-safe message',
        () async {
      const blocked = AuthException(
        'This email address cannot be used to create a Silarah account. Contact support@silarah.com if you think this is a mistake.',
        statusCode: '403',
      );
      final outcome = await GoogleSignInFlow(
        _FakeBackend(signInError: blocked),
      ).run(signup: false);

      expect(outcome.message, blocked.message);
    });

    test('any other refusal stays generic', () async {
      final outcome = await GoogleSignInFlow(
        _FakeBackend(
          signInError: const AuthException('Bad ID token', statusCode: '400'),
        ),
      ).run(signup: false);

      expect(outcome.message, GoogleSignInFlow.genericMessage);
    });
  });

  group('Google ID token', () {
    test('the nonce Google sees is the SHA-256 of the one Supabase gets', () {
      expect(
        GoogleIdentityService.hashNonce('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('every attempt gets a new 256-bit nonce', () {
      final nonces = {
        for (var i = 0; i < 50; i++) GoogleIdentityService.generateRawNonce(),
      };
      expect(nonces, hasLength(50));
      expect(nonces.every((n) => n.length == 43), isTrue);
    });

    test('Google errors map to what the member can do about them', () {
      expect(
        GoogleIdentityService.failureFor(GoogleSignInExceptionCode.canceled),
        GoogleIdTokenFailure.canceled,
      );
      expect(
        GoogleIdentityService.failureFor(
          GoogleSignInExceptionCode.clientConfigurationError,
        ),
        GoogleIdTokenFailure.misconfigured,
      );
      expect(
        GoogleIdentityService.failureFor(
          GoogleSignInExceptionCode.uiUnavailable,
        ),
        GoogleIdTokenFailure.unavailable,
      );
    });

    test('the button is hidden in builds without a web client ID', () {
      // Tests build without GOOGLE_WEB_CLIENT_ID, like any unconfigured build.
      expect(GoogleIdentityService.isAvailable, isFalse);
    });
  });

  group('AuthCubit.continueWithGoogle', () {
    Future<List<AuthState>> run(_FakeBackend backend, String mode) async {
      final cubit = AuthCubit(googleBackend: backend);
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.continueWithGoogle(mode: mode);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await cubit.close();
      return states;
    }

    test('cancel returns to signed out with no message', () async {
      final states = await run(
        _FakeBackend(
          tokenError:
              const GoogleIdTokenException(GoogleIdTokenFailure.canceled),
        ),
        'signin',
      );
      expect(states, [const AuthLoading(), const AuthUnauthenticated()]);
    });

    test('a new address is sent to the legal gate', () async {
      final states = await run(
        _FakeBackend(signInError: _hookConsentRefusal),
        'signin',
      );
      expect(states.last, const AuthError(
        message: GoogleSignInFlow.newMemberMessage,
        kind: AuthErrorKind.legalConsentRequired,
      ));
    });

    test('failures carry the Google kind so the screen shows them as-is',
        () async {
      final states = await run(
        _FakeBackend(
          tokenError:
              const GoogleIdTokenException(GoogleIdTokenFailure.unavailable),
        ),
        'signup',
      );
      expect(states.last, const AuthError(
        message: GoogleSignInFlow.unavailableMessage,
        kind: AuthErrorKind.googleSignIn,
      ));
    });
  });

  group('server and client contract', () {
    test('the newest sign-up hook still needs an acceptance bound to the address',
        () {
      // signInWithIdToken creates users through the public token endpoint,
      // which runs the before-user-created hook like /otp does.
      final migrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final latest = migrations.lastWhere((f) => f
          .readAsStringSync()
          .contains('FUNCTION public.hook_before_user_created'));
      final sql = latest.readAsStringSync();
      expect(sql, contains('private.signup_consent_transactions'));
      expect(sql, contains('c.bound_email_hash = v_hash'));
      expect(sql, contains('c.consumed_at IS NULL'));
      expect(sql, contains("event->'user'->>'email'"));
    });

    test('the app never uses the Auth admin API', () {
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        expect(source, isNot(contains('auth.admin')), reason: file.path);
        expect(source, isNot(contains('service_role')), reason: file.path);
      }
    });

    test('Google sign-in sends the raw nonce and the ID token to Supabase', () {
      final source =
          File('lib/core/services/google_sign_in_flow.dart').readAsStringSync();
      expect(source, contains('provider: OAuthProvider.google'));
      expect(source, contains('nonce: token.rawNonce'));
    });
  });

  group('Continue with Google button', () {
    test('the G is drawn inside its 48 x 48 artboard', () {
      for (final data in [
        'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
            '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
        'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
            'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
      ]) {
        final bounds = parseSvgPath(data).getBounds();
        expect(bounds.left, greaterThanOrEqualTo(-0.01));
        expect(bounds.top, greaterThanOrEqualTo(-0.01));
        expect(bounds.right, lessThanOrEqualTo(48.01));
        expect(bounds.bottom, lessThanOrEqualTo(48.01));
        expect(bounds.width, greaterThan(5));
      }
    });

    testWidgets('shows Google\'s label and reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContinueWithGoogleButton(onTap: () => taps++),
        ),
      ));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = File('lib/core/cubits/auth/auth_cubit.dart').readAsStringSync();

  String between(String source, String start, String end) => source.substring(
        source.indexOf(start),
        source.indexOf(end, source.indexOf(start)),
      );

  test('a deletion request ends every device and still ends this one', () {
    final endSession = between(
      auth,
      'Future<void> _endSession(',
      '/// Closes this device',
    );
    expect(endSession, contains('scope: SignOutScope.global'));
    expect(
      endSession.indexOf('catch (e)'),
      lessThan(endSession.lastIndexOf('await auth.signOut();')),
    );
    expect(auth, contains('everyDevice: endEveryDevice'));
    expect(auth, contains("== 'pending_deletion';"));
  });

  test('a revoked device cannot restore a deletion request', () {
    final recover = between(
      auth,
      'Future<void> _recoverPendingDeletion(String userId) async',
      'Future<bool> _isDeletionAlreadyCancelled',
    );
    expect(
      recover.indexOf('refreshSession()'),
      lessThan(recover.indexOf("'cancel_my_account_deletion'")),
    );
    expect(recover, contains('isInvalidRefreshToken(error)'));
  });

  test('a refused restore tells the member and signs out', () {
    final recover = between(
      auth,
      'Future<void> _recoverPendingDeletion(String userId) async',
      'Future<bool> _isDeletionAlreadyCancelled',
    );
    expect(recover, contains('!restored'));
    expect(recover, contains('_isDeletionAlreadyCancelled(userId)'));
    expect(recover, contains('notice: accountNoLongerRestorableNotice'));
    expect(
      between(auth, 'Future<void> _closeSession(', 'void updateOnboardingStep'),
      contains('emit(AuthUnauthenticated(notice: notice));'),
    );
    expect(
      between(
        auth,
        'Future<AuthSessionCheckResult> checkSession()',
        'Future<void> _handleAuthEvent',
      ),
      contains('on AccountSessionEndedException'),
    );
  });

  test('the auth listener waits for sign-up provisioning', () {
    final listener = between(
      auth,
      'Future<void> _handleAuthEvent(',
      'Future<void> _emitAuthenticatedFromSession(',
    );
    expect(
      listener.indexOf('await provisioning.future'),
      lessThan(listener.indexOf('SupabaseService.recoverSession()')),
    );
    final verify = between(
      auth,
      'Future<void> verifyOtp(',
      'Future<void> signOut()',
    );
    expect(
      verify.indexOf('_signupProvisioning = provisioning'),
      lessThan(verify.indexOf('auth.verifyOTP(')),
    );
    expect(
      verify.indexOf('finalizeSignupAndProvision()'),
      lessThan(verify.indexOf('provisioned = true;')),
    );
    expect(verify, contains('provisioning?.complete(provisioned);'));
  });

  test('Resume unlocks when the follow-up refresh fails', () {
    final standing = File(
      'lib/core/cubits/account_standing/account_standing_cubit.dart',
    ).readAsStringSync();
    final resume = between(
      standing,
      'Future<bool> resumeProfile()',
      'on PostgrestException',
    );
    expect(
      resume.indexOf('await refresh();'),
      lessThan(resume.indexOf('emit(state.copyWith(updating: false));')),
    );
  });

  test('an accepted Guardian invitation is never reported as refused', () {
    final guardian = File(
      'lib/features/home/screens/guardian_connect_screen.dart',
    ).readAsStringSync();
    final accept = between(
      guardian,
      'Future<void> _acceptInvitation()',
      'Future<void> _finishAcceptedInvitation()',
    );
    expect(accept, isNot(contains('refreshAuthenticatedProfile')));
    final finish = between(
      guardian,
      'Future<void> _finishAcceptedInvitation()',
      'Future<void> _continueWithoutGuardian()',
    );
    expect(finish, contains('refreshAuthenticatedProfile'));
    expect(finish, isNot(contains('could not be accepted')));
  });
}

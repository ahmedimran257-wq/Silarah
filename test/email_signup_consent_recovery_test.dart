import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/router/app_router.dart';
import 'package:silarah/features/onboarding/screens/email_verification_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

const _legalExpired =
    'Your legal acceptance has expired. Please review and accept it again.';
const _transactionIdKey = 'pending_signup_consent_transaction_id_v3';
const _transactionExpiresAtKey =
    'pending_signup_consent_transaction_expires_at_v3';

class _ScriptedAuthCubit extends AuthCubit {
  _ScriptedAuthCubit(this.onSend);

  final AuthState onSend;

  @override
  Future<void> sendOtp(
    String email, {
    String mode = 'signin',
    String? countryCode,
    bool isResend = false,
  }) async {
    emit(onSend);
  }
}

Map<String, Object> _validTransaction() => {
      _transactionIdKey: 'transaction-1',
      _transactionExpiresAtKey: DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
    };

Future<GoRouter> _pumpEmailScreen(
  WidgetTester tester,
  AuthCubit authCubit, {
  required EmailAuthMode mode,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(840, 1800);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppRoutes.email,
    routes: [
      GoRoute(
        path: AppRoutes.email,
        builder: (_, __) => EmailVerificationScreen(mode: mode),
      ),
      GoRoute(
        path: AppRoutes.legal,
        builder: (_, __) => const Scaffold(body: Text('legal gate')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

// The OTP cursor blinks forever, so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _send(WidgetTester tester, String label) async {
  await tester.enterText(find.byType(TextField).first, 'member@example.com');
  await tester.ensureVisible(find.text(label));
  await _settle(tester);
  await tester.tap(find.text(label));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('expired consent explains itself and returns to the legal gate',
      (tester) async {
    final cubit = _ScriptedAuthCubit(const AuthError(
      message: _legalExpired,
      kind: AuthErrorKind.legalConsentRequired,
    ));
    addTearDown(cubit.close);
    await _pumpEmailScreen(tester, cubit, mode: EmailAuthMode.signUp);

    await _send(tester, 'Send verification code');

    expect(find.text(_legalExpired), findsOneWidget);
    expect(find.text('legal gate'), findsOneWidget);
  });

  testWidgets('a rejected address shows the real validation message',
      (tester) async {
    const message = 'Temporary email addresses cannot be used.';
    final cubit = _ScriptedAuthCubit(const AuthError(
      message: message,
      kind: AuthErrorKind.invalidEmail,
    ));
    addTearDown(cubit.close);
    await _pumpEmailScreen(tester, cubit, mode: EmailAuthMode.signUp);

    await _send(tester, 'Send verification code');

    expect(find.text(message), findsOneWidget);
    expect(find.text('legal gate'), findsNothing);
  });

  testWidgets('Create profile from Sign in goes through the legal gate',
      (tester) async {
    final cubit = _ScriptedAuthCubit(const AuthOtpSent(email: 'a@b.co'));
    addTearDown(cubit.close);
    await _pumpEmailScreen(tester, cubit, mode: EmailAuthMode.signIn);

    await tester.ensureVisible(find.text('New to Silarah? Create profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to Silarah? Create profile'));
    await tester.pumpAndSettle();

    expect(find.text('legal gate'), findsOneWidget);
  });

  testWidgets('an unexpired acceptance keeps the in-place mode switch',
      (tester) async {
    SharedPreferences.setMockInitialValues(_validTransaction());
    final cubit = _ScriptedAuthCubit(const AuthOtpSent(email: 'a@b.co'));
    addTearDown(cubit.close);
    await _pumpEmailScreen(tester, cubit, mode: EmailAuthMode.signIn);

    await tester.ensureVisible(find.text('New to Silarah? Create profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to Silarah? Create profile'));
    await tester.pumpAndSettle();

    expect(find.text('legal gate'), findsNothing);
    expect(find.text('Create your Silarah profile'), findsOneWidget);
  });

  testWidgets('Change email during sign-up asks for a fresh acceptance',
      (tester) async {
    SharedPreferences.setMockInitialValues(_validTransaction());
    final cubit = _ScriptedAuthCubit(const AuthOtpSent(email: 'a@b.co'));
    addTearDown(cubit.close);
    await _pumpEmailScreen(tester, cubit, mode: EmailAuthMode.signUp);

    await _send(tester, 'Send verification code');
    await tester.ensureVisible(find.text('Change email'));
    await _settle(tester);
    await tester.tap(find.text('Change email'));
    await _settle(tester);

    expect(
      find.text('To use a different email, please accept the terms again.'),
      findsOneWidget,
    );
    expect(find.text('legal gate'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_transactionIdKey), isNull);
  });

  testWidgets('Change email during sign-in stays on the same screen',
      (tester) async {
    final cubit = _ScriptedAuthCubit(const AuthOtpSent(email: 'a@b.co'));
    addTearDown(cubit.close);
    await _pumpEmailScreen(tester, cubit, mode: EmailAuthMode.signIn);

    await _send(tester, 'Send sign-in code');
    await tester.ensureVisible(find.text('Change email'));
    await _settle(tester);
    await tester.tap(find.text('Change email'));
    await _settle(tester);

    expect(find.text('legal gate'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}

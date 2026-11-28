import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/router/app_router.dart';
import 'package:silarah/core/services/google_sign_in_flow.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/widgets/buttons/continue_with_google_button.dart';
import 'package:silarah/features/onboarding/screens/legal_gate_screen.dart';
import 'package:silarah/features/onboarding/screens/splash_brand_screen.dart';
import 'package:silarah/features/onboarding/screens/email_verification_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

class _GoogleScriptedCubit extends AuthCubit {
  _GoogleScriptedCubit(this.result);

  final AuthState result;
  final modes = <String>[];

  @override
  Future<void> continueWithGoogle({String mode = 'signin'}) async {
    modes.add(mode);
    emit(const AuthLoading());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    emit(result);
  }
}

Future<void> _pump(
  WidgetTester tester,
  AuthCubit cubit, {
  required EmailAuthMode mode,
  bool showGoogle = true,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(840, 1800);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppRoutes.email,
    routes: [
      GoRoute(
        path: AppRoutes.email,
        builder: (_, __) =>
            EmailVerificationScreen(mode: mode, showGoogleSignIn: showGoogle),
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
      value: cubit,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapGoogle(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue with Google'));
  await _settle(tester);
  await tester.tap(find.text('Continue with Google'));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final mode in EmailAuthMode.values) {
    testWidgets('Continue with Google sits beside the email code ($mode)',
        (tester) async {
      final cubit = _GoogleScriptedCubit(const AuthUnauthenticated());
      addTearDown(cubit.close);
      await _pump(tester, cubit, mode: mode);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      // The email-code button is still there and unchanged.
      expect(
        find.text(mode == EmailAuthMode.signIn
            ? 'Send sign-in code'
            : 'Send verification code'),
        findsOneWidget,
      );

      await _tapGoogle(tester);
      expect(cubit.modes, [mode == EmailAuthMode.signUp ? 'signup' : 'signin']);
    });
  }

  testWidgets('builds without Google configured show only the email code',
      (tester) async {
    final cubit = _GoogleScriptedCubit(const AuthUnauthenticated());
    addTearDown(cubit.close);
    await _pump(tester, cubit, mode: EmailAuthMode.signIn, showGoogle: false);

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Send sign-in code'), findsOneWidget);
  });

  testWidgets('a new Google address is sent to accept the terms first',
      (tester) async {
    final cubit = _GoogleScriptedCubit(const AuthError(
      message: GoogleSignInFlow.newMemberMessage,
      kind: AuthErrorKind.legalConsentRequired,
    ));
    addTearDown(cubit.close);
    await _pump(tester, cubit, mode: EmailAuthMode.signIn);

    await _tapGoogle(tester);

    expect(find.text(GoogleSignInFlow.newMemberMessage), findsOneWidget);
    expect(find.text('legal gate'), findsOneWidget);
  });

  testWidgets('a Google failure shows its own message, not the code one',
      (tester) async {
    final cubit = _GoogleScriptedCubit(const AuthError(
      message: GoogleSignInFlow.unavailableMessage,
      kind: AuthErrorKind.googleSignIn,
    ));
    addTearDown(cubit.close);
    await _pump(tester, cubit, mode: EmailAuthMode.signIn);

    await _tapGoogle(tester);

    expect(find.text(GoogleSignInFlow.unavailableMessage), findsOneWidget);
    expect(find.textContaining('sign-in code. Check'), findsNothing);
    expect(find.text('legal gate'), findsNothing);
  });

  testWidgets('cancelling Google leaves the screen ready to try again',
      (tester) async {
    final cubit = _GoogleScriptedCubit(const AuthUnauthenticated());
    addTearDown(cubit.close);
    await _pump(tester, cubit, mode: EmailAuthMode.signIn);

    await _tapGoogle(tester);
    expect(find.byType(SnackBar), findsNothing);
    await _tapGoogle(tester);
    expect(cubit.modes, hasLength(2));
  });

  for (final mode in SilarahThemeMode.values) {
    testWidgets('the Google button follows the ${mode.label} theme',
        (tester) async {
      AppColors.activate(mode);
      addTearDown(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.obsidianNight,
          body: Center(child: ContinueWithGoogleButton(onTap: () {})),
        ),
      ));
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(ContinueWithGoogleButton),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.color, AppColors.cardBorder);
      final label = tester.widget<Text>(find.text('Continue with Google'));
      expect(label.style!.color, AppColors.pearlWhite);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the welcome screen offers Google and sends new members to the '
      'terms, which then resume Google', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    final cubit = _GoogleScriptedCubit(const AuthError(
      message: GoogleSignInFlow.newMemberMessage,
      kind: AuthErrorKind.legalConsentRequired,
    ));
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const SplashBrandScreen(showGoogleSignIn: true),
        ),
        GoRoute(
          path: AppRoutes.legal,
          builder: (_, state) => Scaffold(
            body: Text('legal gate then=${state.uri.queryParameters['then']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ));
    await _settle(tester);
    expect(find.text('Create Profile'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    await _tapGoogle(tester);

    expect(cubit.modes, ['signin']);
    expect(find.text('legal gate then=google'), findsOneWidget);
  });

  testWidgets('after accepting, the terms screen continues with Google',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(840, 1800);
    addTearDown(tester.view.reset);
    final source = File(
      'lib/features/onboarding/screens/legal_gate_screen.dart',
    ).readAsStringSync();
    // Accepting records the consent transaction, then Google resumes in
    // sign-up mode so the acceptance is bound to the Google address.
    expect(source, contains("continueWithGoogle(mode: 'signup')"));
    expect(
      source.indexOf('recordPendingOnboardingConsents()'),
      lessThan(source.indexOf("continueWithGoogle(mode: 'signup')")),
    );
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(router, contains("queryParameters['then'] == 'google'"));

    final cubit = _GoogleScriptedCubit(const AuthUnauthenticated());
    addTearDown(cubit.close);
    await tester.pumpWidget(BlocProvider<AuthCubit>.value(
      value: cubit,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LegalGateScreen(continueWithGoogle: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LegalGateScreen), findsOneWidget);
  });
}

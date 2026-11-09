import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/cubits/onboarding/onboarding_cubit.dart';
import 'package:silarah/core/cubits/onboarding/onboarding_state.dart';
import 'package:silarah/core/models/onboarding_data.dart';
import 'package:silarah/features/home/screens/guardian_connect_screen.dart';
import 'package:silarah/features/onboarding/screens/basic_identity_screen.dart';
import 'package:silarah/features/onboarding/widgets/onboarding_scaffold.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

class _SeededAuthCubit extends AuthCubit {
  void seed(AuthState state) => emit(state);
}

class _FailingRefreshAuthCubit extends _SeededAuthCubit {
  @override
  Future<void> refreshAuthenticatedProfile() async {
    throw StateError('network down');
  }
}

class _SeededOnboardingCubit extends OnboardingCubit {
  _SeededOnboardingCubit({required super.authCubit});

  void seed(OnboardingData data) => emit(
        OnboardingActive(step: 2, data: data),
      );
}

const _member = AuthAuthenticated(
  userId: 'user-1',
  onboardingStep: 2,
  email: 'user@example.com',
);

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('system Back during onboarding', () {
    Future<void> pumpScaffold(
      WidgetTester tester, {
      required int step,
      VoidCallback? onBack,
    }) async {
      final authCubit = _SeededAuthCubit()..seed(_member);
      final onboardingCubit = _SeededOnboardingCubit(authCubit: authCubit);
      addTearDown(authCubit.close);
      addTearDown(onboardingCubit.close);
      await tester.pumpWidget(
        _app(
          BlocProvider<OnboardingCubit>.value(
            value: onboardingCubit,
            child: OnboardingScaffold(
              step: step,
              totalSteps: 5,
              body: const Text('step body'),
              ctaLabel: 'Continue',
              onCta: () {},
              onBack: onBack,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('runs the same action as the on-screen Back button',
        (tester) async {
      var backs = 0;
      await pumpScaffold(tester, step: 2, onBack: () => backs++);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(backs, 1);
      expect(handled, isTrue);
    });

    testWidgets('may leave the app only from the first step', (tester) async {
      PopScope<Object?> scope() => tester.widget<PopScope<Object?>>(find
          .byWidgetPredicate(
            (widget) => widget is PopScope<Object?>,
            description: 'PopScope',
          )
          .last);

      await pumpScaffold(tester, step: 0);
      expect(scope().canPop, isTrue);

      await pumpScaffold(tester, step: 2);
      expect(scope().canPop, isFalse);
    });
  });

  group('Basic Identity loads data that arrives after the first build', () {
    Future<_SeededOnboardingCubit> pumpScreen(WidgetTester tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(720, 1600);
      addTearDown(tester.view.reset);
      final authCubit = _SeededAuthCubit()..seed(_member);
      final onboardingCubit = _SeededOnboardingCubit(authCubit: authCubit);
      addTearDown(authCubit.close);
      addTearDown(onboardingCubit.close);
      await tester.pumpWidget(
        _app(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<OnboardingCubit>.value(value: onboardingCubit),
            ],
            child: const BasicIdentityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return onboardingCubit;
    }

    TextField nameField(WidgetTester tester, int index) =>
        tester.widget<TextField>(find.byType(TextField).at(index));

    testWidgets('fills the fields once the profile loads', (tester) async {
      final cubit = await pumpScreen(tester);
      expect(nameField(tester, 0).controller!.text, isEmpty);

      cubit.seed(const OnboardingData(firstName: 'Amina', lastName: 'Khan'));
      await tester.pumpAndSettle();

      expect(nameField(tester, 0).controller!.text, 'Amina');
      expect(nameField(tester, 1).controller!.text, 'Khan');
    });

    testWidgets('keeps anything the member already typed', (tester) async {
      final cubit = await pumpScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Typed');
      await tester.pump();

      cubit.seed(const OnboardingData(firstName: 'Amina', lastName: 'Khan'));
      await tester.pumpAndSettle();

      expect(nameField(tester, 0).controller!.text, 'Typed');
      expect(nameField(tester, 1).controller!.text, 'Khan');
    });

    testWidgets('a field the member cleared stays cleared', (tester) async {
      final cubit = await pumpScreen(tester);
      cubit.seed(const OnboardingData(firstName: 'Amina'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      cubit.seed(const OnboardingData(firstName: 'Amina', lastName: 'Khan'));
      await tester.pumpAndSettle();

      expect(nameField(tester, 0).controller!.text, isEmpty);
    });
  });

  testWidgets('Continue without Guardian recovers from a failed refresh',
      (tester) async {
    final authCubit = _FailingRefreshAuthCubit()..seed(_member);
    addTearDown(authCubit.close);
    await tester.pumpWidget(
      _app(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: const GuardianConnectScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue without Guardian'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We could not refresh your account. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Continue without Guardian'), findsOneWidget);
  });
}

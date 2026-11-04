import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/widgets/startup_offline_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Widget _app(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: child,
  );
}

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));

  testWidgets('calm copy, a tip and one clear retry', (tester) async {
    await tester.pumpWidget(
      _app(StartupOfflineScreen(onRetry: () async => false)),
    );
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.text('Waiting for a connection'), findsOneWidget);
    expect(find.text('WAITING FOR NETWORK'), findsOneWidget);
    expect(
      find.text('Check that Wi-Fi or mobile data is turned on.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Connection unavailable'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a successful check keeps the loading state until handoff',
      (tester) async {
    final result = Completer<bool>();
    await tester.pumpWidget(
      _app(StartupOfflineScreen(onRetry: () => result.future)),
    );
    await tester.pump(const Duration(milliseconds: 1300));

    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text('CHECKING CONNECTION'), findsOneWidget);

    // The root bootstrap swaps this screen out once online; until then the
    // button must not flash back to "Try again".
    result.complete(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text('STILL OFFLINE · RETRYING'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in SilarahThemeMode.values) {
    testWidgets('ripples run cleanly in ${mode.label}', (tester) async {
      AppColors.activate(mode);
      await tester.pumpWidget(
        _app(StartupOfflineScreen(onRetry: () async => false)),
      );
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion settles with no looping ripple',
      (tester) async {
    await tester.pumpWidget(
      _app(
        StartupOfflineScreen(onRetry: () async => false),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Try again'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('small screens and large text scroll instead of overflowing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      _app(StartupOfflineScreen(onRetry: () async => false)),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/discovery/discovery_filter.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/features/home/widgets/discovery_empty_state.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Widget _host(
  Widget child, {
  bool reduceMotion = false,
}) {
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
    home: Scaffold(body: child),
  );
}

class _Calls {
  int clear = 0;
  int refresh = 0;
  final List<String?> adjust = [];
}

DiscoveryEmptyState _state(DiscoveryFilter filter, _Calls calls) =>
    DiscoveryEmptyState(
      filter: filter,
      onClearFilters: () => calls.clear++,
      onRefresh: () => calls.refresh++,
      onAdjustFilters: calls.adjust.add,
    );

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));

  group('hint picks the filter most likely to be narrowing results', () {
    test('no filters means no hint', () {
      expect(DiscoveryEmptyHint.forFilter(DiscoveryFilter.empty), isNull);
    });

    test('trust outranks deen, deen outranks sect', () {
      expect(
        DiscoveryEmptyHint.forFilter(
          const DiscoveryFilter(trustFilter: 'photo', deenLevel: 'practicing'),
        ),
        DiscoveryEmptyHint.trust,
      );
      expect(
        DiscoveryEmptyHint.forFilter(
          const DiscoveryFilter(deenLevel: 'practicing', sect: 'Sunni'),
        ),
        DiscoveryEmptyHint.deen,
      );
    });

    test('each hint opens the matching filter-sheet section', () {
      expect(
        DiscoveryEmptyHint.forFilter(const DiscoveryFilter(sect: 'Sunni'))!
            .section,
        'sect',
      );
      expect(
        DiscoveryEmptyHint.forFilter(const DiscoveryFilter(maxDistanceKm: 25))!
            .section,
        'distance',
      );
      expect(
        DiscoveryEmptyHint.forFilter(const DiscoveryFilter(cityId: 'c1'))!
            .section,
        'location',
      );
      expect(
        DiscoveryEmptyHint.forFilter(const DiscoveryFilter(ageMin: 24))!
            .section,
        'age',
      );
      final other = DiscoveryEmptyHint.forFilter(
        const DiscoveryFilter(activeRecentlyOnly: true),
      );
      expect(other, DiscoveryEmptyHint.other);
      expect(other!.section, isNull);
    });
  });

  testWidgets('feed run out: refresh is primary, adjust opens the sheet',
      (tester) async {
    final calls = _Calls();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(_state(DiscoveryFilter.empty, calls)));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text("You've seen everyone for today"), findsOneWidget);
    expect(find.text('ALL CAUGHT UP'), findsOneWidget);
    expect(find.text('Clear all filters'), findsNothing);

    await tester.tap(find.text('Refresh profiles'));
    await tester.tap(find.text('Adjust filters'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls.refresh, 1);
    expect(calls.clear, 0);
    expect(calls.adjust, [null]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('filters match nobody: clear is primary, hint is specific',
      (tester) async {
    final calls = _Calls();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        _state(
          const DiscoveryFilter(sect: 'Sunni', deenLevel: 'practicing'),
          calls,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('No one matches these filters yet'), findsOneWidget);
    expect(find.text('Try widening Deen level first'), findsOneWidget);

    await tester.tap(find.text('Try widening Deen level first'));
    await tester.tap(find.text('Clear all filters'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls.adjust, ['deen']);
    expect(calls.clear, 1);
    expect(calls.refresh, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in SilarahThemeMode.values) {
    testWidgets('renders and animates cleanly in ${mode.label}',
        (tester) async {
      AppColors.activate(mode);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(_state(const DiscoveryFilter(trustFilter: 'photo'), _Calls())),
      );
      // Entrance plus several idle frames, including the light sweep.
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(CustomPaint), findsWidgets);

      // Disposing mid-loop must not leak tickers.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion shows the settled scene with no looping frames',
      (tester) async {
    await tester.pumpWidget(
      _host(_state(DiscoveryFilter.empty, _Calls()), reduceMotion: true),
    );
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text("You've seen everyone for today"), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('short screens scroll instead of overflowing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(_state(const DiscoveryFilter(sect: 'Sunni'), _Calls())),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

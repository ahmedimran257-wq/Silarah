// The Calls tab loads like the rest of Silarah (owner's request, 25 Nov
// 2026): Discover's premium breathing placeholder, never the generic light
// sweeping across the screen, and still when animations are off.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/widgets/loaders/silarah_shimmer.dart';
import 'package:silarah/features/calls/widgets/calls_tab_widgets.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 800), disableAnimations: reduceMotion),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Iterable<File> _dartFiles(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

void main() {
  test('no Calls surface uses the generic sweep or a stock spinner', () {
    for (final file in _dartFiles('lib/features/calls')) {
      final code = file.readAsStringSync();
      expect(code, isNot(contains('SilarahShimmer(')), reason: file.path);
      expect(code, isNot(contains('CircularProgressIndicator')), reason: file.path);
      expect(code, isNot(contains('LinearProgressIndicator')), reason: file.path);
    }
  });

  test('the Calls placeholders breathe like Discover', () {
    final widgets = File('lib/features/calls/widgets/calls_tab_widgets.dart').readAsStringSync();
    for (final name in ['class CallsListSkeleton', 'class CallMinutesCardPlaceholder', 'class CallAttemptsPlaceholder']) {
      final body = widgets.substring(widgets.indexOf(name));
      expect(body.substring(0, body.indexOf('\n}\n')), contains('SilarahBreathing('), reason: name);
    }
    final loader = File('lib/core/widgets/loaders/silarah_shimmer.dart').readAsStringSync();
    final discover = loader.substring(loader.indexOf('class SilarahProfileCardShimmer'));
    expect(discover.substring(0, discover.indexOf('\n}\n')), contains('SilarahBreathing('),
        reason: 'one motion for every placeholder');
  });

  testWidgets('the placeholders render at 360 dp, at the largest font, and say they are loading', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(_host(MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: const Column(
          children: [CallMinutesCardPlaceholder(), CallsListSkeleton(), CallAttemptsPlaceholder()],
        ),
      )));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: 'text scale $scale');
    }
    expect(find.bySemanticsLabel('Loading calls'), findsNWidgets(2));
    semantics.dispose();
  });

  testWidgets('with animations off the placeholders hold still', (tester) async {
    double pulseNow() => tester.widget<SilarahLoaderBar>(find.byType(SilarahLoaderBar).first).opacity;

    await tester.pumpWidget(_host(const CallsListSkeleton(), reduceMotion: true));
    final before = pulseNow();
    await tester.pump(const Duration(milliseconds: 800));
    expect(pulseNow(), before, reason: 'no motion when the member turned animations off');
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_host(const CallsListSkeleton()));
    final first = pulseNow();
    await tester.pump(const Duration(milliseconds: 700));
    final later = pulseNow();
    expect(later, isNot(first), reason: 'it breathes when animations are on');
  });
}

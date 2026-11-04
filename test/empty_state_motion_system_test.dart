import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/widgets/silarah_empty_state.dart';

Widget _host(SilarahEmptyVisual visual, {bool reduceMotion = false}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: SilarahEmptyState(
          visual: visual,
          title: 'Empty state',
          subtitle: 'A clear explanation of what happens next.',
        ),
      ),
    ),
  );
}

void main() {
  const narrativeVisuals = [
    SilarahEmptyVisual.discovery,
    SilarahEmptyVisual.interests,
    SilarahEmptyVisual.sentInterests,
    SilarahEmptyVisual.conversations,
    SilarahEmptyVisual.savedProfiles,
  ];

  for (final visual in narrativeVisuals) {
    testWidgets('$visual renders smoothly without a stock icon',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_host(visual));
      await tester.pump(const Duration(milliseconds: 620));
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
      }

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Empty state'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('motion system honors reduced-motion accessibility',
      (tester) async {
    await tester.pumpWidget(
      _host(SilarahEmptyVisual.conversations, reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 620));
    await tester.pump(const Duration(seconds: 6));

    expect(tester.takeException(), isNull);
    expect(find.text('Empty state'), findsOneWidget);
  });

  test('primary empty screens use dedicated narrative scenes', () {
    final discovery =
        File('lib/features/home/screens/discovery_feed_screen.dart')
            .readAsStringSync();
    final interests = File('lib/features/home/screens/interests_screen.dart')
        .readAsStringSync();
    final chat = File('lib/features/home/screens/chat_list_screen.dart')
        .readAsStringSync();
    final profile = File('lib/features/home/screens/my_profile_screen.dart')
        .readAsStringSync();

    // Discover has its own mihrab scene with filter-aware actions.
    expect(discovery, contains('DiscoveryEmptyState('));
    expect(interests, contains('SilarahEmptyVisual.interests'));
    expect(interests, contains('SilarahEmptyVisual.sentInterests'));
    expect(chat, contains('SilarahEmptyVisual.conversations'));
    expect(profile, contains('SilarahEmptyVisual.savedProfiles'));
  });
}

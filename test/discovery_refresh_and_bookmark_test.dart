import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/widgets/cards/silarah_profile_card.dart';
import 'package:silarah/core/widgets/loaders/silarah_shimmer.dart';

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));

  test('filter refresh keeps one stable PageView controller attachment', () {
    final source = File(
      'lib/features/home/screens/discovery_feed_screen.dart',
    ).readAsStringSync();

    expect(
      'positions.length == 1'.allMatches(source),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      source,
      isNot(
        contains(
          'if (feedState.status != FeedStatus.refreshing) return carousel;',
        ),
      ),
    );
    expect(
      source,
      contains('if (feedState.status == FeedStatus.refreshing)'),
    );
  });

  testWidgets('bookmark control is high contrast and reflects saved state',
      (tester) async {
    AppColors.activate(SilarahThemeMode.ivoryEmerald);

    Future<void> pumpCard({required bool saved}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SilarahProfileCard(
                  displayName: 'Member',
                  age: 28,
                  cityName: 'Kurnool',
                  isBookmarked: saved,
                  onBookmark: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCard(saved: false);
    final unsavedIcon = tester.widget<Icon>(
      find.byIcon(Icons.bookmark_outline_rounded),
    );
    expect(unsavedIcon.color, AppColors.onMedia);
    expect(find.bySemanticsLabel('Save profile'), findsOneWidget);

    await pumpCard(saved: true);
    final savedIcon = tester.widget<Icon>(
      find.byIcon(Icons.bookmark_rounded),
    );
    expect(savedIcon.color, AppColors.overlayBlack87);
    expect(find.bySemanticsLabel('Remove saved profile'), findsOneWidget);
  });

  testWidgets('relationship action remains visible and can be disabled',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SilarahProfileCard(
                displayName: 'Member',
                age: 28,
                cityName: 'Kurnool',
                interestActionLabel: 'Interest Sent',
                isInterestActionEnabled: false,
                onSendInterest: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Interest Sent'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.text('Interest Sent'));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('only the card action animates while an interest is sending',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SilarahProfileCard(
                displayName: 'Member',
                age: 28,
                cityName: 'Kurnool',
                interestActionLabel: 'Sending...',
                isInterestActionEnabled: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sending...'), findsOneWidget);
    expect(find.byType(SilarahActivityIndicator), findsOneWidget);
    expect(find.byType(SilarahLinearProgress), findsNothing);
  });

  testWidgets(
      'premium card keeps media copy readable and explains identity trust',
      (tester) async {
    AppColors.activate(SilarahThemeMode.ivoryEmerald);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SilarahProfileCard(
                displayName: 'Khatun Khatun',
                age: 25,
                cityName: 'Kurnool',
                sect: 'SUNNI',
                deenLevel: 'practicing',
                profession: 'Writer',
                photoCount: 3,
                isVerified: true,
                lastActiveLabel: '23 hr ago',
                previousMatchLabel: 'Previously matched on Jul 18',
                interestActionLabel: 'Send Interest Again',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('23 hr ago'), findsOneWidget);
    expect(find.text('Previously matched on Jul 18'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Profile photo verified')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    final displayName = tester.widget<Text>(find.text('Khatun Khatun'));
    expect(displayName.style?.color, AppColors.onMedia);
    expect(tester.takeException(), isNull);
  });

  for (final mode in SilarahThemeMode.values) {
    testWidgets(
        '${mode.storageValue} keeps the enabled CTA prominent and frame complete',
        (tester) async {
      AppColors.activate(mode);

      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(mode),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SilarahProfileCard(
                  displayName: 'Member',
                  age: 28,
                  cityName: 'Kurnool',
                  previousMatchLabel: 'Previously matched on Jul 18',
                  interestActionLabel: 'Send Interest Again',
                  onSendInterest: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final frame = tester.widget<Container>(
        find.byKey(const Key('discovery_profile_card_frame')),
      );
      final frameDecoration = frame.foregroundDecoration! as BoxDecoration;
      final frameBorder = frameDecoration.border! as Border;
      for (final side in [
        frameBorder.top,
        frameBorder.right,
        frameBorder.bottom,
        frameBorder.left,
      ]) {
        expect(side.style, BorderStyle.solid);
        // A hairline frame on every side reads as finish, not a widget outline.
        expect(side.width, 1.0);
      }

      final action = tester.widget<AnimatedContainer>(
        find.byKey(const Key('discovery_interest_action')),
      );
      final actionDecoration = action.decoration! as BoxDecoration;
      final actionGradient = actionDecoration.gradient! as LinearGradient;
      expect(actionGradient.colors, isNot(contains(AppColors.overlayBlack87)));
      expect(actionDecoration.boxShadow, isNotEmpty);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      final label = tester.widget<Text>(find.text('Send Interest Again'));
      expect(
        label.style?.color,
        AppColors.readableOn(actionGradient.colors[1]),
      );
      expect(actionGradient.colors.first, AppColors.champagneLight);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in [
    SilarahThemeMode.ivoryEmerald,
    SilarahThemeMode.roseMarigold,
    SilarahThemeMode.oled,
  ]) {
    testWidgets('private photo caption appears once in ${mode.name}',
        (tester) async {
      AppColors.activate(mode);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: SilarahProfileCard(
                  displayName: 'Member',
                  age: 28,
                  cityName: 'Kurnool',
                  photoCount: 1,
                  isPhotoPrivate: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // One centred caption under the placeholder icon, not a second pill.
      expect(
        find.textContaining('visible after acceptance'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      // The lock + count chip in the corner stays.
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

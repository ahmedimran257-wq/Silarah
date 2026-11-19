import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/viewed_profiles_service.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/features/home/screens/viewed_profiles_screen.dart';
import 'package:silarah/features/home/widgets/viewed_profiles_button.dart';

// "Viewed profiles" lets a member find a profile they passed in Discover
// after a refresh, a restart or the next day.
void main() {
  group('day grouping', () {
    final now = DateTime(2026, 11, 19, 10, 30);

    test('same calendar day is Today, even just after midnight', () {
      expect(viewedPeriodFor(DateTime(2026, 11, 19, 0, 5), now),
          ViewedPeriod.today);
    });

    test('late last night is Yesterday, not Today', () {
      expect(viewedPeriodFor(DateTime(2026, 11, 18, 23, 50), now),
          ViewedPeriod.yesterday);
    });

    test('two to six days back is this week, older is Earlier', () {
      expect(viewedPeriodFor(DateTime(2026, 11, 17, 9), now),
          ViewedPeriod.thisWeek);
      expect(viewedPeriodFor(DateTime(2026, 11, 13, 9), now),
          ViewedPeriod.thisWeek);
      expect(viewedPeriodFor(DateTime(2026, 11, 12, 9), now),
          ViewedPeriod.earlier);
    });
  });

  test('server rows map to tiles without exposing more than the card', () {
    final entry = ViewedProfileEntry.fromRow(const {
      'user_id': 'u1',
      'first_name': 'Neha',
      'last_name_initial': 'k',
      'age': 25,
      'city_name': 'Kurnool',
      'is_verified': true,
      'photo_privacy': 'request_only',
      'photo_count': 2,
      'blurhash': null,
      'last_viewed_at': '2026-11-19T04:00:00+00:00',
    });
    expect(entry.displayName, 'Neha K.');
    expect(entry.hasPhotos, isTrue);
    expect(entry.photoUrl, isNull);
    expect(entry.withPhotoUrl('https://x').photoUrl, 'https://x');
  });

  group('wiring', () {
    final discovery =
        File('lib/features/home/screens/discovery_feed_screen.dart')
            .readAsStringSync();
    final screen = File('lib/features/home/screens/viewed_profiles_screen.dart')
        .readAsStringSync();
    final migration =
        File('supabase/migrations/305_my_viewed_profiles_gallery.sql')
            .readAsStringSync();

    test('Discover shows the entry button, limit link and empty-feed link', () {
      expect(discovery, contains('ViewedProfilesButton('));
      expect(discovery, contains('const SeeViewedProfilesAction()'));
      expect(discovery,
          contains('onViewHistory: () => ViewedProfilesScreen.open(context)'));
    });

    test('opening a past profile uses the same daily check as Discover', () {
      final check = screen.indexOf('.recordProfileView(entry.userId)');
      final load = screen.indexOf('AuthorizedProfileService.loadDiscoveryProfiles');
      expect(check, greaterThan(0));
      expect(load, greaterThan(check));
      expect(
        screen,
        contains('PaywallGateSheet.show(context, gate: PremiumGate.feature)'),
      );
    });

    test('the server list hides blocked, hidden, banned and incognito members',
        () {
      expect(migration, contains("owner.visibility = 'visible'"));
      expect(migration, contains('owner_account.deleted_at IS NULL'));
      expect(migration, contains('owner_account.is_banned'));
      expect(migration, contains('private.can_access_incognito_profile'));
      expect(migration, contains('public.blocks'));
      expect(migration, contains("interval '30 days'"));
      expect(migration, contains('FROM PUBLIC, anon'));
    });

    test('private photos never leak a blurhash', () {
      expect(
        migration,
        contains(
            "WHEN coalesce(owner.photo_privacy::text, 'public') = 'public'"),
      );
    });
  });

  for (final mode in SilarahThemeMode.values) {
    for (final direction in TextDirection.values) {
      testWidgets(
          'header button and link fit a narrow phone (${mode.name}, '
          '${direction.name})', (tester) async {
        AppColors.activate(mode);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: const Scaffold(
                body: Column(
                  children: [
                    Row(children: [ViewedProfilesButton(highlighted: true)]),
                    SeeViewedProfilesAction(),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.history_rounded), findsNWidgets(2));
      });
    }
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';
import 'package:silarah/core/models/discovery_profile.dart';

void main() {
  const profile = DiscoveryProfile(
    id: '00000000-0000-0000-0000-000000000002',
    firstName: 'Member',
    lastNameInitial: 'S',
    age: 28,
    cityName: 'Kurnool',
  );
  // Keep pending fixtures relative to the test clock so this contract does not
  // start failing once a hard-coded date crosses the 14-day expiry boundary.
  final now = DateTime.now().toUtc();

  InterestEntry entry(InterestStatus status) => InterestEntry(
        id: '00000000-0000-0000-0000-000000000003',
        profile: profile,
        timeAgo: 'Now',
        sentAt: now,
        createdAt: now,
        status: status,
      );

  test('an accepted match remains an authoritative relationship state', () {
    final state = InterestsState(
      matches: [entry(InterestStatus.accepted)],
      sent: [entry(InterestStatus.accepted)],
    );

    expect(state.discoveryHandoff, DiscoveryInteractionHandoff.matched);
  });

  test('active incoming and outgoing requests hand discovery to Interests', () {
    final received = InterestsState(
      received: [entry(InterestStatus.pending)],
    );
    final sent = InterestsState(
      sent: [entry(InterestStatus.pending)],
    );

    expect(
      received.discoveryHandoff,
      DiscoveryInteractionHandoff.receivedInterest,
    );
    expect(sent.discoveryHandoff, DiscoveryInteractionHandoff.sentInterest);
  });

  test('inactive history does not replace the genuine empty-feed guidance', () {
    final state = InterestsState(
      sent: [
        entry(InterestStatus.declined),
        entry(InterestStatus.withdrawn),
        entry(InterestStatus.expired),
      ],
    );

    expect(state.discoveryHandoff, DiscoveryInteractionHandoff.none);
  });

  test('one profile has one authoritative active relationship state', () {
    expect(
      InterestsState(sent: [entry(InterestStatus.pending)])
          .interactionWith(profile.id),
      ProfileInteractionState.pendingSent,
    );
    expect(
      InterestsState(received: [entry(InterestStatus.pending)])
          .interactionWith(profile.id),
      ProfileInteractionState.pendingReceived,
    );
    expect(
      InterestsState(matches: [entry(InterestStatus.accepted)])
          .interactionWith(profile.id),
      ProfileInteractionState.matched,
    );
    expect(
      InterestsState(sent: [entry(InterestStatus.declined)])
          .interactionWith(profile.id),
      ProfileInteractionState.none,
    );
    expect(
      InterestsState(sent: [entry(InterestStatus.withdrawn)])
          .interactionWith(profile.id),
      ProfileInteractionState.none,
    );
  });

  test('chat, bookmarks, and interest surfaces keep launch-safe contracts', () {
    final chatState =
        File('lib/core/cubits/chat/chat_state.dart').readAsStringSync();
    final chatCubit =
        File('lib/core/cubits/chat/chat_cubit.dart').readAsStringSync();
    final chatScreen =
        File('lib/features/home/screens/chat_screen.dart').readAsStringSync();
    final bookmarks =
        File('lib/core/services/bookmark_service.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/142_chat_delivery_reliability.sql',
    ).readAsStringSync();

    expect(chatState, contains('final String? photoUrl;'));
    expect(chatCubit, contains('getAuthorizedPhotoUrls'));
    expect(chatCubit, contains('retryMessage'));
    expect(chatScreen, contains('resizeToAvoidBottomInset: true'));
    expect(chatScreen, isNot(contains('SpringKeyboardPadding')));
    expect(bookmarks, contains('_writeQueue'));
    expect(migration, contains('SECURITY DEFINER'));
    expect(migration, contains('EXCEPTION WHEN OTHERS'));
    expect(migration, contains('Message % committed without push enqueue'));
  });

  test('relationship states remain visible without replacing empty guidance',
      () {
    final visibilityMigration = File(
      'supabase/migrations/188_relationship_aware_discovery_and_card_context.sql',
    ).readAsStringSync();
    final screen = File(
      'lib/features/home/screens/discovery_feed_screen.dart',
    ).readAsStringSync();
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();

    expect(visibilityMigration, contains("active_match.match_id IS NOT NULL"));
    expect(visibilityMigration, contains("THEN 'matched'"));
    expect(
      visibilityMigration,
      contains("rematch_guard.status IN (''blocked'',''reported'')"),
    );
    expect(screen, isNot(contains('interests.discoveryHandoff')));
    expect(screen, isNot(contains('discovery_handoff_match_title')));
    // The empty guidance still offers a refresh, now localized in the
    // dedicated Discover empty state.
    expect(screen, contains('DiscoveryEmptyState('));
    expect(screen, contains('onRefresh: () => cubit.loadInitial(force: true)'));
    expect(
      File('lib/features/home/widgets/discovery_empty_state.dart')
          .readAsStringSync(),
      contains('l10n.discovery_empty_refresh'),
    );
    final sendHandler = screen.substring(
      screen.indexOf('Future<void> _handleSendInterest'),
      screen.indexOf('Future<void> _handleBookmark'),
    );
    expect(sendHandler, isNot(contains('loadInitial(force: true)')));
    expect(sendHandler, isNot(contains('showInterestCeremony')));
    expect(screen, contains("label: 'Sending...'"));
    expect(screen, isNot(contains('_sentInterests')));
    expect(screen, contains("label: 'Interest Sent'"));
    expect(screen, contains("label: 'Review Interest'"));
    expect(
      screen,
      contains('l10n.discovery_rematch_days(cooldownDays)'),
    );
    expect(home, contains('case 0:'));
    expect(home, contains('refreshIfChanged()'));
    expect(home, contains('AppLifecycleState.resumed'));
  });
}

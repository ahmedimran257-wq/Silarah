import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('background health and presence writes are low-frequency', () {
    final connectivity = source('lib/core/services/connectivity_service.dart');
    final presence = source('lib/core/services/presence_service.dart');
    final main = source('lib/main.dart');

    expect(connectivity, contains('Duration(minutes: 5)'));
    expect(connectivity, contains('_offlineRetryInterval'));
    expect(connectivity, contains('if (!_isForeground)'));
    expect(main, isNot(contains('checkInterval: const Duration(seconds: 10)')));
    expect(presence, contains('Duration(minutes: 10)'));
    expect(presence, contains('_duplicateStateWindow'));
  });

  test('chat and notification reads are event-driven and bounded', () {
    final chatList = source('lib/features/home/screens/chat_list_screen.dart');
    final chat = source('lib/core/cubits/chat/chat_cubit.dart');
    final notifications =
        source('lib/core/cubits/notifications/notifications_cubit.dart');

    expect(chatList, isNot(contains('Timer.periodic')));
    expect(chat, contains('_inboxFreshness'));
    expect(chat, contains('_inboxLoadInFlight'));
    expect(chat, contains('Future<void> refreshIfChanged'));
    expect(chat, contains('scheduleInboxReconciliation'));
    expect(chat, isNot(contains("channel('chat_inbox:")));
    expect(chat, isNot(contains('unawaited(loadConversations());')));
    expect(notifications, contains('_maxRetainedNotifications = 100'));
    expect(notifications, contains('.limit(_maxRetainedNotifications)'));
    expect(notifications, contains('_freshness = Duration(minutes: 5)'));
    expect(notifications, contains('reconcileForegroundPush'));
    expect(notifications, isNot(contains("channel('user_notifications_")));
  });

  test('idle signed-in members do not consume realtime connections', () {
    final standing = source(
      'lib/core/cubits/account_standing/account_standing_cubit.dart',
    );
    final chat = source('lib/core/cubits/chat/chat_cubit.dart');

    expect(standing, isNot(contains('.channel(')));
    expect(chat, contains("'chat:\$conversationId'"));
    expect(chat, contains('currently open private chat'));
  });

  test('signed photo URLs and bookmarks are account-scoped caches', () {
    final photos = source('lib/core/services/profile_photo_service.dart');
    final bookmarks = source('lib/core/services/bookmark_service.dart');

    expect(photos, contains('_readUrlCache'));
    expect(photos, contains('_readUrlLoads'));
    expect(photos, contains('_signedUrlSafetyMargin'));
    expect(photos, contains('_maxCachedUrls = 200'));
    expect(bookmarks, contains('_cachedUserId'));
    expect(bookmarks, contains('_loadInFlight'));
    expect(bookmarks, contains('_freshness = Duration(minutes: 5)'));
  });

  test('large relational screens batch instead of querying per person', () {
    final interests = source('lib/core/cubits/interests/interests_cubit.dart');
    final blocks =
        source('lib/core/cubits/block_report/block_report_cubit.dart');
    final home = source('lib/features/home/home_screen.dart');

    expect(interests, contains('Future.wait<dynamic>'));
    expect(interests, contains('_loadProfilesForUsers'));
    expect(interests, isNot(contains('_loadProfileForUser')));
    expect(interests, contains('_maxRowsPerSection = 100'));
    expect(interests, contains('_batches(userIds, 50)'));
    expect(interests, contains('_batches(profileIds, 50)'));
    expect(interests, contains('_batches(photoOwners, 50)'));
    expect(
      blocks,
      contains('AuthorizedProfileService.load(relatedUserIds)'),
    );
    expect(home, contains('final Map<HomeTab, Widget> _tabCache = {};'));
  });

  test('discovery and admin refreshes have explicit cost ceilings', () {
    final discovery =
        source('lib/core/cubits/discovery/discovery_feed_cubit.dart');
    final cockpit = source('admin/src/components/live-operations-cockpit.tsx');
    final adminRefresh = source('admin/src/components/navigation-state.tsx');
    final adminSidebar = source('admin/src/components/admin-sidebar.tsx');

    expect(
      RegExp(r'_loadServerViewQuota\(\)').allMatches(discovery).length,
      2,
    );
    expect(discovery, contains('_viewerReadinessFreshness'));
    expect(discovery, contains('_revisionCheckFreshness'));
    expect(discovery, contains('Duration(seconds: 90)'));
    expect(discovery, contains("'get_my_discovery_revision'"));
    expect(discovery, contains("'p_filters': _mapFilterToJson(filter)"));
    // The cockpit reads "Online now" live (one indexed count), so it may
    // refresh at most once a minute and only in a visible tab; the heavy
    // figures still come from the 15-minute metrics snapshot. Other pages
    // refresh on demand, never on a background timer.
    expect(cockpit, contains('const liveEveryMs = 60 * 1000;'));
    expect(cockpit, contains('if (document.hidden)'));
    expect(cockpit, contains('window.clearInterval(timer)'));
    expect(adminRefresh, contains('const staleAfterMs = 5 * 60 * 1000'));
    expect(adminRefresh, isNot(contains('setInterval')));
    expect(adminSidebar, contains('prefetch={false}'));
  });

  test('tab and resume reconciliation do not bypass surface caches', () {
    final home = source('lib/features/home/home_screen.dart');
    final main = source('lib/main.dart');
    final interests = source('lib/core/cubits/interests/interests_cubit.dart');
    final relationshipRevision =
        source('lib/core/services/relationship_revision_service.dart');

    expect(
      home,
      contains(
        'read<InterestsCubit>().refreshIfChanged(forceCheck: true)',
      ),
    );
    expect(home, contains('read<ChatCubit>().refreshIfChanged()'));
    expect(home, isNot(contains('loadData(force: true)')));
    expect(
      main,
      contains('_interestsCubit.refreshIfChanged(forceCheck: true)'),
    );
    expect(main, contains('_chatCubit.refreshIfChanged()'));
    expect(interests, contains('Future<void> refreshIfChanged'));
    expect(relationshipRevision, contains('get_my_relationship_revision'));
  });
}

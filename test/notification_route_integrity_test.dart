import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';

void main() {
  const matchId = '8c8a2b1e-4d62-4d90-a59b-a7ce4c48d092';
  const profileId = '455533ed-b96b-41b6-89c2-1789fdd8f4c5';

  test('accepts only known routes and UUID-backed entities', () {
    expect(
      notificationPathFromDeepLink('silarah://chat/$matchId'),
      '/chat/$matchId',
    );
    expect(
      notificationPathFromDeepLink('silarah://profile/$profileId'),
      '/profile/$profileId',
    );
    // Stored notifications still carry the four-tab numbers (3 = Profile).
    expect(notificationPathFromDeepLink('/home?tab=2'), '/home?tab=chats');
    expect(notificationPathFromDeepLink('/home?tab=3'), '/home?tab=profile');
    expect(notificationPathFromDeepLink('/home?tab=calls'), '/home?tab=calls');
    expect(notificationPathFromDeepLink('/home?tab=4'), isNull);
    expect(notificationPathFromDeepLink('silarah://calls'), '/home?tab=calls');
    expect(notificationPathFromDeepLink('/calls'), '/home?tab=calls');
    expect(notificationPathFromDeepLink('/not-a-real-screen'), isNull);
    expect(notificationPathFromDeepLink('/chat/not-a-uuid'), isNull);
    expect(
      notificationPathFromDeepLink('https://example.com/chat/$matchId'),
      isNull,
    );
    expect(
      notificationPathFromDeepLink('silarah://chat/$matchId?redirect=bad'),
      isNull,
    );
  });

  test('message notifications recover safely from missing relationship data',
      () {
    expect(
      notificationDestinationPath(
        type: 'new_message',
        matchId: matchId,
      ),
      '/chat/$matchId',
    );
    expect(
      notificationDestinationPath(type: 'new_message'),
      '/home?tab=chats',
    );
    expect(
      notificationDestinationPath(
        type: 'new_message',
        deepLink: 'silarah://chat/not-a-uuid',
      ),
      '/home?tab=chats',
    );
  });

  test('every notification family has a stable fallback', () {
    expect(
      notificationDestinationPath(type: 'interest_expiring'),
      '/home?tab=interests',
    );
    expect(
      notificationDestinationPath(type: 'interest_expired'),
      '/home?tab=interests',
    );
    expect(
      notificationDestinationPath(type: 'match_ended'),
      '/home?tab=discover',
    );
    expect(
      notificationDestinationPath(type: 'account_limited'),
      '/help-support',
    );
    expect(
      notificationDestinationPath(type: 'referral_reward'),
      '/home?tab=profile',
    );
    expect(
      notificationDestinationPath(type: 'profile_view'),
      '/profile-views',
    );
  });

  test('foreground and stored notification handlers use the same router', () {
    final fcm = File('lib/core/services/fcm_service.dart').readAsStringSync();
    final stored = File(
      'lib/core/cubits/notifications/notifications_cubit.dart',
    ).readAsStringSync();
    expect(fcm, contains('notificationDestinationPath('));
    expect(stored, contains('notificationDestinationPath('));
  });

  test('chat lifecycle migration neutralizes inaccessible message routes', () {
    final migration = File(
      'supabase/migrations/255_notification_chat_lifecycle_integrity.sql',
    ).readAsStringSync();
    expect(migration, contains('trg_sync_chat_notification_lifecycle'));
    expect(migration, contains("n.type = 'new_message'"));
    expect(migration, contains("deep_link = 'silarah://chat'"));
    expect(migration,
        contains('AFTER UPDATE OF hidden_by_a_at, hidden_by_b_at OR DELETE'));
  });

  test('release startup disables debug paint overlays', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('debugPaintBaselinesEnabled = false'));
    expect(main, contains('debugPaintPointersEnabled = false'));
    expect(main, contains('debugPaintSizeEnabled = false'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';

void main() {
  group('progressive profile nudges', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/115_progressive_profile_nudges.sql',
      ).readAsStringSync();
    });

    test('routes every profile action through the shared resolver', () {
      expect(
        notificationPathFromDeepLink('silarah://verify'),
        '/badge-verification',
      );
      expect(
        notificationPathFromDeepLink('silarah://photos'),
        '/edit-profile?section=photos',
      );
      expect(
        notificationPathFromDeepLink('silarah://complete-profile'),
        '/edit-profile',
      );
      expect(
        notificationPathFromDeepLink('silarah://verify-identity'),
        '/verify',
      );
      expect(
        notificationPathFromDeepLink('silarah://subscription'),
        '/subscription',
      );
      expect(
        notificationPathFromDeepLink('silarah://discover'),
        '/home?tab=discover',
      );
      expect(
        notificationPathFromDeepLink('silarah://interests'),
        '/home?tab=interests',
      );
    });

    test('enforces activity, completion, and three-day suppression in SQL', () {
      expect(
          migration, contains("p.last_active_at > now() - interval '7 days'"));
      expect(migration, contains('coalesce(p.completeness_score, 0) < 95'));
      expect(migration, contains("now() - interval '3 days'"));
      expect(migration, contains('GET DIAGNOSTICS v_claimed = ROW_COUNT'));
    });

    test('creates one dynamic priority-based notification', () {
      expect(migration, contains('profile_nudge_rules'));
      expect(migration, contains('ORDER BY rule.priority'));
      expect(migration, contains("p_user_id, 'profile_nudge'"));
      expect(migration, contains("'0 10 * * *'"));
      expect(migration, contains('/functions/v1/dispatch-notifications'));
    });

    test('derives preferences and approved photos from live relations', () {
      expect(migration, contains('FROM public.profile_preferences pref'));
      expect(migration, contains('FROM public.photos ph'));
      expect(migration, contains("ph.status = 'active'"));
      expect(migration, contains('ph.nsfw_cleared = true'));
    });
  });
}

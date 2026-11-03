import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File('supabase/migrations/275_live_profile_boost.sql')
        .readAsStringSync();
  });

  // Regression: boost was read only by the nightly rank job, so a two-hour
  // boost had no effect on the live feed.
  test('an active boost lifts the live feed shortlist and final score', () {
    expect(migration,
        contains('candidate_profile.boost_expires_at > now()) DESC'));
    expect(migration, contains('boosted.boost_expires_at > now()'));
    expect(migration, contains('THEN 15.0 ELSE 0.0 END'));
    expect(migration, contains("'live_boost_feed_anchor_not_found'"));
  });

  // History only: 275 exempted women. Migration 289 makes boost Premium-only
  // for everyone; see test/profile_reminders_rank_and_boost_test.dart.
  test('275 boost entitlement matched messaging (superseded by 289)', () {
    expect(
        migration,
        contains(
            'PERFORM private.assert_outgoing_chat_entitlement(auth.uid());'));
    expect(migration, contains("IF v_gender IS DISTINCT FROM 'female' THEN"));
    expect(migration, isNot(contains("v_subscription IN ('active', 'grace')")));
    expect(migration, contains("interval '7 days'"));
    expect(migration, contains("interval '2 hours'"));
  });
}

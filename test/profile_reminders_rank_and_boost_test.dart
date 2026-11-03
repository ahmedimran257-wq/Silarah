import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/subscription/subscription_state.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';

/// Migration 289: profile-completion reminders, the Discover quality score
/// and Premium-only boosts.
void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/289_profile_reminders_ranking_and_premium_boost.sql',
    ).readAsStringSync();
  });

  String functionBody(String signature) {
    final start = migration.indexOf('CREATE OR REPLACE FUNCTION $signature');
    expect(start, isNonNegative, reason: signature);
    final end = migration.indexOf(r'$$;', start);
    return migration.substring(start, end);
  }

  group('boost is Premium-only', () {
    test('the boost RPC has no gender exemption', () {
      final body = functionBody('public.activate_profile_boost()');
      expect(body, contains('IF NOT public.has_active_premium(auth.uid())'));
      expect(body, isNot(contains("'female'")));
      expect(body, isNot(contains('v_gender')));
      expect(body, contains("interval '2 hours'"));
      expect(body, contains("interval '7 days'"));
    });

    test('the weekly boost reminder only goes to Premium members', () {
      final body = functionBody('private.process_member_reminders(');
      expect(body, contains('AND public.has_active_premium(u.id)'));
      expect(body, isNot(contains("= 'female'")));
    });

    test('women still message free; the boost card follows Premium', () {
      const free = SubscriptionState();
      expect(free.canMessage('female'), isTrue);
      expect(free.canMessage('male'), isFalse);
      expect(free.canBoostProfile('female'), isFalse);
      expect(free.canBoostProfile('male'), isFalse);

      const premium = SubscriptionState(status: SubscriptionStatus.active);
      expect(premium.canBoostProfile('female'), isTrue);
      expect(premium.canBoostProfile('male'), isTrue);

      final screen = File('lib/features/home/screens/my_profile_screen.dart')
          .readAsStringSync();
      expect(screen, contains('subState.canBoostProfile(gender) || isActive'));
      expect(screen, isNot(contains('isFemale || subState.isSubscribed')));
    });

    test('free messaging for women is not touched by this migration', () {
      expect(migration, isNot(contains('assert_outgoing_chat_entitlement(')));
    });
  });

  group('Discover quality score', () {
    test('every component is capped and the maximums sum to 100', () {
      final body = functionBody('private.profile_rank_breakdown(');
      expect(
          body, contains('AND p.photo_verification_paused_at IS NULL THEN 15'));
      expect(body, contains('guardian_user_id IS NOT NULL THEN 5'));
      expect(body, contains('5 * least(greatest(v_photos - 1, 0), 3)'));
      expect(body, contains('WHEN v_bio_length >= 150 THEN 10'));
      expect(body, contains('WHEN v_bio_length >= 50 THEN 5'));
      expect(body, contains('/ 10.0'));
      expect(body, contains("WHEN 'platinum' THEN 15"));
      expect(body,
          contains('round(20 * power(0.5::numeric, v_days_active / 7.0))'));
      expect(body, contains('round(10 * (1 - v_days_live / 14.0))'));
      expect(body,
          contains('least(greatest(coalesce(v_casual_penalty, 0), 0), 15)'));
      expect(body, contains('least(100, greatest(0,'));
      expect(body, contains('WHEN coalesce(v_shadowbanned, false) THEN 0'));
      // 15 + 5 + 15 + 10 + 10 + 15 + 20 + 10
      expect(15 + 5 + 15 + 10 + 10 + 15 + 20 + 10, 100);
    });

    test('the score is precomputed by triggers and the nightly job', () {
      expect(
        functionBody('public.trigger_update_completeness()'),
        contains("(private.profile_rank_breakdown(NEW)->>'total')::integer"),
      );
      expect(migration,
          contains('CREATE TRIGGER trg_refresh_profile_scores_photos'));
      expect(
        migration,
        contains('AFTER INSERT OR DELETE OR UPDATE OF status, admin_approved, '
            'nsfw_cleared,'),
      );
      final nightly = functionBody('public.compute_global_rank_scores()');
      expect(nightly, contains('PERFORM compute_casual_penalties();'));
      expect(nightly, contains('IS DISTINCT FROM fresh.total'));
    });

    test('the live feed and its per-call plans are left alone', () {
      expect(migration, isNot(contains('FUNCTION public.get_discovery_feed')));
      expect(
          migration, isNot(contains('plan_cache_mode = force_generic_plan')));
      final plans = File(
        'supabase/migrations/281_discovery_feed_custom_plans.sql',
      ).readAsStringSync();
      expect(plans, contains('SET plan_cache_mode = force_custom_plan'));
      // The header documents how quality blends with relevance.
      expect(migration, contains('0.72 x mutual preference fit'));
      expect(migration, contains('0.18 x static_rank_score'));
    });
  });

  group('profile-completion reminders', () {
    const gaps = [
      'photo_verification',
      'photos',
      'bio',
      'deen',
      'education',
      'family',
      'marriage_timeline',
      'partner_preferences',
    ];
    const languages = [
      'en',
      'ar',
      'bn',
      'de',
      'fr',
      'hi',
      'id',
      'ms',
      'tr',
      'ur'
    ];

    test('every item has copy in every app language', () {
      for (final gap in gaps) {
        for (final language in languages) {
          expect(migration, contains("('$gap', '$language', '"),
              reason: '$gap/$language');
        }
      }
    });

    test('each item deep-links to the screen that fixes it', () {
      expect(
        migration,
        contains("('photo_verification', 10, 'Verify your profile photo'"),
      );
      expect(notificationPathFromDeepLink('silarah://verify'),
          '/badge-verification');
      expect(notificationPathFromDeepLink('silarah://photos'),
          '/edit-profile?section=photos');
      expect(notificationPathFromDeepLink('silarah://complete-profile'),
          '/edit-profile');
      for (final link in RegExp(r"'(silarah://[a-z-]+)'")
          .allMatches(migration)
          .map((match) => match.group(1)!)) {
        expect(notificationPathFromDeepLink(link), isNotNull, reason: link);
      }
    });

    test('rate limits: 3 days per member, 14 days and 3 sends per item', () {
      final send = functionBody('public.dispatch_profile_nudge(');
      expect(send, contains("<= now() - interval '3 days'"));
      expect(send, contains('GET DIAGNOSTICS v_claimed = ROW_COUNT'));
      expect(send, contains('sent.sent_count < 3'));
      expect(send, contains("sent.last_sent_at <= now() - interval '14 days'"));
      expect(send, contains('IF cardinality(v_gaps) = 0 THEN'));
      expect(send, contains("ORDER BY (c.language_code = v_lang) DESC"));
      // Quiet hours are applied by queue_notification.
      expect(send, contains('PERFORM public.queue_notification('));
      expect(send, isNot(contains('INSERT INTO public.notifications')));
    });

    test('only live members who allow activity nudges are reminded', () {
      final audience = functionBody('private.profile_nudge_audience(');
      for (final rule in [
        'u.deleted_at IS NULL',
        "u.deletion_status = 'active'",
        'coalesce(u.is_banned, false) = false',
        'coalesce(u.is_shadowbanned, false) = false',
        'u.messaging_suspended_until <= now()',
        "coalesce(u.account_role, 'member') <> 'guardian'",
        "p.visibility = 'visible'",
        "p.approved_at <= now() - interval '1 day'",
        "p.last_active_at > now() - interval '7 days'",
        'coalesce(prefs.inactive_nudge, true) = true',
      ]) {
        expect(audience, contains(rule), reason: rule);
      }
      expect(
        functionBody('public.dispatch_profile_nudges()'),
        contains('LIMIT 500'),
      );
    });

    test('a photo check awaiting review is not nagged about', () {
      final completion = functionBody('private.profile_completion_gaps(');
      expect(completion, contains("s.status = 'pending'"));
      expect(completion, contains(') < 2),'));
      expect(
          completion, contains("char_length(btrim(coalesce(p.bio, ''))) < 50"));
    });
  });
}

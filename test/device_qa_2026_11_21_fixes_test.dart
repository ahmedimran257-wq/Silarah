// Fixes from the second device test of 21 Nov 2026
// (docs/device_test_checklist_2026-11-20.md, second list).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';
import 'package:silarah/features/home/screens/my_profile_screen.dart';
import 'package:silarah/l10n/ui_copy_supplement.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('the time-limited Premium banner counts down while Profile is open',
      () {
    test('it rebuilds just after the shown minute runs out', () {
      expect(
        premiumCountdownRefreshDelay(const Duration(minutes: 12, seconds: 20)),
        const Duration(seconds: 20, milliseconds: 250),
      );
      expect(
        premiumCountdownRefreshDelay(
            const Duration(hours: 3, minutes: 4, milliseconds: 500)),
        const Duration(milliseconds: 750),
      );
      // On an exact minute the next change is a whole minute away.
      expect(premiumCountdownRefreshDelay(const Duration(minutes: 5)),
          const Duration(minutes: 1, milliseconds: 250));
    });

    test('the wait is never longer than about a minute', () {
      for (var s = 1; s < 7200; s += 37) {
        final delay = premiumCountdownRefreshDelay(Duration(seconds: s));
        expect(delay, greaterThan(Duration.zero));
        expect(delay,
            lessThanOrEqualTo(const Duration(minutes: 1, milliseconds: 250)));
      }
    });

    test('the banner keeps a timer and cancels it', () {
      final screen = read('lib/features/home/screens/my_profile_screen.dart');
      final banner = screen.substring(
        screen.indexOf('class _ReferralPremiumProfileBannerState'),
        screen.indexOf('// Subscription Card'),
      );
      expect(banner, contains('premiumCountdownRefreshDelay(remaining)'));
      expect(banner, contains('_tick?.cancel();'));
      expect(banner, contains('if (!mounted) return;'));
    });
  });

  test('the 30-day pause after a decline counts from the decline', () {
    final migration = read(
        'supabase/migrations/320_interest_decline_pause_from_decline_time.sql');
    // The database stamps the answer time on every write path ...
    expect(migration, contains('BEFORE INSERT OR UPDATE ON public.interests'));
    expect(migration, contains('NEW.responded_at := now();'));
    // ... nobody can move it afterwards ...
    expect(migration, contains('NEW.responded_at := OLD.responded_at;'));
    // ... and send_interest measures the pause from it.
    expect(
        migration,
        contains(
            "coalesce(i.responded_at, i.created_at) + interval ''30 days''"));
    expect(migration, contains('not found exactly twice'));
  });

  test('welcome links are never cut off at large text sizes', () {
    final splash =
        read('lib/features/onboarding/screens/splash_brand_screen.dart');
    final links = splash.substring(
      splash.indexOf("'I have a Guardian invitation'"),
      splash.indexOf("'How Silarah works'"),
    );
    expect(links, contains('l10n.splash_referral_question'));
    expect(links, isNot(contains('maxLines')));
  });

  test('the consent title scrolls with the checkboxes', () {
    final gate = read('lib/features/onboarding/screens/legal_gate_screen.dart');
    final scroll = gate.substring(gate.indexOf('SingleChildScrollView('));
    final beforeCard =
        scroll.substring(0, scroll.indexOf('_TermsSummaryCard()'));
    expect(beforeCard, contains('l10n.legal_title'));
    expect(beforeCard, contains('l10n.legal_subtitle'));
    // Only one title on the screen.
    expect('l10n.legal_title'.allMatches(gate).length, 1);
  });

  test('no screen draws text that ignores the system text size', () {
    // RichText does not apply the system text scale; Text.rich does.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('RichText('))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('a refund or other billing change updates Premium while the app is open',
      () {
    // Every type the billing webhook sends ...
    final webhook = read('supabase/functions/revenuecat-webhook/index.ts');
    final sent = RegExp(r'"(subscription_[a-z_]+)"')
        .allMatches(webhook)
        .map((m) => m.group(1)!)
        .toSet();
    expect(sent, isNotEmpty);
    for (final type in sent) {
      expect(isBillingNotificationType(type), isTrue, reason: type);
    }
    expect(isBillingNotificationType('new_message'), isFalse);
    // ... re-reads Premium with RevenueCat's stale cache dropped first.
    final main = read('lib/main.dart');
    expect(main, contains('if (isBillingNotificationType(item.type)) {'));
    expect(main, contains('_subscriptionCubit.refreshFromStore()'));
    final cubit = read('lib/core/cubits/subscription/subscription_cubit.dart');
    final fromStore =
        cubit.substring(cubit.indexOf('Future<void> refreshFromStore()'));
    expect(fromStore.indexOf('invalidateCustomerInfoCache'),
        lessThan(fromStore.indexOf('refreshEntitlement()')));
  });

  test('the Discover header keeps its daily counter readable at large text',
      () {
    final feed = read('lib/features/home/screens/discovery_feed_screen.dart');
    // The logo does not grow with the system text size ...
    expect('textScaler: TextScaler.noScaling'.allMatches(feed).length,
        greaterThanOrEqualTo(2));
    // ... and the counter shrinks as a whole instead of ellipsizing to an
    // empty pill.
    final counter = feed.substring(feed.indexOf('class _FreeTierCounter'));
    expect(counter, contains('FittedBox('));
    expect(counter.substring(0, counter.indexOf('// Notification Button')),
        isNot(contains('TextOverflow.ellipsis')));
  });

  test('the profile quality line wraps instead of cutting both halves', () {
    final card = read('lib/features/home/widgets/profile_quality_card.dart');
    final label = card.substring(
        card.indexOf("context.uiCopy('Profile quality')") - 400,
        card.indexOf("context.uiCopy('Profile quality')") + 1200);
    expect(label, contains('Text.rich('));
    expect(label, contains('maxLines: 2'));
  });

  test('one filter or preference is worded in the singular', () {
    final sheet = read('lib/features/home/widgets/discovery_filter_sheet.dart');
    expect(sheet, contains("context.uiCopy('Apply 1 filter')"));
    expect(sheet, contains("context.uiCopy('1 preference selected')"));
    for (final locale in supplementalUiCopy.keys) {
      expect(supplementalUiCopy[locale]!['Apply 1 filter'], isNotNull,
          reason: locale);
      expect(supplementalUiCopy[locale]!['1 preference selected'], isNotNull,
          reason: locale);
    }
  });

  test('daily limits reset at each member own midnight', () {
    final migration = read(
        'supabase/migrations/321_daily_limits_reset_at_member_midnight.sql');
    // One definition of "today", from the member's stored timezone.
    expect(migration, contains('FUNCTION private.member_today(p_user uuid)'));
    expect(
        migration, contains('FUNCTION private.member_day_start(p_user uuid)'));
    expect(migration, contains('JOIN private.timezone_names tz'));
    // Every daily limit uses it; none keeps the UTC day.
    for (final signature in [
      'public.record_profile_view(uuid, boolean)',
      'public.get_profile_view_quota()',
      'public.get_discovery_feed(',
      'public.get_authorized_member_profiles(uuid[])',
      'public.get_authorized_photo_paths(',
      'public.can_bookmark_member(uuid)',
      'public.get_interest_quota()',
      'public.enforce_interest_limits()',
    ]) {
      expect(migration, contains(signature), reason: signature);
    }
    // Hopping timezones for extra resets is limited.
    expect(migration, contains("interval '7 days'"));
    expect(migration, contains('NEW.timezone := OLD.timezone;'));
  });
}

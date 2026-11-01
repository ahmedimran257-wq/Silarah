import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Monthly and 3-month are separate Play subscriptions; buying one while the
  // other is active starts a second subscription and charges twice.
  test('purchases check the store live before charging', () {
    final service =
        File('lib/core/services/subscription_service.dart').readAsStringSync();
    final check =
        service.indexOf('final current = await Purchases.getCustomerInfo();');
    final charge = service.indexOf('await Purchases.purchase(');
    expect(check, isNonNegative);
    expect(charge, greaterThan(check),
        reason: 'The live entitlement check must run before the purchase.');
    expect(service,
        contains('outcome: SubscriptionPurchaseOutcome.alreadyPurchased'));
  });

  // A member who still ends up with both plans keeps the access the other
  // plan pays for when one is refunded or expires. Verified on staging by
  // replaying both plans' events in a rolled-back transaction.
  test('one plan ending does not end Premium the other plan pays for', () {
    final sql =
        File('supabase/migrations/286_premium_survives_other_plan_ending.sql')
            .readAsStringSync();
    expect(
        sql,
        contains('CREATE OR REPLACE FUNCTION '
            'public.apply_revenuecat_subscription_event('));
    expect(sql, contains("<> split_part(p_product_id, ':', 1)"),
        reason: 'Only the other plan’s ledger events count.');
    expect(
        sql, contains("latest.event_type NOT IN ('EXPIRATION', 'REVOCATION')"));
    expect(sql, contains('AND latest.expires_at > now()'));
    expect(sql, contains("IF v_status = 'none' THEN"));
    expect(sql, contains('SET subscription_status = v_status'));
    // Duplicate and stale protection still run before any state change.
    expect(sql.indexOf("'duplicate_event'"),
        lessThan(sql.indexOf('UPDATE public.users')));
    expect(sql.indexOf("'stale_event'"),
        lessThan(sql.indexOf('UPDATE public.users')));
  });

  test('a paid member or a second tap cannot start another purchase', () {
    final cubit = File('lib/core/cubits/subscription/subscription_cubit.dart')
        .readAsStringSync();
    expect(cubit, contains('if (state.isLoading) return false;'));
    expect(cubit, contains('if (state.hasPaidPremium) {'));
  });
}

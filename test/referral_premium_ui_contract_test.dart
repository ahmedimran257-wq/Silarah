import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final mainSource = File('lib/main.dart').readAsStringSync();
  final subscription = File(
    'lib/features/home/screens/subscription_screen.dart',
  ).readAsStringSync();
  final profile = File(
    'lib/features/home/screens/my_profile_screen.dart',
  ).readAsStringSync();
  final fcm = File('lib/core/services/fcm_service.dart').readAsStringSync();
  final notifications = File(
    'lib/core/cubits/notifications/notifications_cubit.dart',
  ).readAsStringSync();
  final notificationRoutes = File(
    'lib/core/utils/notification_deep_link.dart',
  ).readAsStringSync();
  final subscriptionCubit = File(
    'lib/core/cubits/subscription/subscription_cubit.dart',
  ).readAsStringSync();

  test('reward events and app resume refresh promotional access', () {
    expect(mainSource, contains("item.type == 'referral_reward'"));
    // A reward must reach the server; only resume and reconnect may reuse a
    // grant read moments earlier.
    expect(
      mainSource,
      contains('unawaited(_refreshPremiumEntitlement(refreshDiscovery: true));'),
    );
    expect(
      mainSource,
      contains('refreshEntitlement(allowRecent: allowRecent)'),
    );
    expect(mainSource, contains('AppLifecycleState.resumed'));
  });

  test('referral subscription surface protects remaining free time', () {
    expect(subscription, contains('state.isReferralOnly'));
    expect(subscription, contains('_ReferralPremiumActiveView'));
    expect(subscription, contains('PopScope'));
    expect(subscription, contains('context.go(HomeTab.profile.path)'));
    expect(subscriptionCubit, contains('if (state.isReferralOnly)'));
    expect(
      subscriptionCubit,
      contains('Plans become available after it ends'),
    );
  });

  test('paid members see entitlement management instead of purchase plans', () {
    final paidBranch = subscription.indexOf('if (state.hasPaidPremium)');
    final referralBranch = subscription.indexOf('if (state.isReferralOnly)');
    final purchaseCta = subscription.indexOf('onTap: _startPurchase');
    expect(paidBranch, greaterThanOrEqualTo(0));
    expect(paidBranch, lessThan(referralBranch));
    expect(paidBranch, lessThan(purchaseCta));
    expect(subscription, contains('_PaidPremiumActiveView'));
    expect(subscription, contains("context.uiCopy('Manage Subscription')"));
  });

  test('profile exposes a prominent referral Premium banner', () {
    expect(profile, contains('_ReferralPremiumProfileBanner'));
    expect(profile, contains('subscription.isTemporaryPromotional'));
    expect(profile, contains('subscription.isTestOnly'));
    expect(profile, contains('referral_premiumFeaturesUnlocked'));
  });

  test('legacy referral pushes no longer open checkout', () {
    expect(notificationRoutes, contains("type == 'referral_reward'"));
    expect(notificationRoutes, contains('return HomeTab.profile.path'));
    expect(fcm, contains('notificationDestinationPath('));
    expect(notifications, contains('notificationDestinationPath('));
  });
}

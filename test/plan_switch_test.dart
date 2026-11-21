import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/subscription/subscription_cubit.dart';
import 'package:silarah/core/services/subscription_service.dart';
import 'package:silarah/core/services/supabase_service.dart';
import 'package:silarah/l10n/ui_copy_supplement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// An active member switches between the two Play subscriptions in the app.
// Monthly → 3 months is charged now (full 3-month price, unused monthly days
// added on); 3 months → monthly waits for the next renewal. Premium never
// lapses in between, and an unsettled switch is never started twice.

const _expiry = '2036-01-01T00:00:00Z';

const _transaction = {
  'transactionIdentifier': 'synthetic-transaction',
  'productIdentifier': 'silarah_three_month',
  'purchaseDate': '2026-09-27T00:00:00Z',
};

Map<String, dynamic> info({
  String? product,
  String store = 'PLAY_STORE',
  String? billingIssueAt,
}) {
  final entitlements = <String, dynamic>{
    if (product != null)
      'premium': {
        'identifier': 'premium',
        'isActive': true,
        'willRenew': true,
        'latestPurchaseDate': '2026-01-01T00:00:00Z',
        'originalPurchaseDate': '2026-01-01T00:00:00Z',
        'productIdentifier': product,
        'productPlanIdentifier':
            product.contains(':') ? product.split(':').last : null,
        'isSandbox': true,
        'store': store,
        'expirationDate': _expiry,
        'billingIssueDetectedAt': billingIssueAt,
      },
  };
  return {
    'originalAppUserId': 'fixture-user',
    'entitlements': {'all': entitlements, 'active': entitlements},
    'activeSubscriptions': [],
    'allExpirationDates': {},
    'allPurchasedProductIdentifiers': [],
    'firstSeen': '2026-01-01T00:00:00Z',
    'requestDate': '2026-09-26T00:00:00Z',
    'allPurchaseDates': {},
    'nonSubscriptionTransactions': [],
  };
}

Map<String, dynamic> package(String id, String type) => {
      'identifier': id,
      'packageType': type,
      'presentedOfferingContext': {'offeringIdentifier': 'fixture'},
      'product': {
        'identifier': id,
        'description': 'Synthetic plan',
        'title': 'Synthetic plan',
        'price': 1.0,
        'priceString': '1.00',
        'currencyCode': 'INR',
      },
    };

Map<String, dynamic> offerings() {
  final current = {
    'identifier': 'fixture',
    'serverDescription': 'Synthetic offering',
    'metadata': <String, Object>{},
    'availablePackages': [
      package(r'$rc_monthly', 'MONTHLY'),
      package(r'$rc_three_month', 'THREE_MONTH'),
    ],
    'monthly': package(r'$rc_monthly', 'MONTHLY'),
    'threeMonth': package(r'$rc_three_month', 'THREE_MONTH'),
  };
  return {
    'all': {'fixture': current},
    'current': current,
  };
}

PlatformException storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: 'synthetic ${code.name}');

const monthlyPlay = 'silarah_monthly:monthly';
const threeMonthPlay = 'silarah_three_month:three-month';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  late SupabaseClient client;
  late SubscriptionCubit cubit;
  late List<Map<dynamic, dynamic>> storeCalls;
  late Map<String, dynamic> storeInfo;
  late String serverGrant;
  Object? Function(Map<dynamic, dynamic> args)? onPurchase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storeCalls = [];
    storeInfo = info(product: monthlyPlay);
    serverGrant =
        '[{"is_active":true,"source":"paid","expires_at":"$_expiry"}]';
    onPurchase = null;
    client = SupabaseClient('https://billing.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('get_my_premium_entitlement')) {
        return http.Response(serverGrant, 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      return http.Response('[]', 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    SupabaseService.initializeForTesting(client);
    cubit = SubscriptionCubit();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'logIn':
          return {'customerInfo': storeInfo, 'created': false};
        case 'getCustomerInfo':
          return storeInfo;
        case 'syncAttributesAndOfferingsIfNeeded':
          return offerings();
        case 'purchasePackage':
          final args = call.arguments as Map;
          storeCalls.add(args);
          if (onPurchase != null) return onPurchase!(args);
          return {'customerInfo': storeInfo, 'transaction': _transaction};
      }
      return null;
    });
  });

  tearDown(() async {
    cubit.clear();
    await cubit.close();
    SupabaseService.reset();
    await client.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('PlanSwitch', () {
    test('reads plans from Play product IDs with or without a base plan', () {
      expect(PlanSwitch.planOf(monthlyPlay), SubscriptionPlan.monthly);
      expect(PlanSwitch.planOf('silarah_monthly'), SubscriptionPlan.monthly);
      expect(PlanSwitch.planOf(threeMonthPlay), SubscriptionPlan.threeMonth);
      expect(PlanSwitch.planOf('rc_promo_premium_lifetime'), isNull);
      expect(PlanSwitch.planOf(null), isNull);
    });

    test('the cheaper-per-day plan is never charged a prorated difference', () {
      // Google allows CHARGE_PRORATED_PRICE only when the price per day
      // goes up; the 3-month plan is cheaper per day.
      expect(PlanSwitch.modeFor(SubscriptionPlan.threeMonth),
          StoreReplacementMode.chargeFullPrice);
      expect(PlanSwitch.modeFor(SubscriptionPlan.monthly),
          StoreReplacementMode.deferred);
      expect(PlanSwitch.takesEffectNow(SubscriptionPlan.threeMonth), isTrue);
      expect(PlanSwitch.takesEffectNow(SubscriptionPlan.monthly), isFalse);
    });
  });

  test('monthly → 3 months is charged now and the plan changes at once',
      () async {
    await cubit.loginUser('fixture-user');
    expect(cubit.state.paidPlan, SubscriptionPlan.monthly);
    onPurchase = (_) {
      storeInfo = info(product: threeMonthPlay);
      return {'customerInfo': storeInfo, 'transaction': _transaction};
    };

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isTrue);

    expect(storeCalls, hasLength(1));
    expect(storeCalls.single['packageIdentifier'], r'$rc_three_month');
    expect(storeCalls.single['googleOldProductIdentifier'], 'silarah_monthly');
    expect(storeCalls.single['storeReplacementMode'], 'CHARGE_FULL_PRICE');
    expect(cubit.state.isSubscribed, isTrue);
    expect(cubit.state.paidPlan, SubscriptionPlan.threeMonth);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.successMessage, contains('3-month plan'));
  });

  test('3 months → monthly is booked for the renewal, nothing charged today',
      () async {
    storeInfo = info(product: threeMonthPlay);
    await cubit.loginUser('fixture-user');

    expect(await cubit.changePlan(SubscriptionPlan.monthly), isTrue);

    expect(storeCalls.single['packageIdentifier'], r'$rc_monthly');
    // RevenueCat wants the subscription ID without the base plan.
    expect(
        storeCalls.single['googleOldProductIdentifier'], 'silarah_three_month');
    expect(storeCalls.single['storeReplacementMode'], 'DEFERRED');
    // Play keeps the 3-month plan until its period end.
    expect(cubit.state.paidPlan, SubscriptionPlan.threeMonth);
    expect(cubit.state.scheduledPlan, SubscriptionPlan.monthly);
    expect(cubit.state.scheduledPlanStartsAt?.toUtc(), DateTime.parse(_expiry));
    expect(cubit.state.successMessage, contains('Nothing was charged today'));

    // Asking again does not open Google Play a second time.
    expect(await cubit.changePlan(SubscriptionPlan.monthly), isTrue);
    expect(storeCalls, hasLength(1));
  });

  test('the booking is dropped once the new plan is in force', () async {
    storeInfo = info(product: threeMonthPlay);
    await cubit.loginUser('fixture-user');
    await cubit.changePlan(SubscriptionPlan.monthly);
    expect(cubit.state.scheduledPlan, SubscriptionPlan.monthly);

    storeInfo = info(product: monthlyPlay);
    await cubit.refreshEntitlement();

    expect(cubit.state.paidPlan, SubscriptionPlan.monthly);
    expect(cubit.state.scheduledPlan, isNull);
    expect(cubit.state.scheduledPlanStartsAt, isNull);
  });

  test('a booking survives restarting the app', () async {
    storeInfo = info(product: threeMonthPlay);
    await cubit.loginUser('fixture-user');
    await cubit.changePlan(SubscriptionPlan.monthly);

    cubit.clear();
    await cubit.loginUser('fixture-user');

    expect(cubit.state.scheduledPlan, SubscriptionPlan.monthly);
  });

  test('closing the Play sheet changes nothing and says nothing', () async {
    await cubit.loginUser('fixture-user');
    onPurchase =
        (_) => throw storeError(PurchasesErrorCode.purchaseCancelledError);

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);

    expect(cubit.state.paidPlan, SubscriptionPlan.monthly);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isNull);
    expect(cubit.state.successMessage, isNull);
  });

  test('switching to the plan already in force never opens Google Play',
      () async {
    await cubit.loginUser('fixture-user');

    expect(await cubit.changePlan(SubscriptionPlan.monthly), isFalse);

    expect(storeCalls, isEmpty);
    expect(cubit.state.successMessage, 'You are already on this plan.');
  });

  test('a failed renewal must be fixed before switching', () async {
    storeInfo =
        info(product: monthlyPlay, billingIssueAt: '2026-09-20T00:00:00Z');
    await cubit.loginUser('fixture-user');

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);

    expect(storeCalls, isEmpty);
    expect(cubit.state.error, contains('renewal payment did not go through'));
  });

  test('free referral Premium has no plan to switch', () async {
    storeInfo = info();
    serverGrant =
        '[{"is_active":true,"source":"referral","expires_at":"$_expiry"}]';
    await cubit.loginUser('fixture-user');

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);

    expect(storeCalls, isEmpty);
    expect(cubit.state.error, contains('Plan switching needs'));
  });

  test('a subscription from another store is not switched through Play',
      () async {
    storeInfo = info(product: monthlyPlay, store: 'TEST_STORE');
    await cubit.loginUser('fixture-user');

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);

    expect(storeCalls, isEmpty);
    expect(cubit.state.error, contains('Plan switching needs'));
  });

  test('a lost result is not reported as failed and blocks a second switch',
      () async {
    await cubit.loginUser('fixture-user');
    onPurchase = (_) => throw storeError(PurchasesErrorCode.networkError);

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);
    expect(cubit.state.error, contains('has not confirmed the switch'));
    expect(cubit.state.paidPlan, SubscriptionPlan.monthly);
    expect(cubit.state.isSubscribed, isTrue);

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);
    expect(storeCalls, hasLength(1));
  });

  test('a switch that settles clears the hold on further switches', () async {
    await cubit.loginUser('fixture-user');
    onPurchase = (_) => throw storeError(PurchasesErrorCode.networkError);
    await cubit.changePlan(SubscriptionPlan.threeMonth);

    // Play confirmed it after all: the member is now on 3 months.
    storeInfo = info(product: threeMonthPlay);
    onPurchase = null;
    await cubit.refreshEntitlement();
    expect(cubit.state.paidPlan, SubscriptionPlan.threeMonth);

    expect(await cubit.changePlan(SubscriptionPlan.monthly), isTrue);
    expect(storeCalls, hasLength(2));
    expect(storeCalls.last['storeReplacementMode'], 'DEFERRED');
  });

  test('a pending charge keeps the current plan and says so', () async {
    await cubit.loginUser('fixture-user');
    onPurchase =
        (_) => throw storeError(PurchasesErrorCode.paymentPendingError);

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);

    expect(cubit.state.error, contains('current plan stays active'));
    expect(cubit.state.isSubscribed, isTrue);
  });

  test('a charge RevenueCat has not moved over yet is not charged again',
      () async {
    await cubit.loginUser('fixture-user');
    // Play accepted, but RevenueCat still reports the monthly plan.
    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);
    expect(cubit.state.error, contains('has not confirmed the switch'));

    expect(await cubit.changePlan(SubscriptionPlan.threeMonth), isFalse);
    expect(storeCalls, hasLength(1));
  });

  test('every switch message is translated in every locale', () {
    final cubitSource =
        File('lib/core/cubits/subscription/subscription_cubit.dart')
            .readAsStringSync();
    const messages = [
      'Switched to the 3-month plan. The unused days of your monthly plan were added on.',
      'Plan change booked. Your 3-month plan runs to its end date, then renews as monthly. Nothing was charged today.',
      'You are already on this plan.',
      'Payment is pending. Your plan switches after Google Play confirms it, and your current plan stays active until then.',
      'Plan switching needs an active Google Play subscription on this account. Please try again in a moment.',
      'Google Play has not confirmed the switch yet. Your current plan stays active. Please check again in a few minutes rather than switching twice.',
    ];
    for (final message in messages) {
      expect(cubitSource, contains(message));
      for (final locale in supplementalUiCopy.keys) {
        expect(supplementalUiCopy[locale]![message], isNotNull,
            reason: '$locale: $message');
      }
    }
  });
}

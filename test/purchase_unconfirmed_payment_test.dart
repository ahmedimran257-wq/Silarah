import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/subscription/subscription_cubit.dart';
import 'package:silarah/core/services/subscription_service.dart';
import 'package:silarah/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Monthly and 3-month are separate Play subscriptions. Play blocks buying
// the same one twice, but not the other one, so the app must not offer the
// other plan while a payment is pending, lost to a dropped connection, or
// on account hold.

const monthly = SubscriptionCubit.monthlyProductId;
const threeMonth = SubscriptionCubit.threeMonthProductId;

Map<String, dynamic> premium({
  required bool active,
  bool willRenew = true,
  String? billingIssueDetectedAt,
  String? unsubscribeDetectedAt,
  String expirationDate = '2036-01-01T00:00:00Z',
}) =>
    {
      'identifier': 'premium',
      'isActive': active,
      'willRenew': willRenew,
      'latestPurchaseDate': '2026-01-01T00:00:00Z',
      'originalPurchaseDate': '2026-01-01T00:00:00Z',
      'productIdentifier': 'silarah_monthly',
      'isSandbox': true,
      'expirationDate': expirationDate,
      if (billingIssueDetectedAt != null)
        'billingIssueDetectedAt': billingIssueDetectedAt,
      if (unsubscribeDetectedAt != null)
        'unsubscribeDetectedAt': unsubscribeDetectedAt,
    };

Map<String, dynamic> info({Map<String, dynamic>? entitlement}) {
  final active = entitlement != null && entitlement['isActive'] == true;
  return {
    'originalAppUserId': 'fixture-user',
    'entitlements': {
      'all': {if (entitlement != null) 'premium': entitlement},
      'active': {if (active) 'premium': entitlement},
    },
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
      package('silarah_monthly', 'MONTHLY'),
      package('silarah_three_month', 'THREE_MONTH'),
    ],
    'monthly': package('silarah_monthly', 'MONTHLY'),
    'threeMonth': package('silarah_three_month', 'THREE_MONTH'),
  };
  return {
    'all': {'fixture': current},
    'current': current,
  };
}

PlatformException storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: 'synthetic ${code.name}');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  late SupabaseClient client;
  late SubscriptionCubit cubit;
  late List<String> purchased;
  late Map<String, dynamic> storeInfo;
  late Map<String, dynamic> restoredInfo;
  Future<Object?> Function(String productId)? onPurchase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient('https://billing.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('get_my_premium_entitlement')) {
        return http.Response(
            '[{"is_active":false,"source":"none","expires_at":null}]', 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      return http.Response('[]', 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    SupabaseService.initializeForTesting(client);
    cubit = SubscriptionCubit();
    purchased = [];
    storeInfo = info();
    restoredInfo = info();
    onPurchase = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'logIn':
          return {'customerInfo': storeInfo, 'created': false};
        case 'getCustomerInfo':
          return storeInfo;
        case 'restorePurchases':
          return restoredInfo;
        case 'syncAttributesAndOfferingsIfNeeded':
          return offerings();
        case 'purchasePackage':
          final productId = jsonProductId(call.arguments);
          purchased.add(productId);
          if (onPurchase != null) return onPurchase!(productId);
          throw storeError(PurchasesErrorCode.purchaseCancelledError);
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

  test('a second tap while the first purchase is open is refused', () async {
    await cubit.loginUser('fixture-user');
    final gate = Completer<Object?>();
    onPurchase = (_) => gate.future;
    final first = cubit.purchase(monthly);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final second = await cubit.purchase(threeMonth);
    gate.completeError(storeError(PurchasesErrorCode.purchaseCancelledError));
    await first;
    expect(second, isFalse);
    expect(purchased, ['silarah_monthly']);
    expect(cubit.state.isLoading, isFalse);
  });

  test('a pending payment blocks the other plan, even after a restore',
      () async {
    await cubit.loginUser('fixture-user');
    onPurchase =
        (_) => throw storeError(PurchasesErrorCode.paymentPendingError);
    await cubit.purchase(monthly);
    expect(cubit.state.successMessage, contains('pending'));
    expect(cubit.state.isLoading, isFalse);

    await cubit.restore();
    // "No purchases found" would invite paying again.
    expect(cubit.state.error, contains('still pending'));
    purchased.clear();
    expect(await cubit.purchase(threeMonth), isFalse);
    expect(purchased, isEmpty);
    expect(cubit.state.error, contains('still pending'));
    expect(cubit.state.error, contains('avoid paying twice'));

    // Play itself refuses a duplicate of the same plan.
    await cubit.purchase(monthly);
    expect(purchased, ['silarah_monthly']);
  });

  test('a dropped connection after the store opened is not called a failure',
      () async {
    await cubit.loginUser('fixture-user');
    onPurchase = (_) => throw storeError(PurchasesErrorCode.networkError);
    await cubit.purchase(threeMonth);
    expect(cubit.state.error, contains('If you were charged'));
    expect(cubit.state.error, contains('rather than paying again'));
    expect(cubit.state.isLoading, isFalse);

    purchased.clear();
    expect(await cubit.purchase(monthly), isFalse);
    expect(purchased, isEmpty);

    // A restore re-sends every Play purchase; finding none settles it.
    await cubit.restore();
    await cubit.purchase(monthly);
    expect(purchased, ['silarah_monthly']);
  });

  test('a lost payment that restore recovers unlocks Premium', () async {
    await cubit.loginUser('fixture-user');
    onPurchase = (_) => throw storeError(PurchasesErrorCode.networkError);
    await cubit.purchase(monthly);
    storeInfo = info(entitlement: premium(active: true));
    restoredInfo = storeInfo;
    await cubit.restore();
    expect(cubit.state.hasPaidPremium, isTrue);
    expect(await UnconfirmedPurchaseMemory.plan('fixture-user'), isNull);
  });

  test('a connection failure before the store opens blocks nothing', () async {
    await cubit.loginUser('fixture-user');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCustomerInfo') {
        throw storeError(PurchasesErrorCode.networkError);
      }
      if (call.method == 'syncAttributesAndOfferingsIfNeeded') {
        return offerings();
      }
      if (call.method == 'purchasePackage') purchased.add('opened');
      return null;
    });
    await cubit.purchase(monthly);
    expect(purchased, isEmpty);
    expect(cubit.state.error, contains('Check your internet and try again'));
    expect(await UnconfirmedPurchaseMemory.plan('fixture-user'), isNull);
  });

  test('account hold sends the member to fix payment, not to buy again',
      () async {
    final expired =
        DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
    storeInfo = info(
      entitlement: premium(
        active: false,
        billingIssueDetectedAt: expired,
        expirationDate: expired,
      ),
    );
    await cubit.loginUser('fixture-user');
    expect(await cubit.purchase(threeMonth), isFalse);
    expect(purchased, isEmpty);
    expect(cubit.state.error, contains('Update your payment method'));
    expect(cubit.state.isLoading, isFalse);
  });

  test('an active subscription is found live before charging', () async {
    await cubit.loginUser('fixture-user');
    storeInfo = info(entitlement: premium(active: true));
    expect(await cubit.purchase(threeMonth), isTrue);
    expect(purchased, isEmpty);
  });

  group('account hold detection', () {
    final now = DateTime.utc(2026, 11, 1);
    String daysAgo(int days) =>
        now.subtract(Duration(days: days)).toIso8601String();
    CustomerInfo held({
      int expiredDaysAgo = 5,
      String? unsubscribed,
    }) =>
        CustomerInfo.fromJson(info(
          entitlement: premium(
            active: false,
            // RevenueCat reports false whenever a billing issue exists.
            willRenew: false,
            billingIssueDetectedAt: daysAgo(expiredDaysAgo),
            unsubscribeDetectedAt: unsubscribed,
            expirationDate: daysAgo(expiredDaysAgo),
          ),
        ));

    test('holds while the subscription can still recover', () {
      expect(
          SubscriptionEntitlements.isOnAccountHold(held(), now: now), isTrue);
    });

    test('a lapsed or cancelled subscription can be bought again', () {
      expect(
          SubscriptionEntitlements.isOnAccountHold(held(expiredDaysAgo: 61),
              now: now),
          isFalse);
      expect(
          SubscriptionEntitlements.isOnAccountHold(
              held(unsubscribed: daysAgo(1)),
              now: now),
          isFalse);
    });
  });

  test('an unconfirmed payment stops blocking after 72 hours', () async {
    final start = DateTime.utc(2026, 11, 1);
    await UnconfirmedPurchaseMemory.remember(
        'fixture-user', SubscriptionPlan.monthly,
        pending: true, now: start);
    expect(
        await UnconfirmedPurchaseMemory.plan('fixture-user',
            now: start.add(const Duration(hours: 71))),
        SubscriptionPlan.monthly);
    expect(
        await UnconfirmedPurchaseMemory.plan('fixture-user',
            now: start.add(const Duration(hours: 73))),
        isNull);
    expect(
        await UnconfirmedPurchaseMemory.plan('other-user', now: start), isNull);
  });
}

String jsonProductId(Object? arguments) {
  final args = Map<String, dynamic>.from(arguments as Map);
  return (args['packageIdentifier'] ?? args['productIdentifier'] ?? '')
      .toString();
}

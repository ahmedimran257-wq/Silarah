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

// Every way a purchase can end must leave no spinner, say something true,
// and never let a second subscription start on top of an unsettled one.

const monthly = SubscriptionCubit.monthlyProductId;
const threeMonth = SubscriptionCubit.threeMonthProductId;

Map<String, dynamic> info({bool premium = false}) {
  final entitlement = {
    'identifier': 'premium',
    'isActive': true,
    'willRenew': true,
    'latestPurchaseDate': '2026-01-01T00:00:00Z',
    'originalPurchaseDate': '2026-01-01T00:00:00Z',
    'productIdentifier': 'silarah_monthly',
    'isSandbox': true,
    'expirationDate': '2036-01-01T00:00:00Z',
  };
  final entitlements = {if (premium) 'premium': entitlement};
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

Map<String, dynamic> purchaseResult({required bool premium}) => {
      'customerInfo': info(premium: premium),
      'transaction': {
        'transactionIdentifier': 'synthetic-transaction',
        'productIdentifier': 'silarah_monthly',
        'purchaseDate': '2026-09-27T00:00:00Z',
      },
    };

PlatformException storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: 'synthetic ${code.name}');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  late SupabaseClient client;
  late SubscriptionCubit cubit;
  PlatformException? restoreError;
  late List<String> charged;
  late bool storePremium;
  late bool loginFails;
  late String serverGrant;
  late bool serverDown;
  Future<Object?> Function()? onPurchase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    charged = [];
    storePremium = false;
    loginFails = false;
    serverDown = false;
    serverGrant = '[{"is_active":false,"source":"none","expires_at":null}]';
    onPurchase = null;
    restoreError = null;
    client = SupabaseClient('https://billing.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('get_my_premium_entitlement')) {
        if (serverDown) {
          return http.Response('{"message":"down"}', 503, request: request);
        }
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
          if (loginFails) {
            throw storeError(PurchasesErrorCode.networkError);
          }
          return {
            'customerInfo': info(premium: storePremium),
            'created': false
          };
        case 'restorePurchases':
          if (restoreError != null) throw restoreError!;
          return info(premium: storePremium);
        case 'getCustomerInfo':
          return info(premium: storePremium);
        case 'syncAttributesAndOfferingsIfNeeded':
          return offerings();
        case 'purchasePackage':
          charged.add((call.arguments as Map)['packageIdentifier'] as String);
          if (onPurchase != null) return onPurchase!();
          return purchaseResult(premium: true);
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

  group('every store error after the payment sheet opens', () {
    for (final code in PurchasesErrorCode.values) {
      test('${code.name}: no spinner, a true message', () async {
        await cubit.loginUser('fixture-user');
        onPurchase = () => throw storeError(code);
        expect(await cubit.purchase(monthly), isFalse);
        final state = cubit.state;
        expect(state.isLoading, isFalse);
        expect(state.isSubscribed, isFalse);
        switch (code) {
          case PurchasesErrorCode.purchaseCancelledError:
            expect(state.error, isNull);
            expect(state.successMessage, isNull);
          case PurchasesErrorCode.paymentPendingError:
            expect(state.successMessage, contains('pending'));
          default:
            expect(state.error, isNotNull);
        }
        if (unconfirmedPurchaseErrorCodes.contains(code)) {
          // Play may have charged; never say it failed or invite a retry.
          expect(state.error, contains('If you were charged'));
        }
      });
    }
  });

  test('an unrecognised store error after the sheet opens is not a failure',
      () async {
    await cubit.loginUser('fixture-user');
    onPurchase =
        () => throw PlatformException(code: 'UNEXPECTED', message: 'synthetic');
    expect(await cubit.purchase(monthly), isFalse);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, contains('If you were charged'));
    // And the other plan waits until it settles.
    charged.clear();
    expect(await cubit.purchase(threeMonth), isFalse);
    expect(charged, isEmpty);
  });

  test('already owned and active: Premium on, no second charge', () async {
    await cubit.loginUser('fixture-user');
    onPurchase = () {
      storePremium = true;
      throw storeError(PurchasesErrorCode.productAlreadyPurchasedError);
    };
    expect(await cubit.purchase(monthly), isTrue);
    expect(cubit.state.hasPaidPremium, isTrue);
    expect(cubit.state.successMessage, contains('existing'));
  });

  test('already owned but not yet visible: points to Restore', () async {
    await cubit.loginUser('fixture-user');
    onPurchase =
        () => throw storeError(PurchasesErrorCode.productAlreadyPurchasedError);
    expect(await cubit.purchase(monthly), isFalse);
    expect(cubit.state.error, contains('Restore Purchase'));
    expect(cubit.state.isLoading, isFalse);
  });

  test('charged but Premium not granted yet: told so, other plan waits',
      () async {
    await cubit.loginUser('fixture-user');
    onPurchase = () async => purchaseResult(premium: false);
    expect(await cubit.purchase(monthly), isFalse);
    expect(cubit.state.successMessage, contains('accepted the purchase'));
    charged.clear();
    expect(await cubit.purchase(threeMonth), isFalse);
    expect(charged, isEmpty);
  });

  test('a pending payment that completes unlocks Premium without a charge',
      () async {
    await cubit.loginUser('fixture-user');
    onPurchase = () => throw storeError(PurchasesErrorCode.paymentPendingError);
    await cubit.purchase(monthly);
    storePremium = true; // Google Play confirmed it later.
    charged.clear();
    expect(await cubit.purchase(threeMonth), isTrue);
    expect(charged, isEmpty);
    expect(await UnconfirmedPurchaseMemory.plan('fixture-user'), isNull);
  });

  test("one account's pending payment does not block another account",
      () async {
    await cubit.loginUser('first-user');
    onPurchase = () => throw storeError(PurchasesErrorCode.paymentPendingError);
    await cubit.purchase(monthly);
    await cubit.logoutUser();
    await cubit.loginUser('second-user');
    onPurchase = null;
    charged.clear();
    expect(await cubit.purchase(threeMonth), isTrue);
    expect(charged, ['silarah_three_month']);
  });

  test('a successful purchase still unlocks Premium when the server is down',
      () async {
    await cubit.loginUser('fixture-user');
    serverDown = true;
    expect(await cubit.purchase(monthly), isTrue);
    expect(cubit.state.hasPaidPremium, isTrue);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.successMessage, contains('Premium is now active'));
  });

  test('Premium the server already knows blocks buying again', () async {
    serverGrant = '[{"is_active":true,"source":"paid",'
        '"expires_at":"2036-01-01T00:00:00Z"}]';
    await cubit.loginUser('fixture-user');
    expect(await cubit.purchase(threeMonth), isFalse);
    expect(charged, isEmpty);
    expect(cubit.state.error, contains('already active'));
  });

  test('free referral Premium cannot be overpaid', () async {
    serverGrant = '[{"is_active":true,"source":"referral",'
        '"expires_at":"2036-01-01T00:00:00Z"}]';
    await cubit.loginUser('fixture-user');
    expect(await cubit.purchase(monthly), isFalse);
    expect(charged, isEmpty);
    expect(cubit.state.error, contains('referral'));
    expect(cubit.state.isLoading, isFalse);
  });

  test('no store sign-in: the payment sheet never opens', () async {
    loginFails = true;
    await cubit.loginUser('fixture-user');
    expect(await cubit.purchase(monthly), isFalse);
    expect(charged, isEmpty);
    expect(cubit.state.error, contains('Check your internet'));
    expect(cubit.state.isLoading, isFalse);
  });

  test('restore finds nothing: no Premium and nothing charged', () async {
    await cubit.loginUser('fixture-user');
    await cubit.restore();
    expect(cubit.state.isSubscribed, isFalse);
    expect(cubit.state.hasPaidPremium, isFalse);
    expect(charged, isEmpty);
    expect(cubit.state.error, contains('No previous purchases'));
  });

  test('restore of a purchase owned by another account grants nothing',
      () async {
    await cubit.loginUser('fixture-user');
    restoreError = storeError(PurchasesErrorCode.receiptAlreadyInUseError);
    await cubit.restore();
    expect(cubit.state.isSubscribed, isFalse);
    expect(cubit.state.error, contains('another Silarah account'));
  });

  test('restore that fails for any other reason asks to retry', () async {
    await cubit.loginUser('fixture-user');
    restoreError = storeError(PurchasesErrorCode.networkError);
    await cubit.restore();
    expect(cubit.state.isSubscribed, isFalse);
    expect(cubit.state.error, 'Restore failed. Please try again.');
  });

  test('restore while a purchase is open waits its turn', () async {
    await cubit.loginUser('fixture-user');
    final gate = Completer<Object?>();
    onPurchase = () => gate.future;
    final purchase = cubit.purchase(monthly);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final restore = cubit.restore();
    storePremium = true;
    gate.complete(purchaseResult(premium: true));
    expect(await purchase, isTrue);
    await restore;
    expect(charged, ['silarah_monthly']);
    expect(cubit.state.hasPaidPremium, isTrue);
    expect(cubit.state.isLoading, isFalse);
  });
}

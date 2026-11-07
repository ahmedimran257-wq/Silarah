import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/subscription/subscription_cubit.dart';
import 'package:silarah/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// RevenueCat's SDK keeps a cached copy for minutes (and up to days offline)
// in which an entitlement can still read as active after its expiry date.
// The expiry refresh used to re-fire every 250 ms for that whole time, each
// one asking the server for the member's Premium grant.

var expiresAt = DateTime.now();

Map<String, dynamic> staleActiveInfo() {
  final expired = expiresAt.toIso8601String();
  final premium = {
    'identifier': 'premium',
    'isActive': true,
    'willRenew': true,
    'latestPurchaseDate': '2026-01-01T00:00:00Z',
    'originalPurchaseDate': '2026-01-01T00:00:00Z',
    'productIdentifier': 'silarah_monthly',
    'isSandbox': true,
    'expirationDate': expired,
  };
  return {
    'originalAppUserId': 'fixture-user',
    'entitlements': {
      'all': {'premium': premium},
      'active': {'premium': premium},
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  late SupabaseClient client;
  late SubscriptionCubit cubit;
  var serverReads = 0;
  var cacheInvalidations = 0;

  setUp(() {
    serverReads = 0;
    cacheInvalidations = 0;
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient('https://billing.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('get_my_premium_entitlement')) {
        serverReads++;
        return http.Response(
            '[{"is_active":false,"source":"none","expires_at":null}]', 200,
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
          return {'customerInfo': staleActiveInfo(), 'created': false};
        case 'getCustomerInfo':
          return staleActiveInfo();
        case 'invalidateCustomerInfoCache':
          cacheInvalidations++;
          return null;
        case 'syncAttributesAndOfferingsIfNeeded':
          return {'all': {}, 'current': null};
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

  test('at the expiry moment the store is asked fresh, once', () async {
    expiresAt = DateTime.now().add(const Duration(milliseconds: 300));
    await cubit.loginUser('fixture-user');
    final readsAfterLogin = serverReads;
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    expect(cacheInvalidations, 1);
    expect(serverReads - readsAfterLogin, 1);
  });

  test('a stale store copy past its expiry does not loop server reads',
      () async {
    expiresAt = DateTime.now().subtract(const Duration(minutes: 1));
    await cubit.loginUser('fixture-user');
    final readsAfterLogin = serverReads;
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    // One prompt re-check at expiry, then a calm retry interval.
    expect(serverReads - readsAfterLogin, lessThanOrEqualTo(1));
    expect(cacheInvalidations, lessThanOrEqualTo(1));
  });
}

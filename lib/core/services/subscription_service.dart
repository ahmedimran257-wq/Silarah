// SILARAH - RevenueCat Subscription Service
// Pricing comes from RevenueCat, with country/tier offering selection.
// No hardcoded prices.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'my_account_snapshot.dart';
import 'supabase_service.dart';

class DisplayPricing {
  const DisplayPricing({
    required this.monthlyPrice,
    required this.threeMonthPrice,
    required this.savingsPercent,
    required this.source,
    this.countryCode,
    this.pricingTier,
    this.offeringId,
  });

  final String monthlyPrice;
  final String threeMonthPrice;
  final int savingsPercent;
  final PricingSource source;
  final String? countryCode;
  final String? pricingTier;
  final String? offeringId;

  factory DisplayPricing.fromPackages({
    required Package monthlyPackage,
    required Package threeMonthPackage,
    String? countryCode,
    String? pricingTier,
    String? offeringId,
  }) {
    final monthlyProduct = monthlyPackage.storeProduct;
    final threeMonthProduct = threeMonthPackage.storeProduct;
    final threeMonthlyPayments = monthlyProduct.price * 3;
    final savings = threeMonthlyPayments > 0
        ? ((1 - (threeMonthProduct.price / threeMonthlyPayments)) * 100).round()
        : 0;

    return DisplayPricing(
      monthlyPrice: wholePriceLabel(monthlyProduct.priceString),
      threeMonthPrice: wholePriceLabel(threeMonthProduct.priceString),
      savingsPercent: savings,
      source: PricingSource.revenueCat,
      countryCode: countryCode,
      pricingTier: pricingTier,
      offeringId: offeringId,
    );
  }

  factory DisplayPricing.unavailable() => const DisplayPricing(
        monthlyPrice: '',
        threeMonthPrice: '',
        savingsPercent: 0,
        source: PricingSource.unavailable,
      );

  factory DisplayPricing.loading() => const DisplayPricing(
        monthlyPrice: '',
        threeMonthPrice: '',
        savingsPercent: 0,
        source: PricingSource.loading,
      );

  bool get isAvailable => source == PricingSource.revenueCat;
}

enum PricingSource { loading, revenueCat, unavailable }

enum SubscriptionPlan { monthly, threeMonth }

/// Store outcomes that need materially different product behavior.
///
/// A cancellation is intentionally silent, a pending payment must not unlock
/// Premium, and a completed store transaction without the expected entitlement
/// must never be reported as a failed charge.
enum SubscriptionPurchaseOutcome {
  purchased,
  cancelled,
  pending,
  alreadyPurchased,
  entitlementPending,

  /// The store sheet opened but the result never arrived (connection lost).
  /// Google Play may have charged; RevenueCat posts it when back online.
  unconfirmed,

  /// An earlier payment for the other plan is pending or unconfirmed, so
  /// buying this plan could start a second subscription.
  otherPlanUnconfirmed,

  /// The Premium subscription is on account hold. Fixing the payment in
  /// Google Play restores it; buying again would charge twice.
  billingIssue,
  failed,
}

class SubscriptionPurchaseResult {
  const SubscriptionPurchaseResult({
    required this.outcome,
    this.customerInfo,
    this.errorCode,
  });

  final SubscriptionPurchaseOutcome outcome;
  final CustomerInfo? customerInfo;
  final PurchasesErrorCode? errorCode;
}

SubscriptionPurchaseOutcome classifySubscriptionPurchaseError(
  PurchasesErrorCode code,
) {
  return switch (code) {
    PurchasesErrorCode.purchaseCancelledError =>
      SubscriptionPurchaseOutcome.cancelled,
    PurchasesErrorCode.paymentPendingError =>
      SubscriptionPurchaseOutcome.pending,
    PurchasesErrorCode.productAlreadyPurchasedError =>
      SubscriptionPurchaseOutcome.alreadyPurchased,
    _ => SubscriptionPurchaseOutcome.failed,
  };
}

/// RevenueCat's helper parses the code as a number and throws on anything
/// else. Thrown inside a catch, that escaped as a generic "purchase failed"
/// even after the payment sheet had opened, when Play may have charged.
PurchasesErrorCode storeErrorCode(PlatformException error) {
  try {
    return PurchasesErrorHelper.getErrorCode(error);
  } on FormatException {
    return PurchasesErrorCode.unknownError;
  }
}

/// Canonical RevenueCat entitlement mapping.
abstract final class SubscriptionEntitlements {
  static const String premium = 'premium';

  static EntitlementInfo? activePremium(CustomerInfo info) {
    return info.entitlements.active[premium];
  }

  static bool isPremiumActive(CustomerInfo info) {
    return activePremium(info) != null;
  }

  /// Google Play account hold: the renewal payment failed, access is paused,
  /// and the subscription still recovers if the member fixes the payment.
  /// Bounded by Play's longest hold so a lapsed member can always buy again.
  static bool isOnAccountHold(CustomerInfo info, {DateTime? now}) {
    final premium = info.entitlements.all[SubscriptionEntitlements.premium];
    if (premium == null ||
        premium.isActive ||
        premium.billingIssueDetectedAt == null ||
        premium.unsubscribeDetectedAt != null) {
      return false;
    }
    final expiry = DateTime.tryParse(premium.expirationDate ?? '');
    if (expiry == null) return false;
    return (now ?? DateTime.now()).difference(expiry) <
        const Duration(days: 60);
  }
}

/// RevenueCat error codes that can follow a completed Google Play charge
/// whose receipt never reached RevenueCat.
const unconfirmedPurchaseErrorCodes = {
  PurchasesErrorCode.networkError,
  PurchasesErrorCode.offlineConnectionError,
  PurchasesErrorCode.unknownError,
  PurchasesErrorCode.unknownBackendError,
  PurchasesErrorCode.unexpectedBackendResponseError,
};

/// Remembers, per account, a payment that is pending or whose result was
/// lost, so the other plan cannot be bought on top of it. Monthly and
/// 3-month are separate Play subscriptions; Play only blocks re-buying the
/// same one.
class UnconfirmedPurchaseMemory {
  UnconfirmedPurchaseMemory._();

  /// Long enough for Play's slow payment methods to settle and for its
  /// three-day refund of a purchase RevenueCat never acknowledged.
  static const window = Duration(hours: 72);

  static String _key(String userId) => 'subscription_unconfirmed_$userId';

  static Future<void> remember(
    String userId,
    SubscriptionPlan plan, {
    required bool pending,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await prefs.setString(
        _key(userId), '${plan.name}|$at|${pending ? 'pending' : 'lost'}');
  }

  /// The plan of a fresh unconfirmed payment, if any.
  static Future<SubscriptionPlan?> plan(String userId, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final parts = prefs.getString(_key(userId))?.split('|');
    if (parts == null || parts.length != 3) return null;
    final at = int.tryParse(parts[1]);
    if (at == null) return null;
    final age = (now ?? DateTime.now())
        .difference(DateTime.fromMillisecondsSinceEpoch(at));
    if (age > window) return null;
    for (final plan in SubscriptionPlan.values) {
      if (plan.name == parts[0]) return plan;
    }
    return null;
  }

  /// Whether the fresh unconfirmed payment is one Play holds as pending
  /// (a restore cannot settle it), rather than a lost result.
  static Future<bool> isPending(String userId, {DateTime? now}) async {
    if (await plan(userId, now: now) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(userId))?.endsWith('|pending') ?? false;
  }

  /// Premium became active, or a restore found nothing (which settles a lost
  /// result but not a payment Play still holds as pending).
  static Future<void> clear(String userId, {bool keepPending = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (keepPending &&
        (prefs.getString(_key(userId))?.endsWith('|pending') ?? false)) {
      return;
    }
    await prefs.remove(_key(userId));
  }
}

class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  final _pricingController = StreamController<DisplayPricing>.broadcast();

  Stream<DisplayPricing> get pricingStream => _pricingController.stream;

  DisplayPricing? _currentPricing;
  DisplayPricing? get currentPricing => _currentPricing;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  Timer? _retryTimer;
  int _retryCount = 0;
  static const _maxRetries = 3;
  static const _retryInterval = Duration(seconds: 30);

  String? _countryCode;
  String? _pricingTier;
  Offering? _activeOffering;
  int _sessionGeneration = 0;
  String? _userId;

  Future<void> initialize({required String userId}) async {
    final generation = _sessionGeneration;
    _userId = userId;
    try {
      _retryTimer?.cancel();
      _retryCount = 0;
      await _syncSubscriberAttributes(userId, generation);
      if (generation != _sessionGeneration) return;
      await _refreshPricing();
    } catch (e) {
      debugPrint('[SubscriptionService] RevenueCat init error: $e');
      if (generation != _sessionGeneration) return;
      _setPricingUnavailable();
      _scheduleRetry();
    }
  }

  Future<void> retryPricing() async {
    _retryCount = 0;
    await _refreshPricing();
  }

  Future<SubscriptionPurchaseResult> purchase({
    required SubscriptionPlan plan,
  }) async {
    final generation = _sessionGeneration;
    final userId = _userId;
    var storeOpened = false;
    try {
      Offering? offering = _activeOffering;
      if (offering == null) {
        final offerings = await Purchases.syncAttributesAndOfferingsIfNeeded();
        if (generation != _sessionGeneration) {
          return const SubscriptionPurchaseResult(
              outcome: SubscriptionPurchaseOutcome.failed);
        }
        offering = _selectOffering(offerings);
      }
      if (offering == null) throw Exception('No offerings available');

      final package = switch (plan) {
        SubscriptionPlan.monthly => offering.monthly,
        SubscriptionPlan.threeMonth => offering.threeMonth,
      };
      if (package == null) throw Exception('Package not available');

      // Monthly and 3-month are separate Play subscriptions: buying one while
      // the other is active starts a second subscription and charges twice.
      // The paywall hides plans from subscribers, but its state can be stale
      // (offline start, purchase on another device), so ask the store live.
      // The SDK cache can be minutes old; a purchase made elsewhere since
      // then must count.
      await Purchases.invalidateCustomerInfoCache();
      final current = await Purchases.getCustomerInfo();
      if (generation != _sessionGeneration) {
        return const SubscriptionPurchaseResult(
            outcome: SubscriptionPurchaseOutcome.failed);
      }
      if (SubscriptionEntitlements.isPremiumActive(current)) {
        _customerInfo = current;
        _isSubscribed = true;
        if (userId != null) await UnconfirmedPurchaseMemory.clear(userId);
        return SubscriptionPurchaseResult(
          outcome: SubscriptionPurchaseOutcome.alreadyPurchased,
          customerInfo: current,
        );
      }
      if (SubscriptionEntitlements.isOnAccountHold(current)) {
        _customerInfo = current;
        return SubscriptionPurchaseResult(
          outcome: SubscriptionPurchaseOutcome.billingIssue,
          customerInfo: current,
        );
      }
      // A pending or lost payment is invisible to RevenueCat until Play
      // settles it.
      final unconfirmedPlan =
          userId == null ? null : await UnconfirmedPurchaseMemory.plan(userId);
      if (generation != _sessionGeneration) {
        return const SubscriptionPurchaseResult(
            outcome: SubscriptionPurchaseOutcome.failed);
      }
      if (unconfirmedPlan != null && unconfirmedPlan != plan) {
        final pending = await UnconfirmedPurchaseMemory.isPending(userId!);
        return SubscriptionPurchaseResult(
          outcome: SubscriptionPurchaseOutcome.otherPlanUnconfirmed,
          errorCode: pending ? PurchasesErrorCode.paymentPendingError : null,
        );
      }

      storeOpened = true;
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      if (generation != _sessionGeneration) {
        return const SubscriptionPurchaseResult(
            outcome: SubscriptionPurchaseOutcome.failed);
      }
      final customerInfo = result.customerInfo;
      _isSubscribed = SubscriptionEntitlements.isPremiumActive(customerInfo);
      _customerInfo = customerInfo;
      if (userId != null) {
        if (_isSubscribed) {
          await UnconfirmedPurchaseMemory.clear(userId);
        } else {
          // Charged, but RevenueCat has not granted Premium yet.
          await UnconfirmedPurchaseMemory.remember(userId, plan, pending: true);
        }
      }
      return SubscriptionPurchaseResult(
        outcome: _isSubscribed
            ? SubscriptionPurchaseOutcome.purchased
            : SubscriptionPurchaseOutcome.entitlementPending,
        customerInfo: customerInfo,
      );
    } on PlatformException catch (error) {
      if (generation != _sessionGeneration) {
        return const SubscriptionPurchaseResult(
            outcome: SubscriptionPurchaseOutcome.failed);
      }
      final code = storeErrorCode(error);
      var outcome = classifySubscriptionPurchaseError(code);
      if (storeOpened &&
          outcome == SubscriptionPurchaseOutcome.failed &&
          unconfirmedPurchaseErrorCodes.contains(code)) {
        outcome = SubscriptionPurchaseOutcome.unconfirmed;
      }
      if (userId != null &&
          (outcome == SubscriptionPurchaseOutcome.pending ||
              outcome == SubscriptionPurchaseOutcome.unconfirmed)) {
        await UnconfirmedPurchaseMemory.remember(userId, plan,
            pending: outcome == SubscriptionPurchaseOutcome.pending);
      }
      CustomerInfo? customerInfo;
      if (outcome == SubscriptionPurchaseOutcome.alreadyPurchased) {
        try {
          customerInfo = await Purchases.getCustomerInfo();
          if (generation != _sessionGeneration) {
            return const SubscriptionPurchaseResult(
                outcome: SubscriptionPurchaseOutcome.failed);
          }
          _customerInfo = customerInfo;
          _isSubscribed =
              SubscriptionEntitlements.isPremiumActive(customerInfo);
          if (_isSubscribed && userId != null) {
            await UnconfirmedPurchaseMemory.clear(userId);
          }
        } catch (refreshError) {
          debugPrint(
            '[SubscriptionService] Existing purchase refresh error: '
            '$refreshError',
          );
        }
      }
      debugPrint('[SubscriptionService] Purchase error ($code): $error');
      return SubscriptionPurchaseResult(
        outcome: outcome,
        customerInfo: customerInfo,
        errorCode: code,
      );
    } catch (error) {
      debugPrint('[SubscriptionService] Purchase error: $error');
      if (!storeOpened || generation != _sessionGeneration) {
        return const SubscriptionPurchaseResult(
          outcome: SubscriptionPurchaseOutcome.failed,
        );
      }
      if (userId != null) {
        await UnconfirmedPurchaseMemory.remember(userId, plan, pending: false);
      }
      return const SubscriptionPurchaseResult(
        outcome: SubscriptionPurchaseOutcome.unconfirmed,
      );
    }
  }

  Future<bool> restorePurchases() async {
    final generation = _sessionGeneration;
    final userId = _userId;
    try {
      final info = await Purchases.restorePurchases();
      if (generation != _sessionGeneration) return false;
      _customerInfo = info;
      _isSubscribed = SubscriptionEntitlements.isPremiumActive(info);
      // A restore re-sends every Play purchase, so a lost result is settled
      // either way. A payment Play still holds as pending is not included.
      if (userId != null) {
        await UnconfirmedPurchaseMemory.clear(userId,
            keepPending: !_isSubscribed);
      }
      return _isSubscribed;
    } catch (e) {
      debugPrint('[SubscriptionService] Restore error: $e');
      rethrow;
    }
  }

  void dispose() {
    clearUser();
    _pricingController.close();
  }

  /// Clears all user-derived pricing and entitlement snapshots on account
  /// change. RevenueCat identity ownership remains in SubscriptionCubit.
  void clearUser() {
    _sessionGeneration++;
    _retryTimer?.cancel();
    _retryCount = 0;
    _countryCode = null;
    _pricingTier = null;
    _userId = null;
    _activeOffering = null;
    _customerInfo = null;
    _isSubscribed = false;
    _currentPricing = null;
  }

  Future<void> _refreshPricing() async {
    final generation = _sessionGeneration;
    try {
      final offerings = await Purchases.syncAttributesAndOfferingsIfNeeded();
      if (generation != _sessionGeneration) return;
      final offering = _selectOffering(offerings);
      if (offering == null) {
        debugPrint('[SubscriptionService] No offering configured.');
        _setPricingUnavailable();
        _scheduleRetry();
        return;
      }
      _activeOffering = offering;

      final monthlyPackage = offering.monthly;
      final threeMonthPackage = offering.threeMonth;
      if (monthlyPackage == null || threeMonthPackage == null) {
        debugPrint(
          '[SubscriptionService] Missing monthly/three-month package.',
        );
        _setPricingUnavailable();
        _scheduleRetry();
        return;
      }

      _currentPricing = DisplayPricing.fromPackages(
        monthlyPackage: monthlyPackage,
        threeMonthPackage: threeMonthPackage,
        countryCode: _countryCode,
        pricingTier: _pricingTier,
        offeringId: offering.identifier,
      );
      _pricingController.add(_currentPricing!);

      _retryTimer?.cancel();
      _retryCount = 0;

      debugPrint(
        '[SubscriptionService] Pricing loaded: '
        '${_currentPricing!.monthlyPrice}/mo, '
        '${_currentPricing!.threeMonthPrice}/3mo, '
        'offering=${offering.identifier}, '
        'country=${_countryCode ?? "store"}, '
        'tier=${_pricingTier ?? "default"}',
      );
    } catch (e) {
      debugPrint('[SubscriptionService] Offerings fetch error: $e');
      if (generation != _sessionGeneration) return;
      _setPricingUnavailable();
      _scheduleRetry();
    }
  }

  void _setPricingUnavailable() {
    _currentPricing = DisplayPricing.unavailable();
    _pricingController.add(_currentPricing!);
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    _retryCount++;
    _retryTimer = Timer(_retryInterval, _refreshPricing);
  }

  Offering? _selectOffering(Offerings offerings) {
    final country = _countryCode?.toLowerCase();
    final tier = _pricingTier?.toLowerCase();
    final candidates = <String>[
      if (country != null) 'country_$country',
      if (country != null) 'silarah_$country',
      if (country != null) country,
      if (tier != null) 'tier_$tier',
      if (tier != null) 'silarah_$tier',
      if (tier != null) tier,
    ];

    for (final id in candidates) {
      final offering = offerings.getOffering(id);
      if (offering != null) return offering;
    }
    return offerings.current;
  }

  Future<void> _syncSubscriberAttributes(String userId, int generation) async {
    final context = await _loadPricingContext(userId);
    if (generation != _sessionGeneration) return;
    _countryCode = context.countryCode;
    _pricingTier = context.pricingTier;

    final attributes = <String, String>{
      if (_countryCode != null) 'country_code': _countryCode!,
      if (_pricingTier != null) 'pricing_tier': _pricingTier!,
    };
    if (attributes.isNotEmpty) {
      await Purchases.setAttributes(attributes);
    }
    if (generation != _sessionGeneration) return;
    if (context.email != null && context.email!.isNotEmpty) {
      await Purchases.setEmail(context.email!);
    }
  }

  Future<_PricingContext> _loadPricingContext(String userId) async {
    String? countryCode;
    String? email;
    String? pricingTier;

    if (SupabaseService.isInitialized) {
      try {
        final user = await MyAccountSnapshot.instance.user(userId);
        countryCode = (user?['country_code'] as String?)?.toUpperCase();
        email = user?['email'] as String?;
      } catch (e) {
        debugPrint('[SubscriptionService] user context error: $e');
      }

      if (countryCode == null || countryCode.isEmpty) {
        try {
          final profile = await MyAccountSnapshot.instance.profile(userId);
          countryCode = (profile?['country_code'] as String?)?.toUpperCase();
        } catch (e) {
          debugPrint('[SubscriptionService] profile context error: $e');
        }
      }

      if (countryCode != null && countryCode.isNotEmpty) {
        pricingTier = await _loadPricingTier(countryCode);
      }
    }

    if (countryCode == null || countryCode.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      countryCode = prefs.getString('user_country_code')?.toUpperCase();
    }

    return _PricingContext(
      countryCode: countryCode,
      pricingTier: pricingTier,
      email: email,
    );
  }

  Future<String?> _loadPricingTier(String countryCode) async {
    try {
      final row = await SupabaseService.client
          .from('countries')
          .select('pricing_tier')
          .eq('iso_code', countryCode)
          .maybeSingle();
      return row?['pricing_tier'] as String?;
    } catch (e) {
      debugPrint('[SubscriptionService] pricing tier lookup error: $e');
      return null;
    }
  }
}

class _PricingContext {
  const _PricingContext({
    this.countryCode,
    this.pricingTier,
    this.email,
  });

  final String? countryCode;
  final String? pricingTier;
  final String? email;
}

/// Google Play formats ₹299 as "₹299.00". Drop zero minor units so whole
/// prices read as "₹299"; any real paise ("₹299.50") is kept as-is.
String wholePriceLabel(String storePrice) =>
    storePrice.replaceFirst(RegExp(r'([.,])00(?!\d)'), '');

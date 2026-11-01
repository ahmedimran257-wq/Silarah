// SILARAH - Subscription Cubit
// Production RevenueCat flow only.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/my_account_snapshot.dart';
import '../../services/subscription_service.dart';
import '../../services/supabase_service.dart';
import 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit() : super(const SubscriptionState());

  static const monthlyProductId = 'silarah_monthly';
  static const threeMonthProductId = 'silarah_three_month';

  StreamSubscription<DisplayPricing>? _pricingSub;
  int _entitlementRefreshId = 0;
  CustomerInfoUpdateListener? _customerInfoListener;
  Timer? _expiryTimer;
  Future<void> _identityInFlight = Future<void>.value();
  int _sessionGeneration = 0;
  String? _loggedInUserId;
  bool _storeIdentityReady = false;
  bool _purchaseRequested = false;

  Future<void> initialize() async {
    if (isClosed || _pricingSub != null) return;
    emit(state.copyWith(isLoading: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return;
    }

    _pricingSub = SubscriptionService.instance.pricingStream.listen((_) {
      if (!isClosed) emit(state.copyWith(isLoading: false));
    });

    if (!isClosed) emit(state.copyWith(isLoading: false));
  }

  Future<void> loginUser(String userId) async {
    if (!SupabaseService.isInitialized || isClosed) return;
    clear();
    final generation = _sessionGeneration;
    _loggedInUserId = userId;
    emit(state.copyWith(isLoading: true));

    // The native SDK has one identity. Keep login/logout ordered even when
    // an account changes while a previous native request is still pending.
    await _withStoreIdentity(() => _loginUser(userId, generation));
  }

  Future<T> _withStoreIdentity<T>(Future<T> Function() operation) {
    final pending = _identityInFlight.then((_) => operation());
    _identityInFlight =
        pending.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      debugPrint('[SubscriptionCubit] Store operation error: $error');
    });
    return pending;
  }

  bool _isCurrentSession(int generation) =>
      !isClosed && generation == _sessionGeneration && _loggedInUserId != null;

  Future<void> _loginUser(String userId, int generation) async {
    if (!_isCurrentSession(generation)) return;

    CustomerInfo? customerInfo;
    try {
      await Purchases.logIn(userId);
      if (!_isCurrentSession(generation)) return;
      _storeIdentityReady = true;
      customerInfo = await Purchases.getCustomerInfo();
      if (!_isCurrentSession(generation)) return;

      await SubscriptionService.instance.initialize(userId: userId);
    } catch (e) {
      debugPrint('[SubscriptionCubit] RevenueCat login error: $e');
    }

    // Supabase is authoritative for promotional grants. This runs even when
    // RevenueCat is unavailable so a valid referral reward never shows a
    // paywall merely because the store SDK is offline.
    await _refreshEffectiveEntitlement(customerInfo,
        generation: generation, isLoading: false, allowRecent: true);

    if (_storeIdentityReady && _isCurrentSession(generation)) {
      _customerInfoListener = (_) {
        if (!_isCurrentSession(generation)) return;
        // Listener registration replays a cached native event, which may
        // belong to the previous account. Read the current SDK identity.
        // RevenueCat answers for store purchases, so the server's grant
        // read moments ago at login is still current.
        unawaited(refreshEntitlement(allowRecent: true));
      };
      Purchases.addCustomerInfoUpdateListener(_customerInfoListener!);
    }
  }

  Future<bool> purchase(String productId) async {
    // Purchases queue behind store identity work, so a second tap would run
    // after the first finished and see no loading state. Refuse it here.
    if (_purchaseRequested) return false;
    _purchaseRequested = true;
    final generation = _sessionGeneration;
    try {
      return await _withStoreIdentity(() => _purchase(productId, generation));
    } finally {
      _purchaseRequested = false;
    }
  }

  Future<bool> _purchase(String productId, int generation) async {
    if (!_isCurrentSession(generation)) return false;
    // A second tap while the store sheet is opening must not start another
    // purchase flow.
    if (state.isLoading) return false;
    if (state.hasPaidPremium) {
      emit(state.copyWith(
        error:
            'Your Premium subscription is already active. Manage or change plans in Google Play.',
      ));
      return false;
    }
    if (!_storeIdentityReady) {
      await _loginUser(_loggedInUserId!, generation);
      if (!_isCurrentSession(generation)) return false;
      if (!_storeIdentityReady) {
        emit(state.copyWith(
            isLoading: false,
            error: _purchaseErrorMessage(PurchasesErrorCode.networkError)));
        return false;
      }
    }
    if (state.isReferralOnly) {
      emit(state.copyWith(
        isLoading: false,
        error:
            'Your free referral Premium is active. Plans become available after it ends so no free time is wasted.',
      ));
      return false;
    }
    if (state.isTestOnly) {
      emit(state.copyWith(
        isLoading: false,
        error:
            'Test Premium is active on this device. Store purchases are disabled until the test grant ends or is revoked.',
      ));
      return false;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return false;
    }

    try {
      final plan = productId == threeMonthProductId
          ? SubscriptionPlan.threeMonth
          : SubscriptionPlan.monthly;
      final purchase = await SubscriptionService.instance.purchase(plan: plan);

      if (!_isCurrentSession(generation)) return false;

      if (purchase.outcome == SubscriptionPurchaseOutcome.purchased) {
        final info = purchase.customerInfo ?? await Purchases.getCustomerInfo();
        await _refreshEffectiveEntitlement(
          info,
          generation: generation,
          isLoading: false,
          successMessage: 'JazakAllah khair - Silarah Premium is now active!',
        );
        return _isCurrentSession(generation) && state.isSubscribed;
      }

      if (purchase.outcome == SubscriptionPurchaseOutcome.alreadyPurchased) {
        final info = purchase.customerInfo ?? await Purchases.getCustomerInfo();
        if (SubscriptionEntitlements.isPremiumActive(info)) {
          await _refreshEffectiveEntitlement(
            info,
            generation: generation,
            isLoading: false,
            successMessage:
                'Your existing Silarah Premium subscription is active.',
          );
          return _isCurrentSession(generation) && state.isSubscribed;
        }
        if (!_isCurrentSession(generation)) return false;
        emit(state.copyWith(
          isLoading: false,
          error:
              'Google Play reports this plan is already owned. Use Restore Purchase to refresh access.',
        ));
        return false;
      }

      if (purchase.outcome == SubscriptionPurchaseOutcome.cancelled) {
        emit(state.copyWith(
          isLoading: false,
          clearError: true,
          clearSuccess: true,
        ));
        return false;
      }

      if (purchase.outcome == SubscriptionPurchaseOutcome.pending) {
        emit(state.copyWith(
          isLoading: false,
          clearError: true,
          successMessage:
              'Payment is pending. Premium will activate automatically after Google Play confirms it.',
        ));
        return false;
      }

      if (purchase.outcome == SubscriptionPurchaseOutcome.entitlementPending) {
        emit(state.copyWith(
          isLoading: false,
          clearError: true,
          successMessage:
              'Google Play accepted the purchase. Premium is syncing now; use Restore Purchase if it does not appear shortly.',
        ));
        return false;
      }

      final message = switch (purchase.outcome) {
        SubscriptionPurchaseOutcome.unconfirmed =>
          'The connection dropped before Google Play confirmed. If you were charged, Premium switches on automatically once you are back online. Please tap Restore Purchase rather than paying again.',
        SubscriptionPurchaseOutcome.otherPlanUnconfirmed =>
          'Your last Google Play payment has not been confirmed yet. To avoid paying twice, wait for it to finish or tap Restore Purchase before choosing a different plan.',
        SubscriptionPurchaseOutcome.billingIssue =>
          'Your Premium renewal payment did not go through. Update your payment method in Google Play to restore Premium without paying twice.',
        _ => _purchaseErrorMessage(purchase.errorCode),
      };
      emit(state.copyWith(isLoading: false, error: message));
      return false;
    } catch (e) {
      debugPrint('[SubscriptionCubit] Purchase error: $e');
      if (_isCurrentSession(generation)) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Purchase failed. Please check your connection and try again.',
        ));
      }
      return false;
    }
  }

  String _purchaseErrorMessage(PurchasesErrorCode? code) {
    return switch (code) {
      PurchasesErrorCode.networkError =>
        'A secure connection could not be made. Check your internet and try again.',
      PurchasesErrorCode.storeProblemError =>
        'Google Play could not complete the request. No access was changed; please try again shortly.',
      PurchasesErrorCode.purchaseNotAllowedError ||
      PurchasesErrorCode.insufficientPermissionsError =>
        'Purchases are not available for this Google Play account or device.',
      PurchasesErrorCode.productNotAvailableForPurchaseError ||
      PurchasesErrorCode.configurationError ||
      PurchasesErrorCode.invalidCredentialsError =>
        'This plan is not available right now. Please contact Silarah Support.',
      PurchasesErrorCode.receiptAlreadyInUseError ||
      PurchasesErrorCode.receiptInUseByOtherSubscriberError =>
        'This Google Play subscription belongs to another Silarah account. Sign in to that account or contact Silarah Support.',
      PurchasesErrorCode.operationAlreadyInProgressError =>
        'A purchase is already in progress. Complete it in Google Play, then return to Silarah.',
      _ => 'The purchase was not completed. Please try again.',
    };
  }

  Future<void> restore() async {
    final generation = _sessionGeneration;
    await _withStoreIdentity(() => _restore(generation));
  }

  Future<void> _restore(int generation) async {
    if (!_isCurrentSession(generation)) return;
    if (!_storeIdentityReady) {
      await _loginUser(_loggedInUserId!, generation);
      if (!_isCurrentSession(generation)) return;
      if (!_storeIdentityReady) {
        emit(state.copyWith(
            isLoading: false,
            error: _purchaseErrorMessage(PurchasesErrorCode.networkError)));
        return;
      }
    }
    emit(state.copyWith(isLoading: true, clearError: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return;
    }

    try {
      final success = await SubscriptionService.instance.restorePurchases();

      if (!_isCurrentSession(generation)) return;

      if (success) {
        final info = await Purchases.getCustomerInfo();
        await _refreshEffectiveEntitlement(
          info,
          generation: generation,
          isLoading: false,
          successMessage: 'Alhamdulillah! Your subscription has been restored.',
        );
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: 'No previous purchases found for this account.',
        ));
      }
    } catch (e) {
      debugPrint('[SubscriptionCubit] Restore error: $e');
      if (_isCurrentSession(generation)) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Restore failed. Please try again.',
        ));
      }
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  /// Refreshes paid and promotional access without requiring a new login.
  /// Referral rewards can arrive while the app is already open, so login-only
  /// entitlement hydration is not sufficient.
  ///
  /// [allowRecent] lets routine reconciliation (resume, reconnect) reuse a
  /// server grant read in the last 30 seconds. Purchases, restores,
  /// referral rewards and user-initiated refreshes always ask the server.
  Future<void> refreshEntitlement({
    bool showLoading = false,
    bool allowRecent = false,
  }) async {
    if (!SupabaseService.isInitialized) return;
    final generation = _sessionGeneration;
    await _identityInFlight;
    if (!_isCurrentSession(generation)) return;
    if (!_storeIdentityReady) {
      final userId = _loggedInUserId!;
      await _withStoreIdentity(() => _loginUser(userId, generation));
      return;
    }
    if (showLoading && !isClosed) emit(state.copyWith(isLoading: true));

    CustomerInfo? customerInfo;
    try {
      customerInfo = await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('[SubscriptionCubit] RevenueCat refresh error: $e');
    }
    await _refreshEffectiveEntitlement(customerInfo,
        generation: generation, isLoading: false, allowRecent: allowRecent);
  }

  void clear() {
    _sessionGeneration++;
    _entitlementRefreshId++;
    _expiryTimer?.cancel();
    _detachCustomerInfoListener();
    _loggedInUserId = null;
    _storeIdentityReady = false;
    SubscriptionService.instance.clearUser();
    if (!isClosed) emit(const SubscriptionState());
  }

  Future<void> logoutUser() {
    clear();
    return _withStoreIdentity(_performRevenueCatLogout);
  }

  Future<void> _performRevenueCatLogout() async {
    try {
      await Purchases.logOut();
    } catch (error) {
      // Logging out an already-anonymous RevenueCat identity is harmless.
      debugPrint('[SubscriptionCubit] RevenueCat logout skipped: $error');
    }
  }

  void _detachCustomerInfoListener() {
    final listener = _customerInfoListener;
    if (listener == null) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
    _customerInfoListener = null;
  }

  Future<void> _refreshEffectiveEntitlement(
    CustomerInfo? customerInfo, {
    required int generation,
    bool? isLoading,
    String? successMessage,
    bool allowRecent = false,
  }) async {
    if (!_isCurrentSession(generation)) return;
    final refreshId = ++_entitlementRefreshId;
    final revenueCatActive = customerInfo != null &&
        SubscriptionEntitlements.isPremiumActive(customerInfo);
    final revenueCatExpiry = revenueCatActive
        ? DateTime.tryParse(
            SubscriptionEntitlements.activePremium(customerInfo)
                    ?.expirationDate ??
                '',
          )
        : null;

    final server = await _loadServerEntitlement(allowRecent: allowRecent);
    if (!_isCurrentSession(generation) || refreshId != _entitlementRefreshId) {
      return;
    }

    // A transient Supabase failure must not revoke an unexpired promotional
    // entitlement already proven by the server on this session.
    if (!server.isAvailable &&
        !revenueCatActive &&
        state.isSubscribed &&
        (state.expiresAt == null || state.expiresAt!.isAfter(DateTime.now()))) {
      emit(state.copyWith(isLoading: isLoading ?? false));
      _armExpiryRefresh(state.expiresAt);
      return;
    }

    final active = revenueCatActive || server.isActive;
    final hasIndefiniteEntitlement =
        (revenueCatActive && revenueCatExpiry == null) ||
            (server.isActive && server.expiresAt == null);
    final expiry = hasIndefiniteEntitlement
        ? null
        : _laterOf(revenueCatExpiry, server.expiresAt);
    final source = _effectiveSource(
      active: active,
      revenueCatActive: revenueCatActive,
      serverSource: server.source,
    );

    emit(state.copyWith(
      isLoading: isLoading ?? false,
      status: active ? SubscriptionStatus.active : SubscriptionStatus.none,
      source: source,
      expiresAt: expiry,
      clearExpiresAt: expiry == null,
      successMessage: successMessage,
    ));
    _armExpiryRefresh(expiry);
  }

  void _armExpiryRefresh(DateTime? expiresAt) {
    _expiryTimer?.cancel();
    if (expiresAt == null || _loggedInUserId == null) return;
    final delay = expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(
      delay.isNegative ? const Duration(milliseconds: 250) : delay,
      () {
        if (!isClosed && _loggedInUserId != null) {
          unawaited(refreshEntitlement());
        }
      },
    );
  }

  // Login and the listener replay at startup used to read this twice.
  static final _serverGrant = AccountScopedRead<Object?>(
    freshness: MyAccountSnapshot.freshness,
    load: (_) => SupabaseService.client.rpc('get_my_premium_entitlement'),
  );

  Future<_ServerPremiumEntitlement> _loadServerEntitlement({
    required bool allowRecent,
  }) async {
    final userId = _loggedInUserId;
    if (userId == null) return const _ServerPremiumEntitlement();
    try {
      final response = await _serverGrant.read(userId, force: !allowRecent);
      final Map<String, dynamic>? row = switch (response) {
        final List<dynamic> rows when rows.isNotEmpty =>
          Map<String, dynamic>.from(rows.first as Map),
        final Map<dynamic, dynamic> value => Map<String, dynamic>.from(value),
        _ => null,
      };
      if (row == null) {
        return const _ServerPremiumEntitlement(isAvailable: true);
      }

      return _ServerPremiumEntitlement(
        isAvailable: true,
        isActive: row['is_active'] == true,
        source: PremiumEntitlementSource.fromServer(row['source']?.toString()),
        expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('[SubscriptionCubit] Server entitlement error: $e');
      return const _ServerPremiumEntitlement();
    }
  }

  DateTime? _laterOf(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  PremiumEntitlementSource _effectiveSource({
    required bool active,
    required bool revenueCatActive,
    required PremiumEntitlementSource serverSource,
  }) {
    if (!active) return PremiumEntitlementSource.none;
    if (revenueCatActive && serverSource == PremiumEntitlementSource.referral) {
      return PremiumEntitlementSource.paidAndReferral;
    }
    if (revenueCatActive && serverSource == PremiumEntitlementSource.none) {
      return PremiumEntitlementSource.paid;
    }
    return serverSource;
  }

  @override
  Future<void> close() {
    clear();
    _pricingSub?.cancel();
    return super.close();
  }
}

class _ServerPremiumEntitlement {
  const _ServerPremiumEntitlement({
    this.isAvailable = false,
    this.isActive = false,
    this.source = PremiumEntitlementSource.none,
    this.expiresAt,
  });

  final bool isAvailable;
  final bool isActive;
  final PremiumEntitlementSource source;
  final DateTime? expiresAt;
}

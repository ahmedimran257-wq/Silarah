// SILARAH subscription state. Paid-store and promotional entitlements are
// merged into one canonical runtime state.
import 'package:equatable/equatable.dart';

enum SubscriptionStatus { none, active, grace }

enum PremiumEntitlementSource {
  none,
  paid,
  referral,
  test,
  paidAndReferral;

  static PremiumEntitlementSource fromServer(String? value) => switch (value) {
        'paid' => PremiumEntitlementSource.paid,
        'referral' => PremiumEntitlementSource.referral,
        'test' => PremiumEntitlementSource.test,
        'paid_and_referral' => PremiumEntitlementSource.paidAndReferral,
        _ => PremiumEntitlementSource.none,
      };
}

class SubscriptionState extends Equatable {
  final SubscriptionStatus status;
  final PremiumEntitlementSource source;
  final DateTime? expiresAt;

  /// The paid plan's own period end. [expiresAt] can be later when a referral
  /// reward runs past it, which is not when the plan renews.
  final DateTime? paidExpiresAt;

  /// Whether the store will renew at [expiresAt]. False once cancelled; null
  /// when the store has not answered.
  final bool? willRenew;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const SubscriptionState({
    this.status = SubscriptionStatus.none,
    this.source = PremiumEntitlementSource.none,
    this.expiresAt,
    this.paidExpiresAt,
    this.willRenew,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  // Women always message free.
  // Men need active or grace (within 24h) to message.
  bool canMessage(String gender) {
    if (gender == 'female') return true;
    return status == SubscriptionStatus.active ||
        status == SubscriptionStatus.grace;
  }

  bool get isSubscribed =>
      status == SubscriptionStatus.active || status == SubscriptionStatus.grace;

  /// Alias used by filter/boost gates.
  bool get isActive => isSubscribed;

  bool get isReferralOnly =>
      isSubscribed && source == PremiumEntitlementSource.referral;

  /// Owner-supervised, server-expiring physical-device QA access. It is not
  /// a store purchase, referral reward, or public trust signal.
  bool get isTestOnly =>
      isSubscribed && source == PremiumEntitlementSource.test;

  bool get isTemporaryPromotional => isReferralOnly || isTestOnly;

  bool get includesReferral =>
      source == PremiumEntitlementSource.referral ||
      source == PremiumEntitlementSource.paidAndReferral;

  bool get hasPaidPremium =>
      isSubscribed &&
      (source == PremiumEntitlementSource.paid ||
          source == PremiumEntitlementSource.paidAndReferral);

  /// Premium features — require subscription for ALL users.
  bool canUseAdvancedFilters(String gender) => isActive;
  bool canBoostProfile(String gender) => isActive;
  bool canSaveMultipleFilterPresets(String gender) => isActive;
  bool canSeeFullViewersList(String gender) => isActive;
  bool get canViewCompatibilityInsights => isActive;
  bool get canOrganizeShortlists => isActive;
  bool get canUseIncognito => isActive;

  /// Basic viewer count (not full list) is free for all.
  bool canSeeViewerCount(String gender) => true;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    PremiumEntitlementSource? source,
    DateTime? expiresAt,
    DateTime? paidExpiresAt,
    bool? willRenew,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearExpiresAt = false,
    bool clearPaidExpiresAt = false,
    bool clearWillRenew = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      source: source ?? this.source,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      paidExpiresAt:
          clearPaidExpiresAt ? null : (paidExpiresAt ?? this.paidExpiresAt),
      willRenew: clearWillRenew ? null : (willRenew ?? this.willRenew),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        source,
        expiresAt,
        paidExpiresAt,
        willRenew,
        isLoading,
        error,
        successMessage,
      ];
}

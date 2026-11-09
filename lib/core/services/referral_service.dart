// SILARAH — Referral Service
//
// Fixes Audit Finding 7.1 (High):
//   No viral or ambassador mechanics. Handles referral code
//   generation, application, and sharing.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../legal/public_site_links.dart';
import 'supabase_service.dart';

/// Manages referral code generation, application, and reward tracking.
class ReferralService {
  ReferralService._();
  static final instance = ReferralService._();

  SupabaseClient get _supabase {
    if (!SupabaseService.isInitialized) {
      throw UnsupportedError('Referral requires backend');
    }
    return SupabaseService.client;
  }

  String? _cachedCode;
  String? _cachedUserId;

  /// The current user's referral code. Null until [getOrCreateCode] is called.
  String? get referralCode => _cachedCode;

  /// Gets the user's existing referral code or generates a new one.
  ///
  /// The code is a 6-character alphanumeric uppercase string.
  /// Idempotent: calling multiple times returns the same code.
  Future<String> getOrCreateCode() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    if (_cachedUserId == userId && _cachedCode != null) return _cachedCode!;

    try {
      final response = await _supabase.rpc('generate_referral_code');
      _cachedCode = response as String;
      _cachedUserId = userId;
      return _cachedCode!;
    } catch (e) {
      debugPrint('[ReferralService] Error generating code: $e');
      rethrow;
    }
  }

  void clearCache() {
    _cachedCode = null;
    _cachedUserId = null;
  }

  /// Applies a referral code during onboarding.
  ///
  /// Returns a status string:
  /// - 'applied': Code successfully applied
  /// - 'already_referred': User was already referred
  /// - 'invalid_code': Code does not exist
  /// - 'self_referral': User tried to refer themselves
  Future<String> applyCode(String code) async {
    try {
      final response = await _supabase.rpc(
        'apply_referral_code',
        params: {'p_code': code.toUpperCase().trim()},
      );

      final result = response as Map<String, dynamic>;
      final status = result['status'] as String;

      debugPrint('[ReferralService] Apply code result: $status');
      return status;
    } catch (e) {
      debugPrint('[ReferralService] Error applying code: $e');
      rethrow;
    }
  }

  /// Checks that a six-character code exists without exposing its owner.
  /// This RPC is intentionally usable before sign-in so the welcome screen
  /// never promises that an invalid code was saved.
  Future<bool> validateCode(String code) async {
    final normalized = code.toUpperCase().trim();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) return false;
    final response = await _supabase.rpc(
      'validate_referral_code',
      params: {'p_code': normalized},
    );
    return response == true;
  }

  /// Gets the referral share text with the user's code.
  ///
  /// App Links cover only /auth/ and the site has no per-code or per-profile
  /// pages, so shares use the home page and carry the code as plain text.
  Future<String> getShareText() async {
    final code = await getOrCreateCode();
    return 'Join Silarah — the most trusted Muslim matrimony app. '
        'Use my referral code: $code\n\n'
        'Download: ${PublicSiteLinks.origin}';
  }

  /// The share text for a profile. There is no page for one profile, so this
  /// names the member and points at the home page without implying a link.
  ///
  /// [translate] is the screen's `context.uiCopy`, because this service has no
  /// locale of its own. Without it the text stays in English.
  static String profileShareText({
    required String firstName,
    String? code,
    String Function(String source)? translate,
  }) {
    final t = translate ?? (String source) => source;
    final codeLabel = t('Referral code:');
    final getLabel = t('Get Silarah:');
    final codeLine = code == null ? '' : '\n$codeLabel $code';
    final found = t('I found {name} on Silarah, a Muslim matrimony app.')
        .replaceAll('{name}', firstName);
    return '$found\n\n'
        '$getLabel ${PublicSiteLinks.origin}$codeLine';
  }

  /// The member's code for an optional share line; a share never fails or
  /// stalls because the code could not be read.
  Future<String?> getCodeOrNull() async {
    try {
      return await getOrCreateCode().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[ReferralService] Share without code: $e');
      return null;
    }
  }

  /// Gets the user's referral statistics.
  Future<ReferralStats> getStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final responses = await Future.wait([
        _supabase
            .from('referrals')
            .select('id, referred_gender, reward_granted, reward_type')
            .eq('referrer_id', userId),
        _supabase
            .from('promotional_premium_grants')
            .select('id')
            .eq('user_id', userId)
            .eq('beneficiary_role', 'referrer'),
      ]);

      final referrals = responses.first as List<dynamic>;
      final earnedGrants = responses.last as List<dynamic>;

      return ReferralStats(
        totalReferrals: referrals.length,
        // The database enforces one lifetime reward per account. Count the
        // auditable grant owned by this inviter, not every completed referral.
        rewardsEarned: earnedGrants.length,
        pendingReferrals:
            referrals.where((r) => r['reward_granted'] == false).length,
      );
    } catch (e) {
      debugPrint('[ReferralService] Error fetching stats: $e');
      rethrow;
    }
  }
}

/// Statistics about a user's referral activity.
class ReferralStats {
  const ReferralStats({
    required this.totalReferrals,
    required this.rewardsEarned,
    required this.pendingReferrals,
  });

  /// Total number of users referred (completed onboarding).
  final int totalReferrals;

  /// Number of one-time Premium rewards earned from referrals (0 or 1).
  final int rewardsEarned;

  /// Referrals who haven't completed onboarding yet.
  final int pendingReferrals;

  /// Total days of premium earned from referrals.
  int get premiumDaysEarned => rewardsEarned * 3;
}

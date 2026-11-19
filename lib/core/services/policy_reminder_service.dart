import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/legal_documents.dart';
import 'supabase_service.dart';

class PolicyReminderState {
  const PolicyReminderState({required this.isDue});

  final bool isDue;
}

/// Checks the authoritative reminder date at most once per policy interval.
///
/// The versioned local key means a future policy bundle immediately bypasses
/// an old cache. Supabase remains the source of truth across devices.
class PolicyReminderService {
  PolicyReminderService._();

  static final instance = PolicyReminderService._();

  // Per account: after one member acknowledges, the next account on this
  // phone must still be reminded.
  static String get _nextCheckKey =>
      'policy_reminder_next_check_${LegalDocuments.version}_${SupabaseService.currentUserId ?? 'signed_out'}';

  Future<PolicyReminderState> getState() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return const PolicyReminderState(isDue: false);
    }

    final preferences = await SharedPreferences.getInstance();
    final cachedNextCheck = preferences.getInt(_nextCheckKey);
    if (cachedNextCheck != null &&
        DateTime.now().millisecondsSinceEpoch < cachedNextCheck) {
      return const PolicyReminderState(isDue: false);
    }

    try {
      final response = await SupabaseService.client
          .rpc<List<dynamic>>('get_my_policy_reminder_state');
      final row = response.isEmpty
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(response.first as Map);
      final isDue = row['reminder_due'] == true;
      if (!isDue) {
        final nextReminder = DateTime.tryParse(
          row['next_reminder_at']?.toString() ?? '',
        );
        if (nextReminder != null) {
          await preferences.setInt(
            _nextCheckKey,
            nextReminder.toLocal().millisecondsSinceEpoch,
          );
        }
      }
      return PolicyReminderState(isDue: isDue);
    } catch (error) {
      debugPrint('PolicyReminderService: state check failed: $error');
      return const PolicyReminderState(isDue: false);
    }
  }

  Future<bool> acknowledge() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return false;
    }
    try {
      final acknowledgedAt = await SupabaseService.client.rpc<String>(
        'acknowledge_policy_reminder',
        params: {'p_policy_version': LegalDocuments.version},
      );
      final acknowledged = DateTime.tryParse(acknowledgedAt);
      if (acknowledged == null) return false;

      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        _nextCheckKey,
        // Recheck slightly before the authoritative three-calendar-month
        // deadline. This avoids local month-end arithmetic ever delaying a
        // reminder while still eliminating per-launch database reads.
        acknowledged.add(const Duration(days: 89)).millisecondsSinceEpoch,
      );
      return true;
    } catch (error) {
      debugPrint('PolicyReminderService: acknowledgement failed: $error');
      return false;
    }
  }
}

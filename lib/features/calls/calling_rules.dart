// Every number a member is told about calling, from the server
// (get_calling_rules, docs/voice_calling_spec.md 12.6). Copy never
// hard-codes them: if the server changes a value, the text follows.
import 'package:flutter/foundation.dart';

@immutable
class CallingRules {
  const CallingRules({
    required this.callsEnabled,
    required this.unansweredCallLimit,
    required this.includedMinutes,
    required this.includedPeriodDays,
    required this.maxCallMinutes,
    required this.ringSeconds,
    required this.maxPackRefunds,
    required this.minMinutesToCall,
    required this.planMinLeadMinutes,
    required this.planMaxDaysAhead,
    required this.planWindowMinutes,
    required this.planReminderMinutes,
    required this.planMaxOpen,
    required this.planMaxPerChatDay,
    required this.logRetentionMonths,
  });

  /// The server switch. Off: every calling surface is hidden (spec 12.6).
  final bool callsEnabled;
  final int unansweredCallLimit;
  final int includedMinutes;
  final int includedPeriodDays;
  final int maxCallMinutes;
  final int ringSeconds;
  final int maxPackRefunds;
  final int minMinutesToCall;
  final int planMinLeadMinutes;
  final int planMaxDaysAhead;
  final int planWindowMinutes;
  final int planReminderMinutes;
  final int planMaxOpen;
  final int planMaxPerChatDay;
  final int logRetentionMonths;

  static CallingRules? fromJson(Object? value) {
    if (value is! Map) return null;
    int n(String key) => (value[key] as num?)?.toInt() ?? 0;
    return CallingRules(
      callsEnabled: value['calls_enabled'] == true,
      unansweredCallLimit: n('unanswered_call_limit'),
      includedMinutes: n('included_minutes'),
      includedPeriodDays: n('included_period_days'),
      maxCallMinutes: n('max_call_minutes'),
      ringSeconds: n('ring_seconds'),
      maxPackRefunds: n('max_pack_refunds'),
      minMinutesToCall: n('min_minutes_to_call'),
      planMinLeadMinutes: n('plan_min_lead_minutes'),
      planMaxDaysAhead: n('plan_max_days_ahead'),
      planWindowMinutes: n('plan_window_minutes'),
      planReminderMinutes: n('plan_reminder_minutes'),
      planMaxOpen: n('plan_max_open'),
      planMaxPerChatDay: n('plan_max_per_chat_day'),
      logRetentionMonths: n('log_retention_months'),
    );
  }

  /// Placeholders for copy: `{limit}`, `{included}`, `{max_call}`, ...
  Map<String, Object> get copyValues => {
        'limit': unansweredCallLimit,
        'included': includedMinutes,
        'period_days': includedPeriodDays,
        'max_call': maxCallMinutes,
        'ring': ringSeconds,
        'refunds': maxPackRefunds,
        'min_to_call': minMinutesToCall,
        'lead': planMinLeadMinutes,
        'days_ahead': planMaxDaysAhead,
        'window': planWindowMinutes,
        'reminder': planReminderMinutes,
        'retention': logRetentionMonths,
      };
}

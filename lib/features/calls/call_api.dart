// Talks to the server side of calling: the `calls` edge function and the
// member RPCs from migrations 323 and 324. Minutes are never changed from
// the app.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import 'call_log.dart';
import 'call_models.dart';
import 'calling_rules.dart';

typedef CallFunctionInvoker = Future<Map<String, dynamic>> Function(
  Map<String, Object?> body,
);
typedef CallRpcInvoker = Future<Object?> Function(
  String name,
  Map<String, Object?> params,
);

class CallApi {
  CallApi({CallFunctionInvoker? invoke, CallRpcInvoker? rpc})
      : _invoke = invoke ?? _defaultInvoke,
        _rpc = rpc ?? _defaultRpc;

  static final CallApi instance = CallApi();

  final CallFunctionInvoker _invoke;
  final CallRpcInvoker _rpc;

  static Future<Map<String, dynamic>> _defaultInvoke(
    Map<String, Object?> body,
  ) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'calls',
        region: SupabaseService.functionsRegion,
        body: body,
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FunctionException catch (error) {
      debugPrint('[CallApi] ${body['action']} failed: ${error.status}');
      final details = error.details;
      if (details is Map) return Map<String, dynamic>.from(details);
      return {'error': 'http_${error.status}'};
    }
  }

  static Future<Object?> _defaultRpc(
    String name,
    Map<String, Object?> params,
  ) =>
      SupabaseService.client.rpc(name, params: params);

  Future<CallStartResult> start(String matchId) async {
    final json = await _invoke({'action': 'start', 'match_id': matchId});
    return CallStartResult(
      json['error'] != null
          ? CallStartOutcome.failed
          : CallStartOutcome.parse(json['outcome']?.toString()),
      requestId: json['request_id']?.toString(),
      ringSeconds: (json['ring_seconds'] as num?)?.toInt(),
      retryAfter: DateTime.tryParse(json['retry_after']?.toString() ?? ''),
      quietUntil: json['reason'] == 'quiet_hours' ? DateTime.tryParse(json['quiet_until']?.toString() ?? '') : null,
    );
  }

  /// `ringing`, `connecting`, `active`, `ended`, `declined`, ... (no token).
  Future<String> status(String requestId) async {
    final json = await _invoke({'action': 'status', 'request_id': requestId});
    return json['outcome']?.toString() ?? 'unknown';
  }

  /// The caller's view of a ring: its state, and whether it reached the
  /// other member's phone ("Calling…" until it did, "Ringing…" after).
  Future<({String outcome, bool delivered})> ringStatus(String requestId) async {
    final json = await _invoke({'action': 'status', 'request_id': requestId});
    return (outcome: json['outcome']?.toString() ?? 'unknown', delivered: json['delivered'] == true);
  }

  /// A live call's paid minutes and time limit now: they grow when the
  /// caller adds minutes.
  Future<({String outcome, int? maxDurationSeconds, int? holdMinutes})> liveLimits(
    String requestId,
  ) async {
    final json = await _invoke({'action': 'status', 'request_id': requestId});
    return (
      outcome: json['outcome']?.toString() ?? 'unknown',
      maxDurationSeconds: (json['max_duration_seconds'] as num?)?.toInt(),
      holdMinutes: (json['hold_minutes'] as num?)?.toInt(),
    );
  }

  Future<({String outcome, CallJoinInfo? info})> accept(
    String requestId, {
    String? deviceId,
  }) async {
    final json = await _invoke({
      'action': 'accept',
      'request_id': requestId,
      if (deviceId != null) 'device_id': deviceId,
    });
    return (
      outcome: json['outcome']?.toString() ?? 'failed',
      info: CallJoinInfo.fromJson(requestId, json),
    );
  }

  Future<({String outcome, CallJoinInfo? info})> join(String requestId) async {
    final json = await _invoke({'action': 'join', 'request_id': requestId});
    return (
      outcome: json['outcome']?.toString() ?? 'unknown',
      info: CallJoinInfo.fromJson(requestId, json),
    );
  }

  Future<String> end(String requestId, {String reason = 'hangup'}) async {
    final json = await _invoke({
      'action': 'end',
      'request_id': requestId,
      'reason': reason,
    });
    return json['outcome']?.toString() ?? 'unknown';
  }

  Future<({String outcome, int? maxDurationSeconds, int? holdMinutes})> extend(
    String requestId,
  ) async {
    final json = await _invoke({'action': 'extend', 'request_id': requestId});
    return (
      outcome: json['outcome']?.toString() ?? 'failed',
      maxDurationSeconds: (json['max_duration_seconds'] as num?)?.toInt(),
      holdMinutes: (json['hold_minutes'] as num?)?.toInt(),
    );
  }

  Future<CallWallet?> wallet() async {
    try {
      final data = await _rpc('get_my_call_wallet', const {});
      return data is Map ? CallWallet.fromJson(Map<String, dynamic>.from(data)) : null;
    } catch (error) {
      debugPrint('[CallApi] wallet failed: $error');
      return null;
    }
  }

  /// The chat's call controls, or null when they could not be loaded (the
  /// caller keeps what it showed: a failed load is not an answer).
  Future<ChatCallState?> chatState(String matchId) async {
    try {
      final data = await _rpc('get_chat_call_state', {'p_match_id': matchId});
      if (data is Map) return ChatCallState.fromJson(Map<String, dynamic>.from(data));
      debugPrint('[CallApi] chat state: unexpected reply ${data.runtimeType}');
      return null;
    } catch (error) {
      debugPrint('[CallApi] chat state failed: $error');
      return null;
    }
  }

  Future<bool> setChatPrefs(
    String matchId, {
    required bool muted,
    required bool callsBlocked,
  }) async {
    try {
      await _rpc('set_chat_call_prefs', {
        'p_match_id': matchId,
        'p_muted': muted,
        'p_calls_blocked': callsBlocked,
      });
      return true;
    } catch (error) {
      debugPrint('[CallApi] chat prefs failed: $error');
      return false;
    }
  }

  /// `ring`, `silent` or `off`; null when calling is unavailable.
  Future<({String mode, bool enabled})?> preferences() async {
    try {
      final data = await _rpc('get_my_call_preferences', const {});
      if (data is! Map) return null;
      return (
        mode: data['call_mode']?.toString() ?? 'ring',
        enabled: data['calls_enabled'] == true,
      );
    } catch (error) {
      debugPrint('[CallApi] preferences failed: $error');
      return null;
    }
  }

  Future<bool> setMode(String mode) async {
    try {
      await _rpc('set_my_call_mode', {'p_mode': mode});
      return true;
    } catch (error) {
      debugPrint('[CallApi] set mode failed: $error');
      return false;
    }
  }
  // ---------------------------------------------------------------------------
  // Calls tab (spec 12.5) and planned calls (spec 13)
  // ---------------------------------------------------------------------------

  /// The switch and every number members are told (spec 12.6).
  Future<CallingRules?> rules() async {
    try {
      return CallingRules.fromJson(await _rpc('get_calling_rules', const {}));
    } catch (error) {
      debugPrint('[CallApi] rules failed: $error');
      return null;
    }
  }

  Future<CallOverview?> overview() async {
    try {
      final data = await _rpc('get_my_call_overview', const {});
      return data is Map ? CallOverview.fromJson(Map<String, dynamic>.from(data)) : null;
    } catch (error) {
      debugPrint('[CallApi] overview failed: $error');
      return null;
    }
  }

  /// One page, newest first. Throws so the screen can offer a retry.
  Future<List<CallLogEntry>> log({
    CallLogFilter filter = CallLogFilter.all,
    String? query,
    CallLogEntry? after,
    int limit = 40,
    String? otherUserId,
  }) async {
    final data = await _rpc('get_my_call_log', {
      if (otherUserId != null) 'p_other_user_id': otherUserId,
      'p_filter': filter == CallLogFilter.planned ? 'all' : filter.serverName,
      'p_query': (query?.trim().isEmpty ?? true) ? null : query!.trim(),
      'p_before': after?.createdAt.toUtc().toIso8601String(),
      'p_before_id': after?.requestId,
      'p_limit': limit,
    });
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((row) => CallLogEntry.fromJson(Map<String, dynamic>.from(row)))
        .whereType<CallLogEntry>()
        .toList(growable: false);
  }

  Future<List<CallPlan>> plans() async {
    try {
      return CallPlan.listFrom(await _rpc('get_my_call_plans', const {}));
    } catch (error) {
      debugPrint('[CallApi] plans failed: $error');
      return const [];
    }
  }

  /// Clears the badge here and on the member's other phones.
  Future<bool> markSeen() async {
    try {
      await _rpc('mark_calls_seen', const {});
      return true;
    } catch (error) {
      debugPrint('[CallApi] mark seen failed: $error');
      return false;
    }
  }

  /// Remove from history (this member only).
  Future<bool> hide(List<String> requestIds) async {
    if (requestIds.isEmpty) return true;
    try {
      await _rpc('hide_my_calls', {'p_request_ids': requestIds.take(200).toList()});
      return true;
    } catch (error) {
      debugPrint('[CallApi] hide failed: $error');
      return false;
    }
  }

  /// `proposed`, `already_planned`, `invalid_time`, `limit_reached`,
  /// `premium_required`, `unavailable`, `not_allowed`, `calls_disabled`,
  /// `account_restricted`, or `failed`.
  Future<String> proposePlan(String matchId, DateTime at) =>
      _planCall('propose_call_plan', {'p_match_id': matchId, 'p_planned_for': at.toUtc().toIso8601String()});

  Future<String> respondPlan(String planId, {required bool accept}) =>
      _planCall('respond_call_plan', {'p_plan_id': planId, 'p_accept': accept});

  Future<String> cancelPlan(String planId) => _planCall('cancel_call_plan', {'p_plan_id': planId});

  Future<String> _planCall(String name, Map<String, Object?> params) async {
    try {
      final data = await _rpc(name, params);
      return data is Map ? data['outcome']?.toString() ?? 'failed' : 'failed';
    } catch (error) {
      debugPrint('[CallApi] $name failed: $error');
      return 'failed';
    }
  }

  /// Whether this phone can ring (notifications on, incoming-call channel
  /// not blocked). The server rings only phones that said yes.
  Future<bool> reportRingCapability({required String deviceId, required bool canRing}) async {
    try {
      await _rpc('set_my_call_ring_capability', {'p_device_id': deviceId, 'p_can_ring': canRing});
      return true;
    } catch (error) {
      debugPrint('[CallApi] ring capability failed: $error');
      return false;
    }
  }
}

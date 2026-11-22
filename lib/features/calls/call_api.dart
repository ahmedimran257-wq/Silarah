// Talks to the server side of calling: the `calls` edge function and the
// member RPCs from migration 323. Minutes are never changed from the app.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import 'call_models.dart';

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
    );
  }

  /// `ringing`, `connecting`, `active`, `ended`, `declined`, ... (no token).
  Future<String> status(String requestId) async {
    final json = await _invoke({'action': 'status', 'request_id': requestId});
    return json['outcome']?.toString() ?? 'unknown';
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

  Future<ChatCallState> chatState(String matchId) async {
    try {
      final data = await _rpc('get_chat_call_state', {'p_match_id': matchId});
      return data is Map
          ? ChatCallState.fromJson(Map<String, dynamic>.from(data))
          : ChatCallState.hidden;
    } catch (error) {
      debugPrint('[CallApi] chat state failed: $error');
      return ChatCallState.hidden;
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
}

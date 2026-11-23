// Call notifications (incoming ring, missed calls, planned-call reminders),
// drawn by Silarah's native call module from data-only FCM pushes
// (voice_calling_spec.md 4 and 12: our server owns ringing; no Stream push).
//
// Runs in two places:
//  * the FCM background isolate (app closed or in the background), via
//    silarahFirebaseMessagingBackgroundHandler in main.dart;
//  * the app itself, via FcmService.onForegroundMessage.
//
// Shared-phone rule (spec 9 gate 7): a ring is shown only when the push
// names the account signed in on this phone right now. Sign-out clears that
// account before the push token is retired, so a late push for the previous
// account is dropped even if it arrives.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah_calls/silarah_calls.dart';

import '../../core/config/app_config.dart';
import '../../l10n/calling_ui_copy.dart';

const _signedInUserKey = 'silarah_call_push_user_v1';
const _localeKey = 'app_locale';

/// The parts of an incoming-call push the phone needs.
class IncomingCallPush {
  const IncomingCallPush({
    required this.requestId,
    required this.matchId,
    required this.callerName,
    required this.declineToken,
    required this.expiresAt,
    required this.forUser,
  });

  final String requestId;
  final String matchId;
  final String callerName;
  final String declineToken;
  final DateTime expiresAt;
  final String forUser;

  /// [receivedAt] is when this phone got the push. The ring lasts
  /// `ring_seconds` from then, so a phone with a wrong clock still rings for
  /// the full time; FCM drops a push that arrives after its time to live.
  static IncomingCallPush? fromData(Map<String, dynamic> data, {DateTime? receivedAt}) {
    if (data['type'] != 'call_incoming') return null;
    final seconds = int.tryParse(data['ring_seconds']?.toString() ?? '');
    final expires = seconds != null && seconds > 0
        ? (receivedAt ?? DateTime.now()).add(Duration(seconds: seconds.clamp(1, 120)))
        : DateTime.tryParse(data['expires_at']?.toString() ?? '');
    final requestId = data['request_id']?.toString() ?? '';
    final forUser = data['for_user']?.toString() ?? '';
    if (expires == null || requestId.isEmpty || forUser.isEmpty) return null;
    return IncomingCallPush(
      requestId: requestId,
      matchId: data['match_id']?.toString() ?? '',
      callerName: (data['caller_name']?.toString() ?? '').trim(),
      declineToken: data['decline_token']?.toString() ?? '',
      expiresAt: expires,
      forUser: forUser,
    );
  }

  String toPayload() => jsonEncode({
        'request_id': requestId,
        'match_id': matchId,
        'caller_name': callerName,
        'decline_token': declineToken,
        'expires_at': expiresAt.toIso8601String(),
        'for_user': forUser,
      });

  static IncomingCallPush? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return fromData({
        ...Map<String, dynamic>.from(decoded),
        'type': 'call_incoming',
      });
    } catch (_) {
      return null;
    }
  }
}

/// Should this phone ring for [push] right now?
bool shouldRing(IncomingCallPush push, {required String? signedInUserId, required DateTime now}) =>
    signedInUserId != null &&
    signedInUserId.isNotEmpty &&
    push.forUser == signedInUserId &&
    push.expiresAt.isAfter(now);

/// A missed-call push (call-worker, spec 12.3): one notification per caller
/// with the server's count. `premium`: the callee is a free man.
class MissedCallPush {
  const MissedCallPush({
    required this.requestId,
    required this.matchId,
    required this.callerId,
    required this.callerName,
    required this.count,
    required this.premiumVariant,
    required this.silent,
    required this.forUser,
  });

  final String requestId;
  final String matchId;
  final String callerId;
  final String callerName;
  final int count;
  final bool premiumVariant;
  final bool silent;
  final String forUser;

  static MissedCallPush? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'call_missed') return null;
    final callerId = data['caller_id']?.toString() ?? '';
    final forUser = data['for_user']?.toString() ?? '';
    if (callerId.isEmpty || forUser.isEmpty) return null;
    return MissedCallPush(
      requestId: data['request_id']?.toString() ?? '',
      matchId: data['match_id']?.toString() ?? '',
      callerId: callerId,
      callerName: (data['caller_name']?.toString() ?? '').trim(),
      count: (int.tryParse(data['count']?.toString() ?? '') ?? 1).clamp(1, 99),
      premiumVariant: data['variant'] == 'premium',
      silent: data['silent'] == '1',
      forUser: forUser,
    );
  }
}

/// Title and text of a missed-call notification in [code]'s language.
({String title, String body}) missedCallText(String code, MissedCallPush push) {
  final name = push.callerName.isEmpty ? callingCopyFor(code, 'A Silarah member') : push.callerName;
  if (push.premiumVariant) {
    return (
      title: callingCopyFor(code, '{name} tried to call you').replaceAll('{name}', name),
      body: callingCopyFor(code, 'Get Premium to talk with your matches'),
    );
  }
  return (
    title: push.count > 1
        ? callingCopyFor(code, '{count} missed calls from {name}')
            .replaceAll('{count}', '${push.count}')
            .replaceAll('{name}', name)
        : callingCopyFor(code, 'Missed call from {name}').replaceAll('{name}', name),
    body: callingCopyFor(code, 'Tap to see your calls'),
  );
}

/// Call notifications on this phone, drawn by the native call module
/// (packages/silarah_calls) from data-only pushes. Works in the app and in
/// the FCM background isolate.
class CallNotifications {
  CallNotifications._();

  static SilarahCalls get _native => SilarahCalls.instance;

  static Future<void> rememberSignedInUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_signedInUserKey, userId);
  }

  /// Called on every sign-out, before the push token is retired. Never
  /// throws: sign-out must always go on to retire the token. Every call
  /// notification of the departing account goes, and any call service stops.
  static Future<void> forgetSignedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_signedInUserKey);
    } catch (error) {
      debugPrint('[CallNotifications] forget account failed: $error');
    }
    try {
      await _native.clearAll();
    } catch (error) {
      debugPrint('[CallNotifications] clear on sign-out failed: $error');
    }
  }

  /// The same account check that decided to ring, for taps and Answer.
  static Future<bool> isForSignedInUser(IncomingCallPush push) async =>
      push.forUser.isNotEmpty && push.forUser == await _signedInUser();

  static Future<String?> _signedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_signedInUserKey);
  }

  /// The member's app language (the background isolate has no widgets).
  static Future<String> languageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey) ?? 'en';
  }

  /// Handles a call push. Returns the push when this phone should ring.
  static Future<IncomingCallPush?> handlePushData(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    switch (type) {
      case 'call_cancel':
      case 'call_ended':
        final requestId = data['request_id']?.toString();
        if (requestId != null && requestId.isNotEmpty) await cancel(requestId);
        return null;
      case 'call_missed':
        await _showMissed(data);
        return null;
      case 'call_missed_seen':
        // The Calls tab was opened on another phone of this member.
        if (data['for_user']?.toString() == await _signedInUser()) await _native.clearMissed();
        return null;
      case 'call_plan_reminder':
        await _showPlanReminder(data);
        return null;
    }
    final push = IncomingCallPush.fromData(data);
    if (push == null) return null;
    final user = await _signedInUser();
    if (!shouldRing(push, signedInUserId: user, now: DateTime.now())) {
      debugPrint('[CallNotifications] ring dropped (not this account or expired).');
      return null;
    }
    await showIncoming(push);
    return push;
  }

  static Future<void> showIncoming(IncomingCallPush push) async {
    final code = await languageCode();
    final name = push.callerName.isEmpty ? callingCopyFor(code, 'A Silarah member') : push.callerName;
    await _native.showIncoming(
      requestId: push.requestId,
      payload: push.toPayload(),
      callerName: name,
      title: callingCopyFor(code, '{name} · Silarah voice call').replaceAll('{name}', name),
      body: callingCopyFor(code, '{name} is calling you').replaceAll('{name}', name),
      publicTitle: callingCopyFor(code, 'Incoming Silarah call'),
      timeout: push.expiresAt.difference(DateTime.now()),
      declineToken: push.declineToken,
      declineEndpoint: AppConfig.supabaseUrl.isEmpty ? '' : '${AppConfig.supabaseUrl}/functions/v1/calls',
      apiKey: AppConfig.supabaseAnonKey,
      answerLabel: callingCopyFor(code, 'Answer'),
      declineLabel: callingCopyFor(code, 'Decline'),
    );
  }

  static Future<void> _showMissed(Map<String, dynamic> data) async {
    final push = MissedCallPush.fromData(data);
    if (push == null || push.forUser != await _signedInUser()) return;
    final code = await languageCode();
    final text = missedCallText(code, push);
    await _native.showMissed(
      callerId: push.callerId,
      payload: jsonEncode({'match_id': push.matchId, 'variant': push.premiumVariant ? 'premium' : 'missed'}),
      title: text.title,
      body: text.body,
      publicTitle: callingCopyFor(code, 'Missed call'),
      count: push.count,
      silent: push.silent,
    );
  }

  static Future<void> _showPlanReminder(Map<String, dynamic> data) async {
    final forUser = data['for_user']?.toString() ?? '';
    if (forUser.isEmpty || forUser != await _signedInUser()) return;
    final plannedFor = DateTime.tryParse(data['planned_for']?.toString() ?? '');
    final planId = data['plan_id']?.toString() ?? '';
    if (plannedFor == null || planId.isEmpty) return;
    final windowEnd = plannedFor.add(const Duration(minutes: 30));
    if (!windowEnd.isAfter(DateTime.now())) return;
    final code = await languageCode();
    final name = (data['other_name']?.toString() ?? '').trim();
    await _native.showPlanReminder(
      planId: planId,
      payload: jsonEncode({'plan_id': planId, 'match_id': data['match_id']?.toString() ?? ''}),
      title: callingCopyFor(code, 'Your call with {name} is soon')
          .replaceAll('{name}', name.isEmpty ? callingCopyFor(code, 'A Silarah member') : name),
      body: callingCopyFor(code, 'Tap to open your calls'),
      timeout: windowEnd.difference(DateTime.now()),
      silent: data['silent'] == '1',
    );
  }

  static Future<void> cancel(String requestId) async {
    try {
      await _native.cancelIncoming(requestId);
    } catch (error) {
      debugPrint('[CallNotifications] cancel failed: $error');
    }
  }

  /// Opening the Calls tab: missed-call notifications go on this phone
  /// (the server clears the member's other phones).
  static Future<void> clearMissed() => _native.clearMissed();
}

// Incoming-call notifications, drawn by Silarah itself from data-only FCM
// pushes (voice_calling_spec.md 4: our server owns ringing; no Stream push).
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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../l10n/calling_ui_copy.dart';

const callNotificationChannelId = 'silarah_calls';
const _signedInUserKey = 'silarah_call_push_user_v1';
const _localeKey = 'app_locale';
const answerActionId = 'call_answer';
const declineActionId = 'call_decline';

/// One stable Android notification id per call.
int callNotificationId(String requestId) {
  final hex = requestId.replaceAll('-', '');
  final head = hex.length >= 7 ? hex.substring(0, 7) : hex;
  return 900000000 + (int.tryParse(head, radix: 16) ?? 0) % 99999999;
}

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

class CallNotifications {
  CallNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function(NotificationResponse response)? _onForegroundResponse;

  /// Foreground: [onResponse] receives taps and Answer.
  static Future<void> initialize({
    void Function(NotificationResponse response)? onResponse,
  }) async {
    if (onResponse != null) _onForegroundResponse = onResponse;
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_silarah'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _onForegroundResponse?.call(response),
      onDidReceiveBackgroundNotificationResponse:
          silarahCallNotificationBackgroundResponse,
    );
    await _ensureRingChannel();
    _initialized = true;
  }

  /// MainActivity creates this channel with the phone's ringtone at start.
  /// A ring can reach a freshly updated app before it was ever opened; the
  /// same channel is then created here so it still rings like a call.
  /// Android keeps whichever definition came first.
  static Future<void> _ensureRingChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final code = await _languageCode();
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        callNotificationChannelId,
        callingCopyFor(code, 'Calls'),
        importance: Importance.max,
        playSound: true,
        sound: const UriAndroidNotificationSound('content://settings/system/ringtone'),
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        enableVibration: true,
      ),
    );
  }

  /// The tap or Answer that launched the app from closed, if any.
  static Future<NotificationResponse?> launchResponse() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final response = details.notificationResponse;
    if (response == null) return null;
    return IncomingCallPush.fromPayload(response.payload) == null ? null : response;
  }

  static Future<void> rememberSignedInUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_signedInUserKey, userId);
  }

  /// Called on every sign-out, before the push token is retired. Never
  /// throws: sign-out must always go on to retire the token.
  static Future<void> forgetSignedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_signedInUserKey);
    } catch (error) {
      debugPrint('[CallNotifications] forget account failed: $error');
    }
    try {
      await initialize();
      final active = await _plugin.getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        if (id != null && id >= 900000000) await _plugin.cancel(id: id);
      }
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

  static Future<String> _languageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey) ?? 'en';
  }

  /// Handles a call push. Returns the push when this phone should ring.
  static Future<IncomingCallPush?> handlePushData(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    if (type == 'call_cancel' || type == 'call_ended') {
      final requestId = data['request_id']?.toString();
      if (requestId != null && requestId.isNotEmpty) await cancel(requestId);
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
    await initialize();
    final code = await _languageCode();
    final remaining = push.expiresAt.difference(DateTime.now());
    final name = push.callerName.isEmpty ? callingCopyFor(code, 'A Silarah member') : push.callerName;
    await _plugin.show(
      id: callNotificationId(push.requestId),
      title: callingCopyFor(code, 'Incoming Silarah call'),
      body: callingCopyFor(code, '{name} is calling you').replaceAll('{name}', name),
      payload: push.toPayload(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          callNotificationChannelId,
          callingCopyFor(code, 'Calls'),
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          // Full screen only where the member allows it (Android 14+).
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          // Name only on a locked screen if the member's lock-screen setting
          // shows private content; otherwise Android hides it.
          visibility: NotificationVisibility.private,
          timeoutAfter: remaining.inMilliseconds.clamp(1000, 60000),
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          // FLAG_INSISTENT: keep ringing until answered, declined or cancelled.
          additionalFlags: Int32List.fromList(const [4]),
          actions: [
            AndroidNotificationAction(
              declineActionId,
              callingCopyFor(code, 'Decline'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              answerActionId,
              callingCopyFor(code, 'Answer'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> cancel(String requestId) async {
    try {
      await initialize();
      await _plugin.cancel(id: callNotificationId(requestId));
    } catch (error) {
      debugPrint('[CallNotifications] cancel failed: $error');
    }
  }
}

/// Decline without opening the app: the push's single-use token proves the
/// decline came from this callee's phone (edge function `calls`).
Future<bool> declineFromNotification(IncomingCallPush push) async {
  if (AppConfig.supabaseUrl.isEmpty || push.declineToken.isEmpty) return false;
  try {
    final response = await http
        .post(
          Uri.parse('${AppConfig.supabaseUrl}/functions/v1/calls'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppConfig.supabaseAnonKey,
          },
          body: jsonEncode({
            'action': 'decline_token',
            'request_id': push.requestId,
            'token': push.declineToken,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  } catch (error) {
    debugPrint('[CallNotifications] decline failed: $error');
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> silarahCallNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  if (response.actionId != declineActionId) return;
  final push = IncomingCallPush.fromPayload(response.payload);
  if (push == null) return;
  await CallNotifications.cancel(push.requestId);
  await declineFromNotification(push);
}

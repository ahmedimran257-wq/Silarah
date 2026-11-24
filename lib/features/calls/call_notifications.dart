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
import '../../core/cubits/theme/theme_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/calling_ui_copy.dart';

const _signedInUserKey = 'silarah_call_push_user_v1';
const _localeKey = 'app_locale';

// Rings that ended on this phone (cancelled, answered, declined, missed),
// newest last, shared by the app and the FCM background isolate. FCM keeps
// no order between pushes, and a phone back online gets them together: a
// ring push can come after its own cancel or missed-call push and must not
// ring then (spec 9 gate 10). Request ids are never reused, so a short list
// is enough.
const _endedRingsKey = 'silarah_call_ended_rings_v1';
const _endedRingsKept = 50;

/// The parts of an incoming-call push the phone needs.
class IncomingCallPush {
  const IncomingCallPush({
    required this.requestId,
    required this.matchId,
    required this.callerName,
    required this.declineToken,
    required this.expiresAt,
    required this.forUser,
    this.callerId = '',
    this.callerPhoto = '',
  });

  final String requestId;
  final String matchId;
  final String callerName;

  /// Who is calling (for their photo); empty from older servers.
  final String callerId;

  /// A short-lived link to the caller's photo for the native ring screen,
  /// sent only when this member may see it; empty otherwise. Not carried in
  /// the launch payload: the app loads photos itself.
  final String callerPhoto;
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
      callerId: data['caller_id']?.toString() ?? '',
      callerPhoto: data['caller_photo']?.toString() ?? '',
    );
  }

  String toPayload() => jsonEncode({
        'request_id': requestId,
        'match_id': matchId,
        'caller_name': callerName,
        'caller_id': callerId,
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

/// The native ring screen in the member's language and theme: the same
/// colours as the app's call screen (call_screen.dart), so the ring looks
/// the same whether Android or the app shows it.
RingScreen ringScreenFor(String code, SilarahThemeMode mode, {String photoUrl = ''}) {
  final palette = SilarahPalette.forMode(mode);
  return RingScreen(
    statusLabel: callingCopyFor(code, 'Incoming call'),
    connectingLabel: callingCopyFor(code, 'Connecting…'),
    privateNote: callingCopyFor(code, 'Calls are private. Silarah never records them.'),
    background: palette.backgroundDeep.toARGB32(),
    text: palette.contentPrimary.toARGB32(),
    secondaryText: palette.contentSecondary.toARGB32(),
    accent: palette.accent.toARGB32(),
    avatarBorder: palette.accentBorder.toARGB32(),
    avatarFill: palette.surfaceInteractive.toARGB32(),
    decline: palette.danger.toARGB32(),
    onDecline: AppColors.readableOn(palette.danger).toARGB32(),
    answer: palette.success.toARGB32(),
    onAnswer: AppColors.readableOn(palette.success).toARGB32(),
    darkTheme: mode.isDark,
    photoUrl: photoUrl.isEmpty ? null : photoUrl,
  );
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
    this.termsVariant = false,
  });

  final String requestId;
  final String matchId;
  final String callerId;
  final String callerName;
  final int count;
  final bool premiumVariant;
  final bool silent;
  final String forUser;

  /// They could not be rung until they accept the calling terms.
  final bool termsVariant;

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
      termsVariant: data['variant'] == 'consent',
    );
  }
}

/// Title and text of a missed-call notification in [code]'s language.
({String title, String body}) missedCallText(String code, MissedCallPush push) {
  final name = push.callerName.isEmpty ? callingCopyFor(code, 'A Silarah member') : push.callerName;
  if (push.premiumVariant || push.termsVariant) {
    return (
      title: callingCopyWith(code, '{name} tried to call you', {'name': name}),
      body: callingCopyFor(code, push.termsVariant
          ? 'Review and accept the updated terms to receive calls.'
          : 'Get Premium to talk with your matches'),
    );
  }
  return (
    title: push.count > 1
        ? callingCopyWith(code, '{count} missed calls from {name}', {'count': push.count, 'name': name})
        : callingCopyWith(code, 'Missed call from {name}', {'name': name}),
    body: callingCopyFor(code, 'Tap to see your calls'),
  );
}

/// Call notifications on this phone, drawn by the native call module
/// (packages/silarah_calls) from data-only pushes. Works in the app and in
/// the FCM background isolate.
class CallNotifications {
  CallNotifications._();

  /// The calling system's own data pushes (the calls and call-worker
  /// functions): the ring and what follows it, missed calls and plan
  /// reminders. Only these are handled here. Other notifications about calls
  /// (a plan suggested, accepted or cancelled; pack minutes added or
  /// removed) are ordinary Silarah notifications with a `call_` type.
  static const Set<String> pushTypes = {
    'call_incoming',
    'call_cancel',
    'call_ended',
    'call_answered',
    'call_missed',
    'call_missed_seen',
    'call_plan_reminder',
  };

  static bool isCallPush(String? type) => pushTypes.contains(type);

  /// Any notification about calls (a call push or an ordinary `call_`
  /// notification) changes what the Calls tab shows.
  static bool concernsCalls(String? type) => type != null && type.startsWith('call_');

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

  // Call pushes are handled one at a time, in the order they came. In the
  // app they arrive on a stream nobody waits on: without this, a cancel that
  // came while its ring was still being read could finish first, and the
  // ring would then show and ring to its end.
  static Future<void> _lastPush = Future<void>.value();

  /// Handles a call push. Returns the push when this phone should ring.
  static Future<IncomingCallPush?> handlePushData(Map<String, dynamic> data) {
    final handled = _lastPush.then((_) => _handlePushData(data));
    _lastPush = handled.then<void>((_) {}, onError: (_) {});
    return handled;
  }

  static Future<IncomingCallPush?> _handlePushData(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    switch (type) {
      case 'call_cancel':
      case 'call_ended':
        final requestId = data['request_id']?.toString();
        if (requestId != null && requestId.isNotEmpty) await cancel(requestId);
        return null;
      case 'call_missed':
        // A missed call means its ring is over: one still on screen goes,
        // and its ring push, if it comes later, never rings.
        final requestId = data['request_id']?.toString();
        if (requestId != null && requestId.isNotEmpty) await cancel(requestId);
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
    if (await _ringEnded(push.requestId)) {
      debugPrint('[CallNotifications] ring dropped (this call already ended).');
      return null;
    }
    await showIncoming(push);
    return push;
  }

  static Future<bool> _ringEnded(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return (prefs.getStringList(_endedRingsKey) ?? const []).contains(requestId);
    } catch (error) {
      debugPrint('[CallNotifications] ended rings unreadable: $error');
      return false;
    }
  }

  static Future<void> _rememberEnded(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ended = [
        ...(prefs.getStringList(_endedRingsKey) ?? const <String>[]).where((id) => id != requestId),
        requestId,
      ];
      await prefs.setStringList(
        _endedRingsKey,
        ended.length > _endedRingsKept ? ended.sublist(ended.length - _endedRingsKept) : ended,
      );
    } catch (error) {
      debugPrint('[CallNotifications] remember ended ring failed: $error');
    }
  }

  static Future<void> showIncoming(IncomingCallPush push) async {
    final code = await languageCode();
    final name = push.callerName.isEmpty ? callingCopyFor(code, 'A Silarah member') : push.callerName;
    await _native.showIncoming(
      requestId: push.requestId,
      payload: push.toPayload(),
      callerName: name,
      title: callingCopyWith(code, '{name} · Silarah voice call', {'name': name}),
      body: callingCopyWith(code, '{name} is calling you', {'name': name}),
      publicTitle: callingCopyFor(code, 'Incoming Silarah call'),
      timeout: push.expiresAt.difference(DateTime.now()),
      declineToken: push.declineToken,
      declineEndpoint: AppConfig.supabaseUrl.isEmpty ? '' : '${AppConfig.supabaseUrl}/functions/v1/calls',
      apiKey: AppConfig.supabaseAnonKey,
      answerLabel: callingCopyFor(code, 'Answer'),
      declineLabel: callingCopyFor(code, 'Decline'),
      ringScreen: ringScreenFor(code, await _themeMode(), photoUrl: push.callerPhoto),
    );
  }

  /// The member's app theme (the background isolate has no widgets).
  static Future<SilarahThemeMode> _themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return SilarahThemeMode.fromStorage(prefs.getString(ThemeCubit.preferenceKey));
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
      title: callingCopyWith(code, 'Your call with {name} is soon',
          {'name': name.isEmpty ? callingCopyFor(code, 'A Silarah member') : name}),
      body: callingCopyFor(code, 'Tap to open your calls'),
      timeout: windowEnd.difference(DateTime.now()),
      silent: data['silent'] == '1',
    );
  }

  /// The ring of [requestId] ends on this phone, and that call never rings
  /// here again, whatever push comes later.
  static Future<void> cancel(String requestId) async {
    await _rememberEnded(requestId);
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

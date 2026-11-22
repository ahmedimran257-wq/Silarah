/// Silarah's native call module (docs/voice_calling_spec.md 12.1).
///
/// Works in the app and in the FCM background isolate (notifications only
/// there). All methods are no-ops off Android.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MicrophoneStatus { granted, denied, permanentlyDenied }

/// Something the member did outside Silarah's screens, or the system did.
@immutable
class CallEvent {
  const CallEvent(this.type, this.data);

  /// `launch` (a call notification opened Silarah: [launchAction] and
  /// [payload]), `hangUp`, `toggleMute`, `declined`, `phoneCall` ([active]),
  /// `route` ([route]), `routes` ([routes]), `telecom` ([available]).
  final String type;
  final Map<String, Object?> data;

  /// ring | answer | open_call | open_calls
  String? get launchAction => data['action'] as String?;
  String? get payload => data['payload'] as String?;
  bool get active => data['active'] == true;
  String? get route => data['current'] as String?;
  List<String> get routes =>
      (data['available'] as List?)?.map((e) => e.toString()).toList() ?? const [];
  bool get available => data['available'] == true;
  String? get requestId => data['requestId'] as String?;

  @override
  String toString() => 'CallEvent($type, $data)';
}

class SilarahCalls {
  SilarahCalls._() {
    _channel.setMethodCallHandler(_onNative);
  }

  static final SilarahCalls instance = SilarahCalls._();
  static const _channel = MethodChannel('com.silarah.calls');

  final _events = StreamController<CallEvent>.broadcast();

  /// Events from notification buttons, Telecom and the phone-call watcher.
  Stream<CallEvent> get events => _events.stream;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<dynamic> _onNative(MethodCall call) async {
    if (call.method == 'event') {
      final map = Map<String, Object?>.from(call.arguments as Map);
      _events.add(CallEvent(map['type']?.toString() ?? '', map));
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      debugPrint('[SilarahCalls] $method failed: ${error.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  // ------------------------------------------------------------ notifications

  /// Notifications allowed and the incoming-call channel not blocked.
  Future<bool> canRing() async => await _invoke<bool>('canRing') ?? false;

  /// The incoming ring (CallStyle, full screen on a locked phone). Decline
  /// goes from native code to [declineEndpoint] with the one-time token.
  Future<void> showIncoming({
    required String requestId,
    required String payload,
    required String callerName,
    required String title,
    required String body,
    required String publicTitle,
    required Duration timeout,
    required String declineToken,
    required String declineEndpoint,
    required String apiKey,
  }) =>
      _invoke<void>('showIncoming', {
        'requestId': requestId,
        'payload': payload,
        'callerName': callerName,
        'title': title,
        'body': body,
        'publicTitle': publicTitle,
        'timeoutMs': timeout.inMilliseconds,
        'declineToken': declineToken,
        'declineEndpoint': declineEndpoint,
        'apiKey': apiKey,
      });

  Future<void> cancelIncoming(String requestId) =>
      _invoke<void>('cancelIncoming', {'requestId': requestId});

  /// One notification per caller, replaced with the latest count.
  Future<void> showMissed({
    required String callerId,
    required String payload,
    required String title,
    required String body,
    required String publicTitle,
    required int count,
    required bool silent,
  }) =>
      _invoke<void>('showMissed', {
        'callerId': callerId,
        'payload': payload,
        'title': title,
        'body': body,
        'publicTitle': publicTitle,
        'count': count,
        'silent': silent,
      });

  Future<void> clearMissed() => _invoke<void>('clearMissed');

  Future<void> showPlanReminder({
    required String planId,
    required String payload,
    required String title,
    required String body,
    required Duration timeout,
  }) =>
      _invoke<void>('showPlanReminder', {
        'planId': planId,
        'payload': payload,
        'title': title,
        'body': body,
        'timeoutMs': timeout.inMilliseconds,
      });

  /// Sign-out: every call notification goes and any call service stops.
  Future<void> clearAll() => _invoke<void>('clearAll');

  /// The call notification that opened Silarah from closed, once.
  Future<CallEvent?> takeLaunchAction() async {
    final map = await _invoke<Map<Object?, Object?>>('takeLaunchAction');
    if (map == null) return null;
    final data = map.map((key, value) => MapEntry(key.toString(), value));
    return CallEvent('launch', data);
  }

  // -------------------------------------------------------------- live call

  /// Starts the call service and the ongoing notification (and the Telecom
  /// call on Android 8+). False when Android refuses or the microphone is
  /// not allowed.
  Future<bool> startCall({
    required String requestId,
    required String name,
    required bool outgoing,
    required String text,
    required String muteLabel,
    required String unmuteLabel,
    DateTime? connectedAt,
    bool muted = false,
  }) async =>
      await _invoke<bool>('startCall', {
        'requestId': requestId,
        'name': name,
        'title': name,
        'outgoing': outgoing,
        'text': text,
        'muteLabel': muteLabel,
        'unmuteLabel': unmuteLabel,
        'connectedAtMs': connectedAt?.millisecondsSinceEpoch ?? 0,
        'muted': muted,
      }) ??
      false;

  Future<void> updateCall({String? text, DateTime? connectedAt, bool? muted}) =>
      _invoke<void>('updateCall', {
        if (text != null) 'text': text,
        if (connectedAt != null) 'connectedAtMs': connectedAt.millisecondsSinceEpoch,
        if (muted != null) 'muted': muted,
      });

  Future<void> stopCall() => _invoke<void>('stopCall');

  /// Telecom has the call (Android 8+): audio routes go through it.
  Future<bool> telecomActive() async => await _invoke<bool>('telecomActive') ?? false;

  /// speaker | earpiece | bluetooth | wired. False when Telecom cannot.
  Future<bool> setAudioRoute(String route) async =>
      await _invoke<bool>('setAudioRoute', {'route': route}) ?? false;

  Future<void> resumeAfterPhoneCall() => _invoke<void>('resumeAfterPhoneCall');

  // ----------------------------------------------------------- device bits

  MicrophoneStatus _status(String? value) => switch (value) {
        'granted' => MicrophoneStatus.granted,
        'permanentlyDenied' => MicrophoneStatus.permanentlyDenied,
        _ => _supported ? MicrophoneStatus.denied : MicrophoneStatus.granted,
      };

  Future<MicrophoneStatus> microphoneStatus() async =>
      _status(await _invoke<String>('microphoneStatus'));

  Future<MicrophoneStatus> requestMicrophone() async =>
      _status(await _invoke<String>('requestMicrophone'));

  /// Shows Silarah over the lock screen and keeps the screen on, only while
  /// a call is ringing or live.
  Future<void> setCallWindow(bool active) => _invoke<void>('setCallWindow', {'active': active});

  /// Turns the screen off at the ear (earpiece only).
  Future<void> setProximity(bool enabled) => _invoke<void>('setProximity', {'enabled': enabled});

  /// Watches for a regular phone call during a Silarah call (`phoneCall` events).
  Future<void> startPhoneCallWatch() => _invoke<void>('startPhoneCallWatch');

  Future<void> stopPhoneCallWatch() => _invoke<void>('stopPhoneCallWatch');

  Future<bool> canUseFullScreenIntent() async => await _invoke<bool>('canUseFullScreenIntent') ?? true;

  Future<void> openFullScreenIntentSettings() => _invoke<bool>('openFullScreenIntentSettings');

  /// The incoming-call channel's settings, or the app's when notifications are off.
  Future<void> openNotificationSettings() => _invoke<bool>('openNotificationSettings');

  Future<String> manufacturer() async => await _invoke<String>('manufacturer') ?? '';

  Future<void> openAutoStartSettings() => _invoke<bool>('openAutoStartSettings');
}

/// Phone makers whose battery savers stop background pushes unless Silarah
/// is allowed to auto-start (spec 12.2.6).
bool needsAutoStartTip(String manufacturer) => const {
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'vivo',
      'realme',
      'oneplus',
      'iqoo',
    }.contains(manufacturer.toLowerCase());

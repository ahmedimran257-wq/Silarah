// The app's view of the native call module (packages/silarah_calls,
// docs/voice_calling_spec.md 12.1). CallController talks to this class so a
// test can swap it.
import 'dart:async';

import 'package:silarah_calls/silarah_calls.dart';

export 'package:silarah_calls/silarah_calls.dart' show CallEvent, MicrophoneStatus, needsAutoStartTip;

class CallPlatform {
  CallPlatform();

  static final CallPlatform instance = CallPlatform();

  SilarahCalls get _native => SilarahCalls.instance;

  /// Notification buttons (Hang up, Mute), Telecom (hold, routes, hang up
  /// from a headset or the car) and the phone-call watcher.
  Stream<CallEvent> get events => _native.events;

  /// The call notification that opened Silarah from closed, once.
  Future<CallEvent?> takeLaunchAction() => _native.takeLaunchAction();

  Future<MicrophoneStatus> microphoneStatus() => _native.microphoneStatus();

  Future<MicrophoneStatus> requestMicrophone() => _native.requestMicrophone();

  /// Android 12+ without the nearby-devices permission (Bluetooth headsets).
  Future<bool> bluetoothNeeded() => _native.bluetoothNeeded();

  Future<void> setCallWindow(bool active) => _native.setCallWindow(active);

  Future<void> setProximity(bool enabled) => _native.setProximity(enabled);

  Future<bool> startCall({
    required String requestId,
    required String name,
    required bool outgoing,
    required String text,
    required String muteLabel,
    required String unmuteLabel,
    DateTime? connectedAt,
    bool muted = false,
  }) =>
      _native.startCall(
        requestId: requestId,
        name: name,
        outgoing: outgoing,
        text: text,
        muteLabel: muteLabel,
        unmuteLabel: unmuteLabel,
        connectedAt: connectedAt,
        muted: muted,
      );

  Future<void> updateCall({String? text, DateTime? connectedAt, bool? muted}) =>
      _native.updateCall(text: text, connectedAt: connectedAt, muted: muted);

  Future<void> stopCall() => _native.stopCall();

  Future<bool> telecomActive() => _native.telecomActive();

  Future<bool> setAudioRoute(String route) => _native.setAudioRoute(route);

  Future<void> resumeAfterPhoneCall() => _native.resumeAfterPhoneCall();

  Future<void> callConnected() => _native.callConnected();

  Future<void> playTone(String kind) => _native.playTone(kind);

  Future<void> stopTone() => _native.stopTone();

  Future<void> startPhoneCallWatch() => _native.startPhoneCallWatch();

  Future<void> stopPhoneCallWatch() => _native.stopPhoneCallWatch();

  Future<bool> canUseFullScreenIntent() => _native.canUseFullScreenIntent();

  Future<void> openFullScreenIntentSettings() => _native.openFullScreenIntentSettings();

  Future<void> openNotificationSettings() => _native.openNotificationSettings();

  Future<bool> canRing() => _native.canRing();

  Future<String> manufacturer() => _native.manufacturer();

  Future<void> openAutoStartSettings() => _native.openAutoStartSettings();
}

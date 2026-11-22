// Native calling helpers (android/app/src/main/kotlin/.../CallPlatformChannel.kt).
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MicrophoneStatus { granted, denied, permanentlyDenied }

class CallPlatform {
  CallPlatform._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }
  static final CallPlatform instance = CallPlatform._();

  static const _channel = MethodChannel('com.silarah.app/calls');

  /// `true` when another app (a regular phone call) took the audio, `false`
  /// when it came back.
  final StreamController<bool> _audioInterrupted =
      StreamController<bool>.broadcast();
  Stream<bool> get audioInterrupted => _audioInterrupted.stream;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'audioFocusChanged') {
      final state = (call.arguments as Map?)?['state'];
      if (state == 'loss') _audioInterrupted.add(true);
      if (state == 'gain') _audioInterrupted.add(false);
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      debugPrint('[CallPlatform] $method failed: ${error.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

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
  Future<void> setCallWindow(bool active) =>
      _invoke<void>('setCallWindow', {'active': active});

  /// Turns the screen off at the ear (earpiece only).
  Future<void> setProximity(bool enabled) =>
      _invoke<void>('setProximity', {'enabled': enabled});

  Future<bool> startCallService({required String title, required String text}) async =>
      await _invoke<bool>('startCallService', {'title': title, 'text': text}) ??
      false;

  Future<void> stopCallService() => _invoke<void>('stopCallService');

  Future<bool> requestAudioFocus() async =>
      await _invoke<bool>('requestAudioFocus') ?? false;

  Future<void> abandonAudioFocus() => _invoke<void>('abandonAudioFocus');

  Future<bool> canUseFullScreenIntent() async =>
      await _invoke<bool>('canUseFullScreenIntent') ?? true;

  Future<void> openFullScreenIntentSettings() =>
      _invoke<void>('openFullScreenIntentSettings');

  Future<String> manufacturer() async =>
      await _invoke<String>('manufacturer') ?? '';

  Future<void> openAutoStartSettings() => _invoke<bool>('openAutoStartSettings');
}

/// Phone makers whose battery savers stop background pushes unless Silarah
/// is allowed to auto-start (spec 8).
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

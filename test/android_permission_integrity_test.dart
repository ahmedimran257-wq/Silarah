import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('release manifest removes unused sensitive transitive permissions', () {
    expect(
        manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
    for (final permission in <String>[
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_PHONE_STATE',
    ]) {
      final declaration = RegExp(
        '<uses-permission\\s+'
        'android:name="$permission"\\s+'
        'tools:node="remove"\\s*/>',
        multiLine: true,
      );
      expect(
        manifest,
        matches(declaration),
        reason: '$permission must stay out of the merged release manifest.',
      );
    }
  });

  test('voice calls declare the microphone, and only what calls need', () {
    // docs/voice_calling_spec.md 8: RECORD_AUDIO is restored for calls.
    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.RECORD_AUDIO" />'),
    );
    expect(manifest, isNot(contains('RECORD_AUDIO"\n        tools:node="remove"')));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'),
    );
    expect(manifest, contains('android.permission.USE_FULL_SCREEN_INTENT'));
    // A regular phone call is detected through audio focus, never phone state.
    for (final unused in <String>[
      'FOREGROUND_SERVICE_CAMERA',
      'FOREGROUND_SERVICE_PHONE_CALL',
      'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'FOREGROUND_SERVICE_MEDIA_PROJECTION',
      'MANAGE_OWN_CALLS',
    ]) {
      expect(manifest, isNot(contains('android.permission.$unused"')),
          reason: '$unused needs its own Play declaration and is not used.');
    }
    // The call's foreground service is microphone-only.
    expect(
      manifest,
      matches(RegExp(
        r'android:name="\.CallForegroundService"\s+'
        r'android:exported="false"\s+'
        r'android:foregroundServiceType="microphone"',
      )),
    );
    // Stream's ringing needs singleInstance; Silarah rings itself and keeps
    // singleTop for auth links, the photo picker and Play billing.
    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(manifest, isNot(contains('singleInstance')));
    // The whole app is never shown over the lock screen; only a live call
    // is, from code, while it rings or runs.
    expect(manifest, isNot(contains('android:showWhenLocked')));
  });

  test('calling uses the Stream core client without Stream push or services', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('stream_video: 1.6.0'));
    expect(pubspec, isNot(contains('stream_video_push_notification')));
    expect(pubspec, isNot(contains('stream_video_flutter')));
  });
}

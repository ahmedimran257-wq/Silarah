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

  test('no background location foreground service ships', () {
    // geolocator's GeolocatorLocationService (foregroundServiceType
    // "location") is unused: the app reads one coarse position in the
    // foreground. Keeping it would put an undeclared location FGS in the
    // merged manifest (Play foreground service policy).
    expect(
      manifest,
      matches(RegExp(
        r'<service\s+'
        r'android:name="com\.baseflow\.geolocator\.GeolocatorLocationService"\s+'
        r'tools:node="remove"\s*/>',
      )),
    );
    expect(manifest, isNot(contains('FOREGROUND_SERVICE_LOCATION')));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
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
    // Self-managed calls through Jetpack Core-Telecom (spec 12.1): the
    // phone-call service type and own-call management, each with its Play
    // declaration. A regular phone call is detected through Telecom's hold
    // and the audio mode, never phone state.
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_PHONE_CALL"'));
    expect(manifest, contains('android.permission.MANAGE_OWN_CALLS"'));
    for (final unused in <String>[
      'FOREGROUND_SERVICE_CAMERA',
      'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'FOREGROUND_SERVICE_MEDIA_PROJECTION',
    ]) {
      expect(manifest, isNot(contains('android.permission.$unused"')),
          reason: '$unused needs its own Play declaration and is not used.');
    }
    // The call's foreground service lives in the call module: microphone,
    // and phone call only while Telecom holds the call.
    final module = File('packages/silarah_calls/android/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      module,
      matches(RegExp(
        r'android:name="com\.silarah\.calls\.CallService"\s+'
        r'android:exported="false"\s+'
        r'android:foregroundServiceType="phoneCall\|microphone"',
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

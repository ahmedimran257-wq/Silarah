// Call audio rules (docs/voice_calling_spec.md 12.9): where the call's audio
// goes when headsets come and go, and which tone a call ends with. The tones
// themselves and the routing on a real phone are device gates.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/widgets/call_microphone_gate.dart';
import 'package:silarah/l10n/calling_ui_copy.dart';

void main() {
  const earpiece = CallAudioRoute.earpiece;
  const speaker = CallAudioRoute.speaker;
  const bluetooth = CallAudioRoute.bluetooth;
  const wired = CallAudioRoute.wired;

  group('audio route follows headsets like a phone call', () {
    test('a Bluetooth headset that connects takes the call, even from the speaker', () {
      expect(
        nextAudioRoute(current: speaker, before: {earpiece, speaker}, now: {earpiece, speaker, bluetooth}),
        bluetooth,
      );
    });

    test('wired headphones plugged in take the call', () {
      expect(nextAudioRoute(current: earpiece, before: {earpiece, speaker}, now: {speaker, wired}), wired);
    });

    test('the member\'s choice stays while that route is there', () {
      expect(
        nextAudioRoute(current: speaker, before: {earpiece, speaker, bluetooth}, now: {earpiece, speaker, bluetooth}),
        speaker,
      );
    });

    test('the headset goes: back to the earpiece, never the speaker by surprise', () {
      expect(nextAudioRoute(current: bluetooth, before: {earpiece, speaker, bluetooth}, now: {earpiece, speaker}),
          earpiece);
      expect(nextAudioRoute(current: wired, before: {speaker, wired}, now: {earpiece, speaker}), earpiece);
    });

    test('Bluetooth goes while wired is in: wired', () {
      expect(nextAudioRoute(current: bluetooth, before: {speaker, wired, bluetooth}, now: {speaker, wired}), wired);
    });
  });

  group('a call ends with one tone', () {
    test('a connected call: the end tone, for both members, however it ended', () {
      for (final copy in [CallEndCopy.ended, CallEndCopy.timeUp]) {
        expect(callEndTone(copy: copy, connected: true, ringingOut: false), 'ended', reason: copy);
      }
    });

    test('a call that rang out and did not connect: one neutral tone, never why', () {
      expect(callEndTone(copy: CallEndCopy.notAnswered, connected: false, ringingOut: true), 'not_reached');
      expect(callEndTone(copy: CallEndCopy.ended, connected: false, ringingOut: true), 'not_reached');
    });

    test('the caller hanging up while it rings hears the end tone, not "not reached"', () {
      expect(callEndTone(copy: CallEndCopy.ended, connected: false, ringingOut: true, endedByMember: true), 'ended');
    });

    test('a failure has its own tone', () {
      expect(callEndTone(copy: CallEndCopy.failed, connected: false, ringingOut: true), 'failed');
      expect(callEndTone(copy: CallEndCopy.failed, connected: true, ringingOut: false), 'failed');
    });

    test('a ring the member did not answer ends silently', () {
      for (final copy in [CallEndCopy.missed, CallEndCopy.declined, CallEndCopy.answeredElsewhere]) {
        expect(callEndTone(copy: copy, connected: false, ringingOut: false), isNull, reason: copy);
      }
    });
  });

  group('wiring', () {
    final controller = File('lib/features/calls/call_controller.dart').readAsStringSync();
    final native = File('packages/silarah_calls/android/src/main/kotlin/com/silarah/calls/CallTones.kt')
        .readAsStringSync();

    test('no forced earpiece when a call connects (it kept calls off Bluetooth)', () {
      expect(controller, isNot(contains('setRoute(CallAudioRoute.earpiece')));
      expect(controller, contains('call.state.value.audioOutputDevice'));
    });

    test('the ringback starts with the ring and stops when answered or ended', () {
      expect(controller, contains("playTone('ringback')"));
      expect(RegExp(r"case 'active':\s+_pollTimer\?\.cancel\(\);\s+await _platform\.stopTone\(\);").hasMatch(controller),
          isTrue);
      expect(controller, contains('await _platform.stopTone();\n    // While the call'));
    });

    test('the caller ends the call when the paid time is over, not 30 s later', () {
      final tick = controller.substring(controller.indexOf('void _onTick('));
      expect(tick.indexOf('secondsLeftNow <= 0'), lessThan(tick.indexOf('maxDurationSeconds + 5')));
      expect(tick, contains('hangUp(copy: CallEndCopy.timeUp)'));
      expect(tick, contains('isCaller && !extending'));
    });

    test('a finished call puts the phone back in normal audio mode (Android 10: rings vibrate again)', () {
      final service = File('packages/silarah_calls/android/src/main/kotlin/com/silarah/calls/CallService.kt')
          .readAsStringSync();
      expect(service, contains('CallTones.endCallAudio(this)'));
      expect(native, contains('if (manager.mode == AudioManager.MODE_IN_COMMUNICATION)'));
      expect(native, isNot(contains('MODE_IN_CALL')), reason: 'a regular phone call is never touched');
      // The engine's audio session ends first (it would put the mode back on
      // regaining focus); the reset runs after it on the main thread.
      final end = native.substring(native.indexOf('fun endCallAudio('));
      expect(end.indexOf('AudioSwitchManager.instance?.stop()'), lessThan(end.indexOf('main.post')));
      final telecom = File('packages/silarah_calls/android/src/main/kotlin/com/silarah/calls/CallTelecom.kt')
          .readAsStringSync();
      expect(telecom, contains('if (result is CallControlResult.Success) setActive()'),
          reason: 'an answered call is active in Telecom, not ringing');
    });

    test('a ring wakes a sleeping screen unless Do Not Disturb or the full-screen setting says no', () {
      final notifier = File('packages/silarah_calls/android/src/main/kotlin/com/silarah/calls/CallNotifier.kt')
          .readAsStringSync();
      expect(notifier, contains('if (!silent) wakeScreenForRing(context)'));
      expect(notifier, contains('INTERRUPTION_FILTER_ALL'));
      expect(notifier, contains('canUseFullScreenIntent()'));
    });

    test('a regular phone call holds the call both ways: microphone off and the other member silent', () {
      final hold = controller.substring(controller.indexOf('void _onInterrupted('));
      expect(hold, contains('call.setMicrophoneEnabled(enabled: !interrupted && !muted)'));
      expect(hold, contains('_setOtherMemberAudio(call, heard: !interrupted)'));
      expect(controller, contains('if (onHold && held != null) _setOtherMemberAudio(held, heard: false)'),
          reason: 'a track rebuilt during the hold stays silent');
    });

    test('Back during a call leaves the call screen; the call goes on', () {
      final screen = File('lib/features/calls/screens/call_screen.dart').readAsStringSync();
      expect(screen, contains('CallReturnBarHost.showsFor(_call, screenOpen: false)'));
      expect(screen, contains('canPop: phase == CallPhase.ended || phase == CallPhase.idle'));
    });

    test('tones play on the voice-call stream (call route and volume)', () {
      expect(native, contains('ToneGenerator(AudioManager.STREAM_VOICE_CALL'));
    });
  });

  test('the Bluetooth rationale exists in every language', () {
    for (final code in callingUiCopy.keys) {
      for (final key in [bluetoothRationaleCopy, 'Use your Bluetooth headset']) {
        expect(callingUiCopy[code]![key], isNotNull, reason: '$code: $key');
      }
    }
  });
}

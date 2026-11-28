package com.silarah.calls

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper

/**
 * Call tones on the voice-call stream (docs/voice_calling_spec.md 12.9), so
 * they follow the call's route (earpiece, Bluetooth, wired, speaker) and the
 * in-call volume, like a phone call's:
 *
 *  - ringback: while the other phone rings, until answered or ended;
 *  - connected / ended: a short beep when the call connects or ends;
 *  - not_reached: the call did not connect (one neutral tone, whatever the
 *    reason: the caller is never told why, spec 12.4);
 *  - failed: the network or the service failed;
 *  - reconnecting / warning: the connection dropped, or time is running out.
 *
 * One tone at a time. Before the call's audio engine runs (ringing), the
 * audio mode is set to communication for the tone only if nobody else
 * (Telecom, the engine) has set it, and put back afterwards.
 */
internal object CallTones {
    private data class Tone(val type: Int, val durationMs: Int, val volume: Int)

    private val tones = mapOf(
        "ringback" to Tone(ToneGenerator.TONE_SUP_RINGTONE, -1, 70),
        "connected" to Tone(ToneGenerator.TONE_PROP_BEEP, 150, 60),
        "ended" to Tone(ToneGenerator.TONE_PROP_PROMPT, 400, 70),
        "not_reached" to Tone(ToneGenerator.TONE_SUP_BUSY, 1500, 70),
        "failed" to Tone(ToneGenerator.TONE_SUP_ERROR, 1200, 70),
        "reconnecting" to Tone(ToneGenerator.TONE_PROP_BEEP2, 300, 60),
        "warning" to Tone(ToneGenerator.TONE_PROP_BEEP2, 300, 70),
    )

    private val main = Handler(Looper.getMainLooper())
    private var generator: ToneGenerator? = null
    private var restoreMode: Int? = null
    private var audio: AudioManager? = null
    private val release = Runnable { stop() }

    /** Starts [kind]; the time it lasts in ms (0 unknown kind, -1 until [stop]). */
    @Synchronized
    fun play(context: Context, kind: String): Int {
        val tone = tones[kind] ?: return 0
        stop()
        val manager = context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audio = manager
        if (restoreMode == null && manager.mode == AudioManager.MODE_NORMAL) {
            restoreMode = AudioManager.MODE_NORMAL
            try {
                manager.mode = AudioManager.MODE_IN_COMMUNICATION
            } catch (_: SecurityException) {
                restoreMode = null
            }
        }
        generator = try {
            ToneGenerator(AudioManager.STREAM_VOICE_CALL, tone.volume)
        } catch (_: RuntimeException) {
            // No tone hardware free right now: the call goes on without it.
            null
        }
        generator?.startTone(tone.type, tone.durationMs)
        if (tone.durationMs > 0) main.postDelayed(release, tone.durationMs + 50L)
        return tone.durationMs
    }

    @Synchronized
    fun stop() {
        main.removeCallbacks(release)
        generator?.let {
            it.stopTone()
            it.release()
        }
        generator = null
        // While the call service runs, the call still needs the mode (the
        // engine takes it over); the service gives it back when it stops.
        if (!CallService.running) releaseMode()
    }

    /**
     * The call is over: the phone leaves communication mode. On Android 10
     * and older an app's mode stays set until that app resets it, and the
     * call's audio engine does not always do so; the phone then treats every
     * later ring as arriving during a call (no vibration, no ringtone).
     * Only communication mode (internet calls) is touched, never a regular
     * phone call's mode.
     */
    @Synchronized
    fun endCallAudio(context: Context) {
        releaseMode()
        // The audio engine keeps its audio session (and audio focus) until
        // its own clean-up, which can come after this when the other member
        // hung up; regaining focus meanwhile it put communication mode back
        // (seen on Android 10). End its session now: it gives up focus and
        // restores the mode it found. Its later clean-up is then a no-op.
        try {
            io.getstream.webrtc.flutter.audio.AudioSwitchManager.instance?.stop()
        } catch (_: Throwable) {
            // Engine not present: nothing of its to end.
        }
        val manager = context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // The engine's stop runs first on the main thread (queued at the
        // front); this runs after it, so the call ends in normal mode.
        main.post {
            if (manager.mode == AudioManager.MODE_IN_COMMUNICATION) {
                try {
                    manager.mode = AudioManager.MODE_NORMAL
                } catch (_: SecurityException) {
                }
            }
        }
    }

    /** Puts back the audio mode a tone changed, if nobody changed it since. */
    @Synchronized
    fun releaseMode() {
        val mode = restoreMode ?: return
        restoreMode = null
        if (audio?.mode == AudioManager.MODE_IN_COMMUNICATION) {
            try {
                audio?.mode = mode
            } catch (_: SecurityException) {
            }
        }
    }
}

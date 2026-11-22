package com.silarah.calls

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.WindowManager
import androidx.core.content.ContextCompat

/**
 * Shows Silarah over the lock screen, turns the screen on and keeps it on,
 * only while a call is ringing or live. Android applies "turn the screen on"
 * when the activity is next resumed, so a ring must set it as the ring
 * opens Silarah (before it is resumed), not once Flutter has started.
 */
internal object CallWindow {
    fun apply(activity: Activity, active: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(active)
            activity.setTurnScreenOn(active)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (active) activity.window.addFlags(flags) else activity.window.clearFlags(flags)
        }
        if (active) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /** The ring (full screen, tap or Answer) opened Silarah. */
    fun isRingLaunch(intent: Intent?): Boolean =
        intent?.action == CallNotifier.ACTION_RING || intent?.action == CallNotifier.ACTION_ANSWER
}

/** Screen off at the ear while the call uses the earpiece. */
internal class ProximityLock(context: Context) {
    private val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private var lock: PowerManager.WakeLock? = null

    fun set(enabled: Boolean) {
        if (enabled) {
            if (lock?.isHeld == true) return
            if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
            lock = power.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "silarah:call-proximity")
                .apply {
                    setReferenceCounted(false)
                    acquire(4 * 60 * 60 * 1000L)
                }
        } else {
            lock?.let { if (it.isHeld) it.release() }
            lock = null
        }
    }
}

/**
 * A regular phone call, seen through the audio mode, never through
 * phone-state access: the phone app switches to MODE_IN_CALL while a
 * cellular call is connected, whereas a Silarah call runs in
 * MODE_IN_COMMUNICATION. (Audio focus cannot be used: the call's own audio
 * engine takes focus inside this app.) With Telecom (Android 8+) the hold
 * also arrives from Telecom; this watcher covers Android 7 and any phone
 * whose Telecom link failed.
 */
internal class PhoneCallWatcher(
    private val context: Context,
    private val onChange: (Boolean) -> Unit,
) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var watching = false
    private var active = false
    private var listener: Any? = null
    private val poll = object : Runnable {
        override fun run() {
            if (!watching) return
            onMode(audio.mode)
            handler.postDelayed(this, 1000)
        }
    }

    private fun onMode(mode: Int) {
        val now = mode == AudioManager.MODE_IN_CALL
        if (now == active) return
        active = now
        onChange(now)
    }

    fun start() {
        if (watching) return
        watching = true
        active = audio.mode == AudioManager.MODE_IN_CALL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val modeListener = AudioManager.OnModeChangedListener { mode -> onMode(mode) }
            audio.addOnModeChangedListener(ContextCompat.getMainExecutor(context), modeListener)
            listener = modeListener
        } else {
            handler.post(poll)
        }
    }

    fun stop() {
        if (!watching) return
        watching = false
        active = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (listener as? AudioManager.OnModeChangedListener)?.let { audio.removeOnModeChangedListener(it) }
            listener = null
        } else {
            handler.removeCallbacks(poll)
        }
    }
}

package com.silarah.app

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Native pieces of in-app calling that Flutter cannot do itself
 * (voice_calling_spec.md 8): microphone permission, the microphone
 * foreground service, showing the call over the lock screen only while a
 * call is ringing or on, proximity screen-off at the ear, a regular phone
 * call putting the Silarah call on hold, the full-screen-intent
 * setting (Android 14+) and the auto-start screen of some phone makers.
 */
class CallPlatformChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, NAME)
    private var pendingPermission: MethodChannel.Result? = null
    private var proximityLock: PowerManager.WakeLock? = null
    private val audioManager =
        activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // A regular phone call is seen through the audio mode, never through
    // phone-state access: the phone app switches to MODE_IN_CALL while a
    // cellular call is connected, whereas a Silarah call runs in
    // MODE_IN_COMMUNICATION. (Audio focus cannot be used: the call's own
    // audio engine takes focus inside this app.)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var watchingPhoneCalls = false
    private var phoneCallActive = false
    private var modeListener: Any? = null
    private val modePoll = object : Runnable {
        override fun run() {
            if (!watchingPhoneCalls) return
            onAudioMode(audioManager.mode)
            mainHandler.postDelayed(this, 1000)
        }
    }

    private fun onAudioMode(mode: Int) {
        val active = mode == AudioManager.MODE_IN_CALL
        if (active == phoneCallActive) return
        phoneCallActive = active
        channel.invokeMethod("phoneCallChanged", mapOf("active" to active))
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "microphoneStatus" -> result.success(microphoneStatus())
                "requestMicrophone" -> requestPermissions(result)
                "setCallWindow" -> {
                    setCallWindow(call.argument<Boolean>("active") == true)
                    result.success(null)
                }
                "setProximity" -> {
                    setProximity(call.argument<Boolean>("enabled") == true)
                    result.success(null)
                }
                "startCallService" -> {
                    if (microphoneStatus() != "granted") {
                        result.success(false)
                    } else {
                        result.success(
                            CallForegroundService.start(
                                activity.applicationContext,
                                call.argument<String>("title"),
                                call.argument<String>("text"),
                            ),
                        )
                    }
                }
                "stopCallService" -> {
                    CallForegroundService.stop(activity.applicationContext)
                    result.success(null)
                }
                "startPhoneCallWatch" -> {
                    startPhoneCallWatch()
                    result.success(null)
                }
                "stopPhoneCallWatch" -> {
                    stopPhoneCallWatch()
                    result.success(null)
                }
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                "openFullScreenIntentSettings" -> {
                    openFullScreenIntentSettings()
                    result.success(null)
                }
                "manufacturer" -> result.success(Build.MANUFACTURER.lowercase())
                "openAutoStartSettings" -> result.success(openAutoStartSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun microphoneStatus(): String {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) return "granted"
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val asked = prefs.getBoolean(KEY_ASKED, false)
        return if (asked &&
            !ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.RECORD_AUDIO)
        ) "permanentlyDenied" else "denied"
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (microphoneStatus() == "granted" && bluetoothGrantedOrNotNeeded()) {
            result.success("granted")
            return
        }
        pendingPermission?.success(microphoneStatus())
        pendingPermission = result
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ASKED, true).apply()
        val wanted = mutableListOf(Manifest.permission.RECORD_AUDIO)
        // Android 12+ needs this to route the call to a Bluetooth headset.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            wanted.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        ActivityCompat.requestPermissions(activity, wanted.toTypedArray(), REQUEST_CODE)
    }

    private fun bluetoothGrantedOrNotNeeded(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(microphoneStatus())
        pendingPermission = null
        return true
    }

    private fun setCallWindow(active: Boolean) = applyCallWindow(activity, active)

    private fun setProximity(enabled: Boolean) {
        val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (enabled) {
            if (proximityLock?.isHeld == true) return
            if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
            proximityLock = power.newWakeLock(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                "silarah:call-proximity",
            ).apply {
                setReferenceCounted(false)
                // Never longer than the longest single hold plus margin.
                acquire(65 * 60 * 1000L)
            }
        } else {
            proximityLock?.let {
                if (it.isHeld) it.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
            }
            proximityLock = null
        }
    }

    private fun startPhoneCallWatch() {
        if (watchingPhoneCalls) return
        watchingPhoneCalls = true
        phoneCallActive = audioManager.mode == AudioManager.MODE_IN_CALL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val listener = AudioManager.OnModeChangedListener { mode -> onAudioMode(mode) }
            audioManager.addOnModeChangedListener(ContextCompat.getMainExecutor(activity), listener)
            modeListener = listener
        } else {
            mainHandler.post(modePoll)
        }
    }

    private fun stopPhoneCallWatch() {
        if (!watchingPhoneCalls) return
        watchingPhoneCalls = false
        phoneCallActive = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (modeListener as? AudioManager.OnModeChangedListener)?.let {
                audioManager.removeOnModeChangedListener(it)
            }
            modeListener = null
        } else {
            mainHandler.removeCallbacks(modePoll)
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${activity.packageName}"))
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
        }
        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /** Best effort: these screens move between OS versions. */
    private fun openAutoStartSettings(): Boolean {
        val candidates = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        )
        for (component in candidates) {
            val intent = Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (activity.packageManager.resolveActivity(intent, 0) != null) {
                try {
                    activity.startActivity(intent)
                    return true
                } catch (_: Exception) {
                    // Try the next one.
                }
            }
        }
        activity.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        return false
    }

    fun dispose() {
        setProximity(false)
        stopPhoneCallWatch()
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val NAME = "com.silarah.app/calls"
        private const val REQUEST_CODE = 41_010
        private const val PREFS = "silarah_call_permissions"
        private const val KEY_ASKED = "microphone_asked"
    }
}

/**
 * Shows Silarah over the lock screen, turns the screen on and keeps it on,
 * only while a call is ringing or live. Android applies "turn the screen on"
 * when the activity is next resumed, so a ring must set it before Silarah is
 * shown (see [isIncomingRingLaunch]), not once Flutter has started.
 */
internal fun applyCallWindow(activity: Activity, active: Boolean) {
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

/**
 * True when Android opened Silarah for the incoming-call notification (its
 * full-screen ring on a locked or sleeping phone, a tap, or Answer). The
 * notification plugin launches with this action and the ring's payload, the
 * same JSON the Dart side reads (call_notifications.dart, IncomingCallPush).
 * Flutter then owns the window: it keeps it for the ring or releases it when
 * the ring is no longer for this phone.
 */
internal fun isIncomingRingLaunch(intent: Intent?): Boolean {
    if (intent?.action != "SELECT_NOTIFICATION") return false
    val payload = intent.getStringExtra("payload") ?: return false
    return try {
        val ring = JSONObject(payload)
        listOf("request_id", "for_user", "expires_at").all { ring.optString(it).isNotEmpty() }
    } catch (_: org.json.JSONException) {
        false
    }
}

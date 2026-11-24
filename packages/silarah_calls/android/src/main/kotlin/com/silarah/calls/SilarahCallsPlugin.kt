package com.silarah.calls

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Silarah's call module (docs/voice_calling_spec.md 12.1). One instance per
 * Flutter engine: the app's engine (with the activity) and the FCM
 * background isolate's engine (notifications only). Events from
 * notification buttons and Telecom go to the app's engine.
 */
class SilarahCallsPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingLaunch: Map<String, Any?>? = null
    private var proximity: ProximityLock? = null
    private var phoneCalls: PhoneCallWatcher? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        CallNotifier.ensureChannels(context)
        instances.add(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        instances.remove(this)
        phoneCalls?.stop()
        proximity?.set(false)
        channel.setMethodCallHandler(null)
    }

    // ---------------------------------------------------------------- activity

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
        // Attached during the activity's onCreate, before it is resumed: a
        // ring that opened Silarah lights the screen and shows over the lock.
        consumeLaunch(binding.activity.intent, initial = true)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        binding.addRequestPermissionsResultListener(this)
        binding.activity.application.registerActivityLifecycleCallbacks(screenWatch)
    }

    private fun detach() {
        binding?.activity?.application?.unregisterActivityLifecycleCallbacks(screenWatch)
        binding?.removeOnNewIntentListener(this)
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
        proximity?.set(false)
        proximity = null
    }

    // Why Silarah's screen last went away: the member went to another app
    // (true), or the phone locked over it: the screen turned off, or the lock
    // screen came back over Silarah after a ring (false). A ring that brings
    // Silarah back from another app returns the member there once the call
    // is over, like a phone call (spec 12.1).
    private var leftForAnotherApp = false

    private val screenWatch = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityStopped(stopped: Activity) {
            if (stopped !== activity) return
            val power = stopped.getSystemService(Context.POWER_SERVICE) as PowerManager
            val keyguard = stopped.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            leftForAnotherApp = power.isInteractive && !keyguard.isKeyguardLocked
        }

        override fun onActivityResumed(resumed: Activity) {
            if (resumed === activity) leftForAnotherApp = false
        }

        override fun onActivityCreated(created: Activity, state: Bundle?) {}
        override fun onActivityStarted(started: Activity) {}
        override fun onActivityPaused(paused: Activity) {}
        override fun onActivitySaveInstanceState(saved: Activity, state: Bundle) {}
        override fun onActivityDestroyed(destroyed: Activity) {}
    }

    // Delivered before the activity is resumed again.
    override fun onNewIntent(intent: Intent): Boolean {
        consumeLaunch(intent, initial = false)
        return false
    }

    private fun consumeLaunch(intent: Intent?, initial: Boolean) {
        val action = intent?.action ?: return
        if (action !in LAUNCH_ACTIONS) return
        if (CallWindow.isRingLaunch(intent)) activity?.let { CallWindow.apply(it, true) }
        val launch = mapOf(
            "action" to action.substringAfterLast('.').lowercase(),
            "payload" to intent.getStringExtra(CallNotifier.EXTRA_PAYLOAD),
            // Opened from closed, or from behind another app.
            "fromAnotherApp" to (initial || leftForAnotherApp),
        )
        // Recreating the activity must not replay the same launch.
        intent.action = Intent.ACTION_MAIN
        if (initial) {
            pendingLaunch = launch
        } else {
            channel.invokeMethod("event", launch + ("type" to "launch"))
        }
    }

    // ------------------------------------------------------------------ calls

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
        when (call.method) {
            "canRing" -> result.success(CallNotifier.canRing(context))
            "showIncoming" -> {
                CallNotifier.showIncoming(context, args)
                result.success(null)
            }
            "cancelIncoming" -> {
                CallNotifier.cancelIncoming(context, args["requestId"] as? String ?: "")
                result.success(null)
            }
            "showMissed" -> {
                CallNotifier.showMissed(context, args)
                result.success(null)
            }
            "clearMissed" -> {
                CallNotifier.clearMissed(context)
                result.success(null)
            }
            "showPlanReminder" -> {
                CallNotifier.showPlanReminder(context, args)
                result.success(null)
            }
            "clearAll" -> {
                CallNotifier.clearAll(context)
                CallService.stop(context)
                result.success(null)
            }
            "takeLaunchAction" -> {
                result.success(pendingLaunch)
                pendingLaunch = null
            }
            "startCall" -> result.success(
                microphoneStatus() == "granted" && CallService.start(context, args),
            )
            "updateCall" -> {
                CallService.update(args)
                result.success(null)
            }
            "stopCall" -> {
                CallService.stop(context)
                result.success(null)
            }
            "telecomActive" -> result.success(CallService.telecomActive)
            "callConnected" -> {
                CallService.markConnected()
                result.success(null)
            }
            "playTone" -> {
                // Answers when the tone is over, so the app can wait for an
                // end tone before it lets the call's audio go.
                val duration = CallTones.play(context, args["kind"] as? String ?: "")
                if (duration > 0) main.postDelayed({ result.success(null) }, duration.toLong()) else result.success(null)
            }
            "stopTone" -> {
                CallTones.stop()
                result.success(null)
            }
            "setAudioRoute" -> result.success(CallService.requestRoute(args["route"] as? String ?: ""))
            "resumeAfterPhoneCall" -> {
                CallService.resumeAfterPhoneCall()
                result.success(null)
            }
            "microphoneStatus" -> result.success(microphoneStatus())
            "bluetoothNeeded" -> result.success(!bluetoothGrantedOrNotNeeded())
            "requestMicrophone" -> requestMicrophone(result)
            "setCallWindow" -> {
                activity?.let { CallWindow.apply(it, args["active"] == true) }
                result.success(null)
            }
            "isDeviceLocked" -> {
                val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                result.success(keyguard.isKeyguardLocked)
            }
            // Back to where the member was: the lock screen or the other app.
            "moveToBack" -> result.success(activity?.moveTaskToBack(true) ?: false)
            "setProximity" -> {
                val current = activity
                if (current != null) {
                    val lock = proximity ?: ProximityLock(current).also { proximity = it }
                    lock.set(args["enabled"] == true)
                }
                result.success(null)
            }
            "startPhoneCallWatch" -> {
                val watcher = phoneCalls ?: PhoneCallWatcher(context) { active ->
                    channel.invokeMethod("event", mapOf("type" to "phoneCall", "active" to active))
                }.also { phoneCalls = it }
                watcher.start()
                result.success(null)
            }
            "stopPhoneCallWatch" -> {
                phoneCalls?.stop()
                result.success(null)
            }
            "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
            "openFullScreenIntentSettings" -> result.success(openFullScreenIntentSettings())
            "openNotificationSettings" -> result.success(openNotificationSettings())
            "manufacturer" -> result.success(Build.MANUFACTURER.lowercase())
            "openAutoStartSettings" -> result.success(openAutoStartSettings())
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------- microphone

    private fun microphoneStatus(): String {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) return "granted"
        val current = activity ?: return "denied"
        val asked = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ASKED, false)
        return if (asked &&
            !ActivityCompat.shouldShowRequestPermissionRationale(current, Manifest.permission.RECORD_AUDIO)
        ) "permanentlyDenied" else "denied"
    }

    private fun requestMicrophone(result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.success(microphoneStatus())
            return
        }
        if (microphoneStatus() == "granted" && bluetoothGrantedOrNotNeeded()) {
            result.success("granted")
            return
        }
        pendingPermission?.success(microphoneStatus())
        pendingPermission = result
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ASKED, true).apply()
        val wanted = mutableListOf(Manifest.permission.RECORD_AUDIO)
        // Android 12+ needs this to route the call to a Bluetooth headset.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) wanted.add(Manifest.permission.BLUETOOTH_CONNECT)
        ActivityCompat.requestPermissions(current, wanted.toTypedArray(), REQUEST_CODE)
    }

    private fun bluetoothGrantedOrNotNeeded(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(microphoneStatus())
        pendingPermission = null
        return true
    }

    // ---------------------------------------------------------------- settings

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun startSettings(intent: Intent): Boolean = try {
        (activity ?: context).startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: Exception) {
        false
    }

    private fun appDetails() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))

    private fun openFullScreenIntentSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${context.packageName}"))
        } else {
            appDetails()
        }
        return startSettings(intent) || startSettings(appDetails())
    }

    /** The incoming-call channel's screen when notifications are on, else the app's. */
    private fun openNotificationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return startSettings(appDetails())
        val appOn = androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()
        val intent = if (appOn) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, CallNotifier.CHANNEL_INCOMING)
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
        return startSettings(intent) || startSettings(appDetails())
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
            val intent = Intent().setComponent(component)
            if (context.packageManager.resolveActivity(intent, 0) != null && startSettings(intent)) return true
        }
        startSettings(appDetails())
        return false
    }

    companion object {
        private const val CHANNEL = "com.silarah.calls"
        private const val REQUEST_CODE = 41_010
        private const val PREFS = "silarah_call_permissions"
        private const val KEY_ASKED = "microphone_asked"
        private val LAUNCH_ACTIONS = setOf(
            CallNotifier.ACTION_RING,
            CallNotifier.ACTION_ANSWER,
            CallNotifier.ACTION_OPEN_CALL,
            CallNotifier.ACTION_OPEN_CALLS,
        )

        private val instances = CopyOnWriteArraySet<SilarahCallsPlugin>()
        private val main = Handler(Looper.getMainLooper())

        /**
         * Sends an event to the app's engine (the one with the activity:
         * the call lives there). False when Silarah's screen is gone, so
         * the caller can clean up natively instead.
         */
        /** A volume key while the ring is on screen (MainActivity): silence it. */
        @JvmStatic
        fun onVolumeKey(context: Context): Boolean = CallNotifier.silenceIncoming(context)

        fun emit(type: String, data: Map<String, Any?>): Boolean {
            val target = instances.firstOrNull { it.activity != null } ?: return false
            val message = data + ("type" to type)
            if (Looper.myLooper() == Looper.getMainLooper()) {
                target.channel.invokeMethod("event", message)
            } else {
                main.post { target.channel.invokeMethod("event", message) }
            }
            return true
        }
    }
}

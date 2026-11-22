package com.silarah.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val lifecycleChannel = "com.silarah.app/app_lifecycle"
    private val platformActionsChannel = "com.silarah.app/platform_actions"
    private var callChannel: CallPlatformChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        createNotificationChannels()
        wakeForIncomingRing(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12 otherwise inserts its own icon fade between the
            // native surface and Flutter's reveal. Remove the system layer
            // atomically when Flutter reports its first composed frame.
            splashScreen.setOnExitAnimationListener { splashView ->
                splashView.remove()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        wakeForIncomingRing(intent)
    }

    /** A ring opening Silarah on a sleeping or locked phone must light the
     *  screen and show over the lock before Silarah is resumed. */
    private fun wakeForIncomingRing(intent: Intent?) {
        if (isIncomingRingLaunch(intent)) applyCallWindow(this, true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callChannel?.dispose()
        callChannel = CallPlatformChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            lifecycleChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "restartApp") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                result.error(
                    "restart_unavailable",
                    "Silarah's launcher activity could not be resolved.",
                    null,
                )
                return@setMethodCallHandler
            }

            result.success(true)
            launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
            startActivity(launchIntent)
            overridePendingTransition(0, 0)
            finishAffinity()
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            platformActionsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank()) {
                        result.error("invalid_share", "Nothing to share.", null)
                        return@setMethodCallHandler
                    }
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        call.argument<String>("subject")?.let {
                            putExtra(Intent.EXTRA_SUBJECT, it)
                        }
                    }
                    // A null title lets Android provide the chooser heading in
                    // the device language instead of forcing an English label.
                    startActivity(Intent.createChooser(sendIntent, null))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callChannel?.dispose()
        callChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        callChannel?.onPermissionResult(requestCode)
    }

    // Android 15+ always draws apps edge-to-edge when they target SDK 35+.
    // Opting in from Android 8 keeps every phone on the same layout: Flutter
    // reports the bar sizes as MediaQuery padding and each screen insets its
    // own content. AndroidX makes both bars transparent and turns off the
    // system scrim, so the deprecated Window bar-colour setters are never
    // called from Silarah's code. Android 7 cannot draw dark navigation
    // buttons, so it keeps the opaque system navigation bar.
    private fun enableEdgeToEdge() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        WindowCompat.enableEdgeToEdge(window)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val alerts = NotificationChannel(
            ALERTS_CHANNEL_ID,
            getString(R.string.notification_channel_alerts),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_alerts_description)
            enableVibration(true)
        }
        val activity = NotificationChannel(
            ACTIVITY_CHANNEL_ID,
            getString(R.string.notification_channel_activity),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = getString(R.string.notification_channel_activity_description)
        }
        // Incoming calls ring like a phone call (ringtone, on the alarm-free
        // ringtone stream). The member can change or silence it in Android
        // settings; Silarah's own Ring / Silent / Off setting is separate.
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val calls = NotificationChannel(
            CALLS_CHANNEL_ID,
            getString(R.string.notification_channel_calls),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_calls_description)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 600, 800, 600)
            setSound(
                ringtone,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }
        val ongoing = NotificationChannel(
            CALL_ONGOING_CHANNEL_ID,
            getString(R.string.notification_channel_call_ongoing),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.notification_channel_call_ongoing_description)
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannels(listOf(alerts, activity, calls, ongoing))
    }

    companion object {
        const val ALERTS_CHANNEL_ID = "silarah_alerts"
        const val ACTIVITY_CHANNEL_ID = "silarah_activity"
        const val CALLS_CHANNEL_ID = "silarah_calls"
        const val CALL_ONGOING_CHANNEL_ID = "silarah_call_ongoing"
    }
}

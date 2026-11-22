package com.silarah.app

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps the microphone alive while a Silarah call is on and the screen is
 * off or another app is in front (voice_calling_spec.md 8). Started only
 * after the member answers or the other person picks up, while the app is
 * in the foreground; stopped when the call ends. Type: microphone only.
 */
class CallForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: getString(R.string.call_ongoing_title)
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: getString(R.string.call_ongoing_text)
        val open = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(EXTRA_OPEN_CALL, true)
        }
        val contentIntent = open?.let {
            PendingIntent.getActivity(
                this,
                REQUEST_OPEN,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification: Notification = NotificationCompat.Builder(this, MainActivity.CALL_ONGOING_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_silarah)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentIntent)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
        } catch (error: RuntimeException) {
            // Android refuses a microphone service without the permission or
            // from the background. The call still runs while Silarah is open.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiping Silarah away ends the call; the server settles it.
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    companion object {
        private const val NOTIFICATION_ID = 41_001
        private const val REQUEST_OPEN = 41_002
        const val ACTION_STOP = "com.silarah.app.call.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_OPEN_CALL = "silarah_open_call"

        /**
         * Starts the service; false when Android refuses (a microphone
         * service may only start while Silarah is in front, Android 12+).
         * The app starts it only when resumed; this guard keeps a refusal
         * from ever crashing the app.
         */
        fun start(context: Context, title: String?, text: String?): Boolean {
            val intent = Intent(context, CallForegroundService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (error: RuntimeException) {
                false
            }
        }

        fun stop(context: Context) {
            // stopService never counts as a background start, unlike
            // sending ACTION_STOP through startService on Android 8+.
            context.stopService(Intent(context, CallForegroundService::class.java))
        }
    }
}

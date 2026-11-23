package com.silarah.calls

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person

/**
 * Call notifications (docs/voice_calling_spec.md 12.1–12.3). Texts arrive
 * already in the member's language from Dart; only the channel names come
 * from this module's resources (Android shows them in system settings).
 */
internal object CallNotifier {
    // Channel ids are permanent: Android never changes a channel's importance
    // after it is created, so each kind of call notification has its own.
    const val CHANNEL_INCOMING = "silarah_calls"
    const val CHANNEL_MISSED = "silarah_calls_missed"
    const val CHANNEL_ONGOING = "silarah_call_ongoing"

    const val ONGOING_ID = 41_001
    private const val RING_ID_BASE = 900_000_000
    private const val MISSED_ID = 41_100
    private const val PLAN_ID = 41_200
    private const val MISSED_TAG_PREFIX = "missed:"
    private const val PLAN_TAG_PREFIX = "plan:"

    // Launch actions the app understands (SilarahCallsPlugin forwards them).
    const val ACTION_RING = "com.silarah.calls.RING"
    const val ACTION_ANSWER = "com.silarah.calls.ANSWER"
    const val ACTION_OPEN_CALL = "com.silarah.calls.OPEN_CALL"
    const val ACTION_OPEN_CALLS = "com.silarah.calls.OPEN_CALLS"
    const val EXTRA_PAYLOAD = "com.silarah.calls.PAYLOAD"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val incoming = NotificationChannel(
            CHANNEL_INCOMING,
            context.getString(R.string.silarah_calls_notification_channel_calls),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.silarah_calls_notification_channel_calls_description)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 600, 800, 600)
            setSound(
                ringtone,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        val missed = NotificationChannel(
            CHANNEL_MISSED,
            context.getString(R.string.silarah_calls_notification_channel_missed),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.silarah_calls_notification_channel_missed_description)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        val ongoing = NotificationChannel(
            CHANNEL_ONGOING,
            context.getString(R.string.silarah_calls_notification_channel_call_ongoing),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.silarah_calls_notification_channel_call_ongoing_description)
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannels(listOf(incoming, missed, ongoing))
    }

    /**
     * Whether a ring can reach this member on this phone: notifications
     * allowed and the incoming-call channel not blocked (spec 12.2.4).
     */
    fun canRing(context: Context): Boolean {
        val compat = NotificationManagerCompat.from(context)
        if (!compat.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        ensureChannels(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = manager.getNotificationChannel(CHANNEL_INCOMING) ?: return true
        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun ringId(requestId: String): Int {
        val hex = requestId.replace("-", "")
        val head = if (hex.length >= 7) hex.substring(0, 7) else hex
        val value = head.toIntOrNull(16) ?: 0
        return RING_ID_BASE + value % 99_999_999
    }

    fun smallIcon(context: Context): Int {
        val id = context.resources.getIdentifier("ic_stat_silarah", "drawable", context.packageName)
        return if (id != 0) id else context.applicationInfo.icon
    }

    /** Opens Silarah (singleTop) with [action] and the payload. */
    fun launchIntent(context: Context, action: String, payload: String?, requestCode: Int): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        launch.action = action
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (payload != null) launch.putExtra(EXTRA_PAYLOAD, payload)
        return PendingIntent.getActivity(
            context,
            requestCode,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** The ring: CallStyle with Answer / Decline, full screen on a locked or sleeping phone. */
    fun showIncoming(context: Context, args: Map<String, Any?>) {
        ensureChannels(context)
        val requestId = args["requestId"] as String
        val payload = args["payload"] as String
        val id = ringId(requestId)
        val name = (args["callerName"] as? String).orEmpty()
        val title = (args["title"] as? String).orEmpty()
        val body = (args["body"] as? String).orEmpty()
        val publicTitle = (args["publicTitle"] as? String).orEmpty()
        val timeoutMs = ((args["timeoutMs"] as? Number)?.toLong() ?: 30_000L).coerceIn(1_000L, 120_000L)

        val ring = launchIntent(context, ACTION_RING, payload, id) ?: return
        val answer = launchIntent(context, ACTION_ANSWER, payload, id + 1) ?: return
        val decline = CallActionReceiver.declineIntent(
            context,
            requestCode = id + 2,
            notificationId = id,
            requestId = requestId,
            token = (args["declineToken"] as? String).orEmpty(),
            endpoint = (args["declineEndpoint"] as? String).orEmpty(),
            apiKey = (args["apiKey"] as? String).orEmpty(),
        )
        val person = Person.Builder().setName(name).setImportant(true).build()
        // On a locked screen whose settings hide private content, Android
        // shows this version: no name.
        val publicVersion = NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(smallIcon(context))
            .setContentTitle(publicTitle)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
        fun base() = NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(smallIcon(context))
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setFullScreenIntent(ring, true)
            .setContentIntent(ring)
            .setOngoing(true)
            .setAutoCancel(false)
            .setTimeoutAfter(timeoutMs)

        // Keep ringing until answered, declined, cancelled or timed out.
        fun insistent(notification: Notification) = notification.apply {
            flags = flags or Notification.FLAG_INSISTENT
        }

        val callStyle = insistent(
            base().setStyle(NotificationCompat.CallStyle.forIncomingCall(person, decline, answer)).build(),
        )
        if (!notify(context, null, id, callStyle)) {
            // Some Android 14+ builds refuse a CallStyle ring once the member
            // has not allowed full-screen calls. The ring must still show:
            // a heads-up with the same Answer and Decline.
            val plain = insistent(
                base()
                    .addAction(0, (args["declineLabel"] as? String).orEmpty(), decline)
                    .addAction(0, (args["answerLabel"] as? String).orEmpty(), answer)
                    .build(),
            )
            notify(context, null, id, plain)
        }
    }

    fun cancelIncoming(context: Context, requestId: String) {
        NotificationManagerCompat.from(context).cancel(ringId(requestId))
    }

    /** One notification per caller; the count comes from the server. */
    fun showMissed(context: Context, args: Map<String, Any?>) {
        ensureChannels(context)
        val callerId = (args["callerId"] as? String).orEmpty()
        val payload = (args["payload"] as? String).orEmpty()
        val tag = MISSED_TAG_PREFIX + callerId
        val open = launchIntent(context, ACTION_OPEN_CALLS, payload, tag.hashCode()) ?: return
        val count = ((args["count"] as? Number)?.toInt() ?: 1).coerceAtLeast(1)
        val publicVersion = NotificationCompat.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(smallIcon(context))
            .setContentTitle((args["publicTitle"] as? String).orEmpty())
            .build()
        val notification = NotificationCompat.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(smallIcon(context))
            .setContentTitle((args["title"] as? String).orEmpty())
            .setContentText((args["body"] as? String).orEmpty())
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setNumber(count)
            .setSilent(args["silent"] == true)
            .setOnlyAlertOnce(false)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        notify(context, tag, MISSED_ID, notification)
    }

    fun showPlanReminder(context: Context, args: Map<String, Any?>) {
        ensureChannels(context)
        val planId = (args["planId"] as? String).orEmpty()
        val tag = PLAN_TAG_PREFIX + planId
        val open = launchIntent(context, ACTION_OPEN_CALLS, (args["payload"] as? String).orEmpty(), tag.hashCode())
            ?: return
        val timeoutMs = ((args["timeoutMs"] as? Number)?.toLong() ?: 35 * 60_000L).coerceAtLeast(60_000L)
        val notification = NotificationCompat.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(smallIcon(context))
            .setContentTitle((args["title"] as? String).orEmpty())
            .setContentText((args["body"] as? String).orEmpty())
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setSilent(args["silent"] == true)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setTimeoutAfter(timeoutMs)
            .build()
        notify(context, tag, PLAN_ID, notification)
    }

    /** Opening the Calls tab here or on another phone clears missed calls. */
    fun clearMissed(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (active in manager.activeNotifications) {
            if (active.tag?.startsWith(MISSED_TAG_PREFIX) == true) manager.cancel(active.tag, active.id)
        }
    }

    /** Sign-out on a shared phone: nothing of the previous account stays. */
    fun clearAll(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (active in manager.activeNotifications) {
            val tag = active.tag
            val ours = active.id >= RING_ID_BASE ||
                tag?.startsWith(MISSED_TAG_PREFIX) == true ||
                tag?.startsWith(PLAN_TAG_PREFIX) == true
            if (ours) manager.cancel(tag, active.id)
        }
    }

    /** False when Android refused this notification (it is not shown). */
    @Suppress("MissingPermission")
    private fun notify(context: Context, tag: String?, id: Int, notification: Notification): Boolean {
        val compat = NotificationManagerCompat.from(context)
        if (!compat.areNotificationsEnabled()) return true
        return try {
            compat.notify(tag, id, notification)
            true
        } catch (error: SecurityException) {
            // POST_NOTIFICATIONS revoked between the check and the call.
            true
        } catch (error: IllegalArgumentException) {
            false
        }
    }
}

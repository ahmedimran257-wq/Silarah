package com.silarah.calls

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat

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

    /**
     * The status-bar icon of the ring and of a call in progress: a handset,
     * as in WhatsApp, so Android's call chip shows a phone. Silarah's
     * crescent shrinks there to a sliver that reads as "!" (seen on the
     * OnePlus, 25 Nov 2026).
     */
    val callIcon: Int get() = R.drawable.silarah_calls_ic_call

    /** The status-bar icon of a missed call. */
    val missedCallIcon: Int get() = R.drawable.silarah_calls_ic_call_missed

    /**
     * The call person: their name and a picture, their initial on a round
     * tile drawn here (no network). Android shows the picture in the call
     * notification, and some phones (OxygenOS) in the status-bar call chip,
     * which showed a "!" without one. WhatsApp always gives its call person
     * a picture.
     */
    fun callPerson(name: String): Person =
        Person.Builder().setName(name).setIcon(initialIcon(name)).setImportant(true).build()

    private fun initialIcon(name: String): IconCompat {
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AVATAR_COLOR }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        val initial = name.trim().take(1).uppercase()
        if (initial.isNotEmpty()) {
            paint.color = Color.WHITE
            paint.textSize = size * 0.46f
            paint.textAlign = Paint.Align.CENTER
            paint.typeface = Typeface.DEFAULT_BOLD
            canvas.drawText(initial, size / 2f, size / 2f - (paint.descent() + paint.ascent()) / 2f, paint)
        }
        return IconCompat.createWithBitmap(bitmap)
    }

    // Silarah's rose, readable under white.
    private const val AVATAR_COLOR = 0xFF9C2F55.toInt()

    /** Silarah's own icon, for its other notifications (plan reminders). */
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

    // The ring on screen now, so a volume key can silence it.
    @Volatile
    private var ringing: Map<String, Any?>? = null

    @Volatile
    private var ringingUntil = 0L

    /**
     * A volume key during the ring silences it, like a phone call; the ring
     * stays on screen. False when nothing is ringing.
     */
    fun silenceIncoming(context: Context): Boolean {
        val args = ringing ?: return false
        if (args["silent"] == true) return true
        val left = ringingUntil - System.currentTimeMillis()
        if (left < 1_000) return false
        val requestId = args["requestId"] as? String ?: return false
        NotificationManagerCompat.from(context).cancel(ringId(requestId))
        showIncoming(context, args + mapOf("silent" to true, "timeoutMs" to left))
        return true
    }

    /** The ring: CallStyle with Answer / Decline, full screen on a locked or sleeping phone. */
    fun showIncoming(context: Context, args: Map<String, Any?>) {
        ensureChannels(context)
        val silent = args["silent"] == true
        val requestId = args["requestId"] as String
        val payload = args["payload"] as String
        val id = ringId(requestId)
        val name = (args["callerName"] as? String).orEmpty()
        val title = (args["title"] as? String).orEmpty()
        val body = (args["body"] as? String).orEmpty()
        val publicTitle = (args["publicTitle"] as? String).orEmpty()
        val timeoutMs = ((args["timeoutMs"] as? Number)?.toLong() ?: 30_000L).coerceIn(1_000L, 120_000L)
        ringing = args
        ringingUntil = System.currentTimeMillis() + timeoutMs

        // The banner and the full-screen ring open the native ring screen
        // (WhatsApp / Telegram model, spec 12.1); without one from the app
        // (an older build), Silarah's own ring screen.
        val ringScreen = IncomingCallActivity.intent(context, args, ringingUntil)?.let {
            PendingIntent.getActivity(
                context,
                id + 3,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val ring = ringScreen ?: launchIntent(context, ACTION_RING, payload, id) ?: return
        // The banner's Answer opens the native screen already answering: a
        // closed Silarah would otherwise show its launch window (the logo)
        // before the call screen. WhatsApp's Answer opens its call screen too.
        val answerScreen = IncomingCallActivity.intent(context, args, ringingUntil, answer = true)?.let {
            PendingIntent.getActivity(
                context,
                id + 4,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val answer = answerScreen ?: launchIntent(context, ACTION_ANSWER, payload, id + 1) ?: return
        val decline = CallActionReceiver.declineIntent(
            context,
            requestCode = id + 2,
            notificationId = id,
            requestId = requestId,
            token = (args["declineToken"] as? String).orEmpty(),
            endpoint = (args["declineEndpoint"] as? String).orEmpty(),
            apiKey = (args["apiKey"] as? String).orEmpty(),
        )
        val person = callPerson(name)
        // On a locked screen whose settings hide private content, Android
        // shows this version: no name.
        val publicVersion = NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(callIcon)
            .setContentTitle(publicTitle)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
        fun base() = NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(callIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .apply {
                // The silenced ring is re-posted while its screen already
                // shows: it must not open that screen again.
                if (!silent) setFullScreenIntent(ring, true)
            }
            .setContentIntent(ring)
            .setOngoing(true)
            .setAutoCancel(false)
            .setTimeoutAfter(timeoutMs)
            .setSilent(silent)

        // Keep ringing until answered, declined, cancelled, silenced or timed out.
        fun insistent(notification: Notification) = notification.apply {
            if (!silent) flags = flags or Notification.FLAG_INSISTENT
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
        if (!silent) wakeScreenForRing(context)
    }

    /**
     * A ring on a sleeping phone turns the screen on, like the phone app's.
     * The full-screen ring asks Android to do it too, but when Silarah is
     * already the app in front Android hands the ring to that screen and
     * the request can be lost (seen on Android 10). Not when Do Not Disturb
     * is on or full-screen calls are not allowed: those settings win.
     */
    @Suppress("DEPRECATION")
    private fun wakeScreenForRing(context: Context) {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (power.isInteractive) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && !manager.canUseFullScreenIntent()) return
        try {
            power.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "silarah:ring-wake",
            ).acquire(5_000)
        } catch (_: RuntimeException) {
            // Waking is a courtesy; the ring still shows.
        }
    }

    /** The ring notification [notificationId] went (declined from it). */
    fun ringEnded(notificationId: Int) {
        val current = ringing?.get("requestId") as? String ?: return
        if (ringId(current) == notificationId) {
            ringing = null
            notifyRingEnded(current)
        }
    }

    fun cancelIncoming(context: Context, requestId: String) {
        if ((ringing?.get("requestId") as? String) == requestId) ringing = null
        NotificationManagerCompat.from(context).cancel(ringId(requestId))
        notifyRingEnded(requestId)
    }

    // The native ring screen listens: it closes when its ring ends anywhere
    // (cancelled, answered elsewhere, declined from the banner). "" = all.
    private val ringListeners = java.util.concurrent.CopyOnWriteArraySet<(String) -> Unit>()

    fun addRingListener(listener: (String) -> Unit) {
        ringListeners.add(listener)
    }

    fun removeRingListener(listener: (String) -> Unit) {
        ringListeners.remove(listener)
    }

    private fun notifyRingEnded(requestId: String) {
        for (listener in ringListeners) listener(requestId)
    }

    /** The ring of [requestId] is still in the status bar (it rings). */
    fun isRingShowing(context: Context, requestId: String): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = ringId(requestId)
        return manager.activeNotifications.any { it.id == id && it.tag == null }
    }

    /**
     * Silarah opened to answer [payload]'s ring, from the ring screen in
     * Silarah's own task: the app's screen comes up in that task (brought
     * forward if it is already there) with no launch window.
     */
    fun answerIntent(context: Context, payload: String): Intent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        launch.action = ACTION_ANSWER
        launch.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        launch.putExtra(EXTRA_PAYLOAD, payload)
        return launch
    }

    /**
     * Where the member is, for a ring that ends without an answer and for a
     * launch from a call notification: true once they left Silarah for
     * another app (or Silarah has not been on screen since it started);
     * false while Silarah is in front, also behind the lock screen. Kept by
     * the plugin from the app's screen (SilarahCallsPlugin.screenWatch).
     */
    @Volatile
    var memberLeftSilarah = true

    /** The native ring screen is up: it covers the app's screen, which is not the member leaving. */
    @Volatile
    var ringScreenShowing = false

    /** One notification per caller; the count comes from the server. */
    fun showMissed(context: Context, args: Map<String, Any?>) {
        ensureChannels(context)
        val callerId = (args["callerId"] as? String).orEmpty()
        val payload = (args["payload"] as? String).orEmpty()
        val tag = MISSED_TAG_PREFIX + callerId
        val open = launchIntent(context, ACTION_OPEN_CALLS, payload, tag.hashCode()) ?: return
        val count = ((args["count"] as? Number)?.toInt() ?: 1).coerceAtLeast(1)
        val publicVersion = NotificationCompat.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(missedCallIcon)
            .setContentTitle((args["publicTitle"] as? String).orEmpty())
            .build()
        val notification = NotificationCompat.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(missedCallIcon)
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
        // Nothing of the previous account may come back on a volume key.
        ringing = null
        notifyRingEnded("")
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

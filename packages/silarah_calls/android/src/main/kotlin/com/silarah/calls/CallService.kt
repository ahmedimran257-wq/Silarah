package com.silarah.calls

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.ServiceCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * The live Silarah call (docs/voice_calling_spec.md 12.1): keeps the
 * microphone alive with the screen off or another app in front, and shows
 * the ongoing CallStyle notification (name, running timer, minutes left,
 * Mute, Hang up; tap returns to the call). On Android 12+ that notification
 * puts the call chip in the status bar. On Android 8+ the call is also a
 * self-managed Telecom call ([CallTelecom]); on Android 7 it is the service
 * and the notification only. Started by the app only after the call is
 * answered and while Silarah is in front; stopped when the call ends.
 */
class CallService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var telecom: Any? = null
    private var state = OngoingState()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        current = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        @Suppress("UNCHECKED_CAST", "DEPRECATION")
        val args = (intent?.getSerializableExtra(EXTRA_ARGS) as? HashMap<String, Any?>) ?: hashMapOf()
        state = state.merge(args)
        val foreground = startInForeground(telecomActive = (telecom as? CallTelecom)?.isActive == true)
        if (!foreground) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_START && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            telecom == null && state.requestId.isNotEmpty()
        ) {
            val link = CallTelecom(applicationContext, scope) { event, data ->
                SilarahCallsPlugin.emit(event, data)
            }
            telecom = link
            link.start(state.name, state.requestId, state.outgoing) {
                // Telecom has the call: now it may run as a phone-call service.
                startInForeground(telecomActive = true)
            }
        }
        return START_NOT_STICKY
    }

    /** False when Android refuses (missing permission, started from the background). */
    private fun startInForeground(telecomActive: Boolean): Boolean {
        val type = when {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q -> 0
            telecomActive -> ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            else -> ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        return try {
            ServiceCompat.startForeground(this, CallNotifier.ONGOING_ID, buildNotification(), type)
            true
        } catch (error: RuntimeException) {
            false
        }
    }

    private fun buildNotification(): Notification {
        CallNotifier.ensureChannels(this)
        val person = Person.Builder().setName(state.name.ifEmpty { state.title }).setImportant(true).build()
        val hangUp = CallActionReceiver.actionIntent(this, CallActionReceiver.ACTION_HANG_UP, 41_011)
        val mute = CallActionReceiver.actionIntent(this, CallActionReceiver.ACTION_TOGGLE_MUTE, 41_012)
        val open = CallNotifier.launchIntent(this, CallNotifier.ACTION_OPEN_CALL, null, 41_013)
        val builder = NotificationCompat.Builder(this, CallNotifier.CHANNEL_ONGOING)
            .setSmallIcon(CallNotifier.smallIcon(this))
            .setContentTitle(state.name.ifEmpty { state.title })
            .setContentText(state.text)
            .setStyle(NotificationCompat.CallStyle.forOngoingCall(person, hangUp).setIsVideo(false))
            .addAction(
                if (state.muted) R.drawable.silarah_calls_ic_mic else R.drawable.silarah_calls_ic_mic_off,
                if (state.muted) state.unmuteLabel else state.muteLabel,
                mute,
            )
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
        if (state.connectedAtMs > 0) {
            builder.setUsesChronometer(true).setShowWhen(true).setWhen(state.connectedAtMs)
        } else {
            builder.setShowWhen(false)
        }
        return builder.build()
    }

    private fun refresh() {
        try {
            NotificationManagerCompat.from(this).notify(CallNotifier.ONGOING_ID, buildNotification())
        } catch (_: SecurityException) {
        }
    }

    override fun onDestroy() {
        (telecom as? CallTelecom)?.end()
        telecom = null
        if (current === this) current = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        // Let Telecom hear the disconnect before the scope goes.
        android.os.Handler(mainLooper).postDelayed({ scope.cancel() }, 1_000)
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiping Silarah away ends the call; the server settles it.
        SilarahCallsPlugin.emit("hangUp", mapOf("source" to "task_removed"))
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    /** What the ongoing notification shows; fields left out keep their value. */
    private data class OngoingState(
        val requestId: String = "",
        val name: String = "",
        val title: String = "",
        val text: String = "",
        val outgoing: Boolean = true,
        val connectedAtMs: Long = 0,
        val muted: Boolean = false,
        val muteLabel: String = "Mute",
        val unmuteLabel: String = "Unmute",
    ) {
        fun merge(args: Map<String, Any?>) = copy(
            requestId = args["requestId"] as? String ?: requestId,
            name = args["name"] as? String ?: name,
            title = args["title"] as? String ?: title,
            text = args["text"] as? String ?: text,
            outgoing = args["outgoing"] as? Boolean ?: outgoing,
            connectedAtMs = (args["connectedAtMs"] as? Number)?.toLong() ?: connectedAtMs,
            muted = args["muted"] as? Boolean ?: muted,
            muteLabel = args["muteLabel"] as? String ?: muteLabel,
            unmuteLabel = args["unmuteLabel"] as? String ?: unmuteLabel,
        )
    }

    companion object {
        private const val ACTION_START = "com.silarah.calls.SERVICE_START"
        private const val EXTRA_ARGS = "args"

        @Volatile
        private var current: CallService? = null

        val telecomActive: Boolean
            get() = (current?.telecom as? CallTelecom)?.isActive == true

        /** False when Android refuses to start it (see [startInForeground]). */
        fun start(context: Context, args: Map<String, Any?>): Boolean {
            val intent = Intent(context, CallService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_ARGS, HashMap(args))
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

        /** Name, timer, minutes left or mute changed. No-op when not running. */
        fun update(args: Map<String, Any?>) {
            val service = current ?: return
            service.state = service.state.merge(args)
            service.refresh()
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CallService::class.java))
        }

        fun requestRoute(route: String): Boolean =
            (current?.telecom as? CallTelecom)?.requestRoute(route) == true

        fun resumeAfterPhoneCall() {
            (current?.telecom as? CallTelecom)?.resume()
        }
    }
}

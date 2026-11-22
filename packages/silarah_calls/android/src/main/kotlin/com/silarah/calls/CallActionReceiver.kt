package com.silarah.calls

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Notification buttons that must work without opening Silarah:
 *  * Decline on the ring: sent to the server with the ring's one-time token
 *    (edge function `calls`, action decline_token), even when Silarah is
 *    closed. The token only lets this one call be declined.
 *  * Mute and Hang up on the live call: forwarded to the call in the app.
 */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_DECLINE -> decline(context, intent)
            ACTION_HANG_UP -> {
                if (!SilarahCallsPlugin.emit("hangUp", emptyMap())) {
                    // No call left in the app to hang up: just remove the service.
                    CallService.stop(context)
                }
            }
            ACTION_TOGGLE_MUTE -> SilarahCallsPlugin.emit("toggleMute", emptyMap())
        }
    }

    private fun decline(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        NotificationManagerCompat.from(context).cancel(notificationId)
        val requestId = intent.getStringExtra(EXTRA_REQUEST_ID).orEmpty()
        val token = intent.getStringExtra(EXTRA_TOKEN).orEmpty()
        val endpoint = intent.getStringExtra(EXTRA_ENDPOINT).orEmpty()
        val apiKey = intent.getStringExtra(EXTRA_API_KEY).orEmpty()
        // The app, if open, closes its incoming screen.
        SilarahCallsPlugin.emit("declined", mapOf("requestId" to requestId))
        if (requestId.isEmpty() || token.isEmpty() || !endpoint.startsWith("https://")) return
        val pending = goAsync()
        thread(name = "silarah-call-decline") {
            try {
                postDecline(endpoint, apiKey, requestId, token)
            } finally {
                pending.finish()
            }
        }
    }

    private fun postDecline(endpoint: String, apiKey: String, requestId: String, token: String) {
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 8_000
                readTimeout = 8_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                if (apiKey.isNotEmpty()) setRequestProperty("apikey", apiKey)
            }
            val body = JSONObject()
                .put("action", "decline_token")
                .put("request_id", requestId)
                .put("token", token)
                .toString()
                .toByteArray(Charsets.UTF_8)
            connection.outputStream.use { it.write(body) }
            connection.responseCode // send and wait; the ring times out anyway if this fails
        } catch (_: Exception) {
            // Offline: the ring ends by timeout and shows as missed.
        } finally {
            connection?.disconnect()
        }
    }

    companion object {
        const val ACTION_DECLINE = "com.silarah.calls.DECLINE"
        const val ACTION_HANG_UP = "com.silarah.calls.HANG_UP"
        const val ACTION_TOGGLE_MUTE = "com.silarah.calls.TOGGLE_MUTE"
        private const val EXTRA_NOTIFICATION_ID = "notification_id"
        private const val EXTRA_REQUEST_ID = "request_id"
        private const val EXTRA_TOKEN = "token"
        private const val EXTRA_ENDPOINT = "endpoint"
        private const val EXTRA_API_KEY = "api_key"

        fun declineIntent(
            context: Context,
            requestCode: Int,
            notificationId: Int,
            requestId: String,
            token: String,
            endpoint: String,
            apiKey: String,
        ): PendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, CallActionReceiver::class.java)
                .setAction(ACTION_DECLINE)
                .putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                .putExtra(EXTRA_REQUEST_ID, requestId)
                .putExtra(EXTRA_TOKEN, token)
                .putExtra(EXTRA_ENDPOINT, endpoint)
                .putExtra(EXTRA_API_KEY, apiKey),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, CallActionReceiver::class.java).setAction(action),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }
}

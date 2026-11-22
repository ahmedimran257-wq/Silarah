package com.silarah.calls

import android.content.Context
import android.net.Uri
import android.os.Build
import android.telecom.DisconnectCause
import androidx.annotation.RequiresApi
import androidx.core.telecom.CallAttributesCompat
import androidx.core.telecom.CallControlResult
import androidx.core.telecom.CallControlScope
import androidx.core.telecom.CallEndpointCompat
import androidx.core.telecom.CallsManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * The live call as a self-managed Telecom call (Jetpack Core-Telecom,
 * Android 8+). Telecom then knows Silarah is on a call: headset, car and
 * Bluetooth buttons act on it, audio routes through Telecom's endpoints, and
 * a regular phone call puts it on hold (onSetInactive) instead of mixing
 * audio. Any failure here leaves the call running without Telecom.
 */
@RequiresApi(Build.VERSION_CODES.O)
internal class CallTelecom(
    private val context: Context,
    private val scope: CoroutineScope,
    private val emit: (String, Map<String, Any?>) -> Unit,
) {
    private var control: CallControlScope? = null
    private var job: Job? = null
    private var endpoints: List<CallEndpointCompat> = emptyList()

    val isActive: Boolean get() = control != null

    /** Adds the call and makes it active; [onActive] runs once Telecom has it. */
    fun start(name: String, requestId: String, outgoing: Boolean, onActive: () -> Unit) {
        if (job != null) return
        val manager = CallsManager(context)
        try {
            manager.registerAppWithTelecom(CallsManager.CAPABILITY_BASELINE)
        } catch (error: Exception) {
            emit("telecom", mapOf("available" to false, "error" to error.javaClass.simpleName))
            return
        }
        val attributes = CallAttributesCompat(
            displayName = name,
            address = Uri.fromParts("silarah", requestId, null),
            direction = if (outgoing) {
                CallAttributesCompat.DIRECTION_OUTGOING
            } else {
                CallAttributesCompat.DIRECTION_INCOMING
            },
            callType = CallAttributesCompat.CALL_TYPE_AUDIO_CALL,
            callCapabilities = CallAttributesCompat.SUPPORTS_SET_INACTIVE,
        )
        job = scope.launch {
            try {
                manager.addCall(
                    attributes,
                    onAnswer = { _ -> },
                    // Hung up from a headset, the car or the system.
                    onDisconnect = { _ ->
                        control = null
                        emit("hangUp", mapOf("source" to "telecom"))
                    },
                    onSetActive = { emit("phoneCall", mapOf("active" to false)) },
                    // A regular phone call took over: Silarah's call is on hold.
                    onSetInactive = { emit("phoneCall", mapOf("active" to true)) },
                ) {
                    control = this
                    launch {
                        // The member already answered in Silarah.
                        val result = if (outgoing) setActive() else answer(CallAttributesCompat.CALL_TYPE_AUDIO_CALL)
                        if (result is CallControlResult.Success) {
                            emit("telecom", mapOf("available" to true))
                            onActive()
                        } else {
                            emit("telecom", mapOf("available" to false, "error" to result.toString()))
                        }
                    }
                    launch {
                        currentCallEndpoint.collect { endpoint ->
                            emit("route", mapOf("current" to routeName(endpoint.type)))
                        }
                    }
                    launch {
                        availableEndpoints.collect { list ->
                            endpoints = list
                            emit("routes", mapOf("available" to list.map { routeName(it.type) }.distinct()))
                        }
                    }
                }
            } catch (error: Exception) {
                control = null
                emit("telecom", mapOf("available" to false, "error" to error.javaClass.simpleName))
            }
        }
    }

    /** speaker | earpiece | bluetooth | wired. False when Telecom cannot do it. */
    fun requestRoute(route: String): Boolean {
        val scopeControl = control ?: return false
        val target = endpoints.firstOrNull { routeName(it.type) == route } ?: return false
        scope.launch { scopeControl.requestEndpointChange(target) }
        return true
    }

    /** After a regular phone call ended, the Silarah call is active again. */
    fun resume() {
        val scopeControl = control ?: return
        scope.launch { scopeControl.setActive() }
    }

    fun end() {
        val scopeControl = control
        control = null
        if (scopeControl != null) {
            scope.launch {
                try {
                    scopeControl.disconnect(DisconnectCause(DisconnectCause.LOCAL))
                } catch (_: Exception) {
                }
                job?.cancel()
                job = null
            }
        } else {
            job?.cancel()
            job = null
        }
    }

    companion object {
        fun routeName(type: Int): String = when (type) {
            CallEndpointCompat.TYPE_SPEAKER -> "speaker"
            CallEndpointCompat.TYPE_BLUETOOTH -> "bluetooth"
            CallEndpointCompat.TYPE_WIRED_HEADSET -> "wired"
            CallEndpointCompat.TYPE_EARPIECE -> "earpiece"
            else -> "other"
        }
    }
}

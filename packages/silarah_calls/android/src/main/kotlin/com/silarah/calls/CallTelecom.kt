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

    /**
     * Adds the call; [onActive] runs once Telecom has it. An outgoing call
     * is added as it starts ringing (Telecom routes its ringback to the
     * earpiece or headset) and becomes active in [markConnected]; an
     * incoming call is added when answered, and is active at once.
     */
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
                        if (outgoing) {
                            // Dialing: active once the other member answers.
                            emit("telecom", mapOf("available" to true))
                            onActive()
                            if (connectedEarly) setActive()
                        } else {
                            // The member already answered in Silarah. Answer, then
                            // active: on Android 10 the answered call otherwise
                            // stayed "ringing" in Telecom for the whole call.
                            val result = answer(CallAttributesCompat.CALL_TYPE_AUDIO_CALL)
                            if (result is CallControlResult.Success) setActive()
                            if (result is CallControlResult.Success) {
                                emit("telecom", mapOf("available" to true))
                                onActive()
                            } else {
                                emit("telecom", mapOf("available" to false, "error" to result.toString()))
                            }
                        }
                    }
                    launch {
                        currentCallEndpoint.collect { endpoint ->
                            emit("route", mapOf("current" to routeName(endpoint.type), "name" to endpoint.name.toString()))
                        }
                    }
                    launch {
                        availableEndpoints.collect { list ->
                            endpoints = list
                            emit("routes", mapOf("available" to list.map {
                                mapOf("route" to routeName(it.type), "name" to it.name.toString())
                            }))
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

    private var connectedEarly = false

    /** The other member answered: the outgoing call is active. */
    fun markConnected() {
        val scopeControl = control
        if (scopeControl == null) {
            // Telecom has not handed over the call yet: active when it does.
            connectedEarly = true
            return
        }
        scope.launch { scopeControl.setActive() }
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

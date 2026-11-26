package com.silarah.calls

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.min

/**
 * The ring screen, native like WhatsApp's and Telegram's
 * (docs/voice_calling_spec.md 12.1). Android opens it at once from the ring's
 * banner or over the lock screen, without starting Silarah: no app logo, no
 * start-up. It looks like the app's own call screen (call_screen.dart): the
 * app hands it the member's language, theme colours and the caller's photo
 * link with every ring. Decline is sent natively; Answer opens Silarah, which
 * answers. The banner's Answer opens this screen already answering, so that
 * path shows no app logo either. It closes when the ring ends anywhere, and
 * closing it returns the member to where they were.
 */
class IncomingCallActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private var ring: Bundle = Bundle()
    private val requestId get() = ring.getString(KEY_REQUEST_ID).orEmpty()
    private var photoThread: Thread? = null
    private var status: TextView? = null
    private var actions: View? = null

    // The member was not in Silarah when the ring came (another app, the
    // home screen, or Silarah not running): a ring that ends without an
    // answer returns them there, like WhatsApp.
    private var cameFromElsewhere = true

    // Answered: Silarah's call screen comes up over this screen in the same
    // task; this screen closes once it is covered (onStop).
    private var answered = false

    // The ring ended (cancelled, answered elsewhere, declined from the banner,
    // signed out): nothing to show.
    private val onRingEnded: (String) -> Unit = { ended ->
        main.post { if (ended == requestId || ended.isEmpty()) close() }
    }
    private val timeUp = Runnable { close() }

    // Silarah never drew over the answered ring (it failed to start).
    private val answerTimeout = Runnable { finish() }

    // On screen at least once. Silarah may only open over this screen after
    // that: opened over a task with nothing drawn yet, Android shows
    // Silarah's launch window (the logo) first.
    private var onScreen = false
    private var answerWhenOnScreen = false
    private val answerAnyway = Runnable { answerIfAsked() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cameFromElsewhere = isTaskRoot || CallNotifier.memberLeftSilarah
        CallNotifier.ringScreenShowing = true
        showOverLockScreen()
        CallNotifier.addRingListener(onRingEnded)
        show(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        answered = false
        show(intent)
    }

    override fun onStop() {
        super.onStop()
        if (answered) finish()
    }

    override fun onDestroy() {
        CallNotifier.ringScreenShowing = false
        CallNotifier.removeRingListener(onRingEnded)
        main.removeCallbacks(timeUp)
        main.removeCallbacks(answerTimeout)
        main.removeCallbacks(answerAnyway)
        photoThread?.interrupt()
        super.onDestroy()
    }

    /**
     * The ring is over here without an answer: back to where the member was
     * (the lock screen or the other app), or to Silarah if they were in it.
     */
    private fun close() {
        if (answered || isFinishing) return
        if (cameFromElsewhere) moveTaskToBack(true)
        finish()
    }

    /** A ring waits for Answer or Decline, as in the app. */
    @Deprecated("Back on a ring does nothing", ReplaceWith(""))
    override fun onBackPressed() {}

    /** A volume key silences the ring, like a phone call. */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (CallNotifier.silenceIncoming(this)) return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun show(intent: Intent?) {
        ring = intent?.getBundleExtra(EXTRA_RING) ?: Bundle()
        val endsAt = ring.getLong(KEY_ENDS_AT)
        val left = endsAt - System.currentTimeMillis()
        // Opened for a ring that is already over (a late tap, a restored task).
        if (requestId.isEmpty() || left <= 0 || !CallNotifier.isRingShowing(this, requestId)) {
            close()
            return
        }
        main.removeCallbacks(timeUp)
        main.postDelayed(timeUp, left)
        setContentView(build())
        // The banner's Answer: answering starts on this screen, as soon as
        // it shows.
        if (intent?.getBooleanExtra(EXTRA_ANSWER, false) == true) {
            answerWhenOnScreen = true
            // Already answered: its first frame says so.
            showConnecting()
            if (onScreen) {
                answerIfAsked()
            } else {
                main.postDelayed(answerAnyway, ON_SCREEN_TIMEOUT_MS)
            }
        }
    }

    /** Android calls this once the screen has come in (also with no animation). */
    override fun onEnterAnimationComplete() {
        super.onEnterAnimationComplete()
        onScreen = true
        answerIfAsked()
    }

    private fun answerIfAsked() {
        main.removeCallbacks(answerAnyway)
        if (!answerWhenOnScreen) return
        answerWhenOnScreen = false
        answer()
    }

    @Suppress("DEPRECATION")
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        volumeControlStream = android.media.AudioManager.STREAM_RING
    }

    // ------------------------------------------------------------------ layout

    private fun color(key: String) = ring.getInt(key)

    private fun dp(value: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()

    private fun font(file: String, weight: Int): Typeface {
        val base = try {
            Typeface.createFromAsset(assets, "flutter_assets/assets/fonts/$file")
        } catch (_: RuntimeException) {
            if (file.startsWith("Playfair")) Typeface.SERIF else Typeface.SANS_SERIF
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Typeface.create(base, weight, false) else base
    }

    private fun text(value: String, sizeSp: Float, colorKey: String, typeface: Typeface) = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(color(colorKey))
        this.typeface = typeface
        gravity = Gravity.CENTER
        includeFontPadding = false
    }

    @Suppress("DEPRECATION")
    private fun build(): View {
        val background = color(KEY_BACKGROUND)
        window.decorView.setBackgroundColor(background)
        window.statusBarColor = background
        window.navigationBarColor = background
        val dark = ring.getBoolean(KEY_DARK)
        var flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        if (!dark) {
            flags = flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) flags = flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        }
        window.decorView.systemUiVisibility = flags

        val inter = font("Inter.ttf", 400)
        val playfair = font("PlayfairDisplay.ttf", 600)
        val name = ring.getString(KEY_NAME).orEmpty()

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24f), dp(16f), dp(24f), dp(32f))
            setBackgroundColor(background)
        }

        // "Calls are private. Silarah never records them."
        val note = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(ImageView(context).apply {
                setImageResource(R.drawable.silarah_calls_ic_lock)
                setColorFilter(color(KEY_SECONDARY))
            }, LinearLayout.LayoutParams(dp(14f), dp(14f)).apply { marginEnd = dp(6f) })
            addView(text(ring.getString(KEY_PRIVATE_NOTE).orEmpty(), 13f, KEY_SECONDARY, inter))
        }
        column.addView(note, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        column.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))

        column.addView(avatar(name), LinearLayout.LayoutParams(dp(132f), dp(132f)))

        column.addView(text(name, 24f, KEY_TEXT, playfair).apply {
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            letterSpacing = 0.2f / 24f
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(24f)
        })
        val statusLine = text(ring.getString(KEY_STATUS).orEmpty(), 15f, KEY_SECONDARY, inter).apply {
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        status = statusLine
        column.addView(statusLine,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(8f)
            })
        column.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(action(ring.getString(KEY_DECLINE_LABEL).orEmpty(), R.drawable.silarah_calls_ic_call_end,
                KEY_DECLINE, KEY_ON_DECLINE, inter) { decline() }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(action(ring.getString(KEY_ANSWER_LABEL).orEmpty(), R.drawable.silarah_calls_ic_call,
                KEY_ANSWER, KEY_ON_ANSWER, inter) { answer() }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        }
        column.addView(actions, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(32f)
        })
        this.actions = actions

        // Below the status bar and above the navigation bar.
        column.setOnApplyWindowInsetsListener { view, insets ->
            view.setPadding(dp(24f), dp(16f) + insets.systemWindowInsetTop, dp(24f), dp(32f) + insets.systemWindowInsetBottom)
            insets
        }
        window.decorView.systemUiVisibility = flags or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        return column
    }

    /** The caller's photo in a ring, or their initial until it loads. */
    private fun avatar(name: String): View {
        val frame = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(color(KEY_AVATAR_FILL))
                setStroke(dp(2f), color(KEY_AVATAR_BORDER))
            }
            contentDescription = name
        }
        val initial = text(name.trim().take(1).uppercase(), 22f, KEY_ACCENT, font("Inter.ttf", 800)).apply {
            letterSpacing = 2f / 22f
        }
        frame.addView(initial, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        val photo = ImageView(this).apply { visibility = View.GONE }
        frame.addView(photo, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT).apply {
            setMargins(dp(2f), dp(2f), dp(2f), dp(2f))
        })
        val url = ring.getString(KEY_PHOTO_URL)
        if (!url.isNullOrEmpty()) loadPhoto(url, dp(128f), photo)
        return frame
    }

    private fun loadPhoto(url: String, sizePx: Int, into: ImageView) {
        photoThread?.interrupt()
        photoThread = Thread {
            val bitmap = try {
                download(url)?.let { circle(it, sizePx) }
            } catch (_: Exception) {
                null
            }
            if (bitmap != null && !Thread.currentThread().isInterrupted) {
                main.post {
                    into.setImageBitmap(bitmap)
                    into.visibility = View.VISIBLE
                }
            }
        }.apply { start() }
    }

    private fun download(url: String): Bitmap? {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 5_000
        connection.readTimeout = 5_000
        return try {
            if (connection.responseCode != 200) return null
            val bytes = connection.inputStream.use { it.readBytes() }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (min(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 512) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
        } finally {
            connection.disconnect()
        }
    }

    private fun circle(source: Bitmap, size: Int): Bitmap {
        val side = min(source.width, source.height)
        val square = Bitmap.createBitmap(source, (source.width - side) / 2, (source.height - side) / 2, side, side)
        val scaled = Bitmap.createScaledBitmap(square, size, size, true)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        Canvas(output).drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return output
    }

    /** A 72 dp round button with its label below, as in the app. */
    private fun action(label: String, icon: Int, colorKey: String, onColorKey: String, inter: Typeface, onTap: () -> Unit): View {
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val button = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(color(colorKey))
            }
            isClickable = true
            isFocusable = true
            contentDescription = label
            setOnClickListener {
                isEnabled = false
                onTap()
            }
        }
        button.addView(ImageView(this).apply {
            setImageResource(icon)
            setColorFilter(color(onColorKey))
        }, FrameLayout.LayoutParams(dp(32f), dp(32f), Gravity.CENTER))
        column.addView(button, LinearLayout.LayoutParams(dp(72f), dp(72f)))
        column.addView(text(label, 13f, KEY_SECONDARY, inter).apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(8f)
        })
        return column
    }

    // ----------------------------------------------------------------- actions

    /** Declined here and on the server at once; back to where the member was. */
    private fun decline() {
        try {
            CallActionReceiver.declineIntent(
                this,
                requestCode = CallNotifier.ringId(requestId) + 2,
                notificationId = CallNotifier.ringId(requestId),
                requestId = requestId,
                token = ring.getString(KEY_DECLINE_TOKEN).orEmpty(),
                endpoint = ring.getString(KEY_DECLINE_ENDPOINT).orEmpty(),
                apiKey = ring.getString(KEY_API_KEY).orEmpty(),
            ).send()
        } catch (_: Exception) {
            // The ring then runs out on the server; the member saw it end here.
        }
        close()
    }

    /**
     * Like WhatsApp: this screen stays up, "Connecting…", with the ring
     * silenced and its buttons gone, while Silarah opens in the same task and
     * answers (it checks the microphone first). Silarah draws only once its
     * call screen is ready, which covers this screen and closes it.
     */
    private fun answer() {
        if (answered) return
        val launch = CallNotifier.answerIntent(this, ring.getString(KEY_PAYLOAD).orEmpty()) ?: return
        answered = true
        main.removeCallbacks(timeUp)
        showConnecting()
        CallNotifier.silenceIncoming(this)
        // Over the lock screen before it comes to the front: no glimpse of
        // the lock screen between this screen and the call screen.
        SilarahCallsPlugin.prepareCallWindow()
        startActivity(launch)
        main.postDelayed(answerTimeout, ANSWER_TIMEOUT_MS)
    }

    /** "Connecting…", with Decline and Answer gone. */
    private fun showConnecting() {
        actions?.visibility = View.INVISIBLE
        status?.text = ring.getString(KEY_CONNECTING).orEmpty().ifEmpty { status?.text }
    }

    companion object {
        // Silarah drew over an answered ring well before this on every phone tested.
        private const val ANSWER_TIMEOUT_MS = 15_000L
        // The screen comes in within a few hundred ms; answering never waits longer.
        private const val ON_SCREEN_TIMEOUT_MS = 1_000L
        const val EXTRA_RING = "com.silarah.calls.RING_SCREEN"
        const val EXTRA_ANSWER = "com.silarah.calls.ANSWER_ON_OPEN"
        const val KEY_REQUEST_ID = "requestId"
        const val KEY_PAYLOAD = "payload"
        const val KEY_NAME = "name"
        const val KEY_STATUS = "status"
        const val KEY_CONNECTING = "connecting"
        const val KEY_PRIVATE_NOTE = "privateNote"
        const val KEY_ANSWER_LABEL = "answerLabel"
        const val KEY_DECLINE_LABEL = "declineLabel"
        const val KEY_DECLINE_TOKEN = "declineToken"
        const val KEY_DECLINE_ENDPOINT = "declineEndpoint"
        const val KEY_API_KEY = "apiKey"
        const val KEY_PHOTO_URL = "photoUrl"
        const val KEY_ENDS_AT = "endsAt"
        const val KEY_DARK = "dark"
        const val KEY_BACKGROUND = "background"
        const val KEY_TEXT = "text"
        const val KEY_SECONDARY = "secondaryText"
        const val KEY_ACCENT = "accent"
        const val KEY_AVATAR_BORDER = "avatarBorder"
        const val KEY_AVATAR_FILL = "avatarFill"
        const val KEY_DECLINE = "decline"
        const val KEY_ON_DECLINE = "onDecline"
        const val KEY_ANSWER = "answer"
        const val KEY_ON_ANSWER = "onAnswer"

        private val COLOR_KEYS = listOf(
            KEY_BACKGROUND, KEY_TEXT, KEY_SECONDARY, KEY_ACCENT, KEY_AVATAR_BORDER,
            KEY_AVATAR_FILL, KEY_DECLINE, KEY_ON_DECLINE, KEY_ANSWER, KEY_ON_ANSWER,
        )

        /** The ring screen for [args] (CallNotifier.showIncoming), or null
         *  when the app sent no screen (an older app build): the app's own
         *  ring screen is used then. [answer]: opened by the banner's Answer,
         *  it answers at once. */
        fun intent(context: Context, args: Map<String, Any?>, endsAt: Long, answer: Boolean = false): Intent? {
            val colors = args["ringColors"] as? Map<*, *> ?: return null
            val ring = Bundle().apply {
                putString(KEY_REQUEST_ID, args["requestId"] as? String)
                putString(KEY_PAYLOAD, args["payload"] as? String)
                putString(KEY_NAME, args["callerName"] as? String)
                putString(KEY_STATUS, args["ringStatus"] as? String)
                putString(KEY_CONNECTING, args["ringConnecting"] as? String)
                putString(KEY_PRIVATE_NOTE, args["ringPrivateNote"] as? String)
                putString(KEY_ANSWER_LABEL, args["answerLabel"] as? String)
                putString(KEY_DECLINE_LABEL, args["declineLabel"] as? String)
                putString(KEY_DECLINE_TOKEN, args["declineToken"] as? String)
                putString(KEY_DECLINE_ENDPOINT, args["declineEndpoint"] as? String)
                putString(KEY_API_KEY, args["apiKey"] as? String)
                putString(KEY_PHOTO_URL, args["ringPhotoUrl"] as? String)
                putBoolean(KEY_DARK, args["ringDark"] == true)
                putLong(KEY_ENDS_AT, endsAt)
                for (key in COLOR_KEYS) {
                    val value = colors[key] as? Number ?: return null
                    putInt(key, value.toLong().toInt())
                }
            }
            return Intent(context, IncomingCallActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                .putExtra(EXTRA_RING, ring)
                .putExtra(EXTRA_ANSWER, answer)
        }
    }
}

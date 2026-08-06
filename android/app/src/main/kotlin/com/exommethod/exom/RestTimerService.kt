package com.exommethod.exom

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.util.Locale
import kotlin.math.ceil

class RestTimerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var sessionId: String? = null
    private var endsAtMillis = 0L
    private var durationSeconds = 0
    private var exerciseName = ""
    private var soundEnabled = true
    private var timerFinished = false
    private var completionPlayer: MediaPlayer? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { }

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (System.currentTimeMillis() >= endsAtMillis) {
                finishTimer()
                return
            }

            getSystemService(NotificationManager::class.java).notify(
                ONGOING_NOTIFICATION_ID,
                buildOngoingNotification(),
            )
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_FINISH) {
            val finished = finishTimer(intent.getStringExtra(EXTRA_SESSION_ID))
            if (!finished && sessionId == null) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_START) return START_NOT_STICKY

        releaseCompletionPlayer()
        timerFinished = false
        sessionId = intent.getStringExtra(EXTRA_SESSION_ID)
        endsAtMillis = intent.getLongExtra(EXTRA_ENDS_AT_MILLIS, 0L)
        exerciseName = intent.getStringExtra(EXTRA_EXERCISE_NAME).orEmpty()
        durationSeconds = intent.getIntExtra(EXTRA_DURATION_SECONDS, 0)
        soundEnabled = intent.getBooleanExtra(EXTRA_SOUND_ENABLED, true)
        if (endsAtMillis <= System.currentTimeMillis() || durationSeconds <= 0) {
            finishTimer()
            return START_NOT_STICKY
        }

        handler.removeCallbacks(tickRunnable)
        startForeground(
            ONGOING_NOTIFICATION_ID,
            buildOngoingNotification(),
        )
        handler.postDelayed(tickRunnable, 1_000L)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        releaseCompletionPlayer()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildOngoingNotification() =
        NotificationCompat.Builder(this, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.rest_timer_title))
            .setContentText(
                getString(
                    R.string.rest_timer_countdown,
                    exerciseName,
                    formatRemainingTime(),
                ),
            )
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setForegroundServiceBehavior(
                NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE,
            )
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .build()

    private fun formatRemainingTime(): String {
        val remainingSeconds = ceil(
            (endsAtMillis - System.currentTimeMillis()).coerceAtLeast(0L) / 1_000.0,
        ).toLong()
        val hours = remainingSeconds / 3_600
        val minutes = (remainingSeconds % 3_600) / 60
        val seconds = remainingSeconds % 60
        return if (hours > 0) {
            String.format(Locale.getDefault(), "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.getDefault(), "%02d:%02d", minutes, seconds)
        }
    }

    private fun showFinishedNotification() {
        val builder = NotificationCompat.Builder(this, FINISHED_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.rest_timer_finished_title))
            .setContentText(getString(R.string.rest_timer_finished_body))
            .setContentIntent(openAppIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(FINISHED_VIBRATION_PATTERN)
            .setDefaults(NotificationCompat.DEFAULT_LIGHTS)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
        getSystemService(NotificationManager::class.java).notify(
            FINISHED_NOTIFICATION_ID,
            builder.build(),
        )
    }

    private fun finishTimer(expectedSessionId: String? = null): Boolean {
        if (timerFinished ||
            (expectedSessionId != null && expectedSessionId != sessionId)
        ) {
            return false
        }

        timerFinished = true
        handler.removeCallbacks(tickRunnable)
        showFinishedNotification()
        if (soundEnabled) {
            playFinishedSound()
        } else {
            stopTimerService()
        }
        return true
    }

    private fun playFinishedSound() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val player = try {
            MediaPlayer.create(this, R.raw.exom_rest_finished, attributes, 0)
        } catch (_: RuntimeException) {
            null
        }
        if (player == null) {
            stopTimerService()
            return
        }

        completionPlayer = player
        requestCompletionAudioFocus(attributes)
        player.setVolume(1.0f, 1.0f)
        player.setOnCompletionListener { completedPlayer ->
            if (completionPlayer === completedPlayer) {
                releaseCompletionPlayer()
                stopTimerService()
            }
        }
        player.setOnErrorListener { failedPlayer, _, _ ->
            if (completionPlayer === failedPlayer) {
                releaseCompletionPlayer()
                stopTimerService()
            }
            true
        }
        try {
            player.start()
        } catch (_: RuntimeException) {
            releaseCompletionPlayer()
            stopTimerService()
        }
    }

    @Suppress("DEPRECATION")
    private fun requestCompletionAudioFocus(attributes: AudioAttributes) {
        val audioManager = getSystemService(AudioManager::class.java)
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(audioFocusChangeListener, handler)
                .build()
                .also { audioFocusRequest = it }
                .let(audioManager::requestAudioFocus)
        } else {
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
        }
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun abandonCompletionAudioFocus() {
        val audioManager = getSystemService(AudioManager::class.java)
        if (hasAudioFocus) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let(audioManager::abandonAudioFocusRequest)
            } else {
                audioManager.abandonAudioFocus(audioFocusChangeListener)
            }
        }
        audioFocusRequest = null
        hasAudioFocus = false
    }

    private fun releaseCompletionPlayer() {
        completionPlayer?.setOnCompletionListener(null)
        completionPlayer?.setOnErrorListener(null)
        completionPlayer?.release()
        completionPlayer = null
        abandonCompletionAudioFocus()
    }

    private fun stopTimerService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun openAppIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)!!.apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel(LEGACY_FINISHED_CHANNEL_ID)
        manager.deleteNotificationChannel(LEGACY_FINISHED_CHANNEL_V2_ID)
        manager.deleteNotificationChannel(LEGACY_SILENT_FINISHED_CHANNEL_ID)
        manager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL_ID,
                getString(R.string.rest_timer_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = getString(R.string.rest_timer_channel_description) },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                FINISHED_CHANNEL_ID,
                getString(R.string.rest_timer_finished_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = getString(R.string.rest_timer_finished_channel_description)
                enableVibration(true)
                vibrationPattern = FINISHED_VIBRATION_PATTERN
                setSound(null, null)
            },
        )
    }

    companion object {
        const val ACTION_START = "com.exommethod.exom.action.START_REST_TIMER"
        const val ACTION_FINISH = "com.exommethod.exom.action.FINISH_REST_TIMER"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_EXERCISE_NAME = "exercise_name"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"
        const val EXTRA_ENDS_AT_MILLIS = "ends_at_millis"
        const val EXTRA_SOUND_ENABLED = "sound_enabled"

        private const val ONGOING_CHANNEL_ID = "exom_rest_timer"
        private const val FINISHED_CHANNEL_ID = "exom_rest_finished_v3"
        private const val LEGACY_FINISHED_CHANNEL_ID = "exom_rest_finished"
        private const val LEGACY_FINISHED_CHANNEL_V2_ID = "exom_rest_finished_v2"
        private const val LEGACY_SILENT_FINISHED_CHANNEL_ID = "exom_rest_finished_silent"
        private const val ONGOING_NOTIFICATION_ID = 41020
        private const val FINISHED_NOTIFICATION_ID = 41021
        private val FINISHED_VIBRATION_PATTERN = longArrayOf(0, 300, 150, 500)
    }
}

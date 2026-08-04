package com.exommethod.exom

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import java.util.Locale
import kotlin.math.ceil

class RestTimerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var sessionId: String? = null
    private var endsAtMillis = 0L
    private var durationSeconds = 0
    private var exerciseName = ""

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (System.currentTimeMillis() >= endsAtMillis) {
                showFinishedNotification()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
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
        if (intent?.action != ACTION_START) return START_NOT_STICKY

        sessionId = intent.getStringExtra(EXTRA_SESSION_ID)
        endsAtMillis = intent.getLongExtra(EXTRA_ENDS_AT_MILLIS, 0L)
        exerciseName = intent.getStringExtra(EXTRA_EXERCISE_NAME).orEmpty()
        durationSeconds = intent.getIntExtra(EXTRA_DURATION_SECONDS, 0)
        if (endsAtMillis <= System.currentTimeMillis() || durationSeconds <= 0) {
            showFinishedNotification()
            stopSelf()
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
        val notification = NotificationCompat.Builder(this, FINISHED_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.rest_timer_finished_title))
            .setContentText(getString(R.string.rest_timer_finished_body))
            .setContentIntent(openAppIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .build()
        getSystemService(NotificationManager::class.java).notify(
            FINISHED_NOTIFICATION_ID,
            notification,
        )
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
                vibrationPattern = longArrayOf(0, 300, 150, 500)
                setSound(
                    Settings.System.DEFAULT_NOTIFICATION_URI,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                        .build(),
                )
            },
        )
    }

    companion object {
        const val ACTION_START = "com.exommethod.exom.action.START_REST_TIMER"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_EXERCISE_NAME = "exercise_name"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"
        const val EXTRA_ENDS_AT_MILLIS = "ends_at_millis"

        private const val ONGOING_CHANNEL_ID = "exom_rest_timer"
        private const val FINISHED_CHANNEL_ID = "exom_rest_finished"
        private const val ONGOING_NOTIFICATION_ID = 41020
        private const val FINISHED_NOTIFICATION_ID = 41021
    }
}

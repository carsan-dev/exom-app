package com.exommethod.exom

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.exommethod.exom/rest_timer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        requestNotificationPermissionIfNeeded()
                        val intent = Intent(this, RestTimerService::class.java).apply {
                            action = RestTimerService.ACTION_START
                            putExtra(RestTimerService.EXTRA_SESSION_ID, call.argument<String>("id"))
                            putExtra(RestTimerService.EXTRA_EXERCISE_NAME, call.argument<String>("exerciseName"))
                            putExtra(RestTimerService.EXTRA_DURATION_SECONDS, call.argument<Int>("durationSeconds") ?: 0)
                            putExtra(RestTimerService.EXTRA_ENDS_AT_MILLIS, call.argument<Number>("endsAtMillis")?.toLong() ?: 0L)
                            putExtra(RestTimerService.EXTRA_SOUND_ENABLED, call.argument<Boolean>("soundEnabled") ?: true)
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }
                    "cancel" -> {
                        stopService(Intent(this, RestTimerService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermissionIfNeeded() {
        val preferences = getSharedPreferences("exom_rest_timer", MODE_PRIVATE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED &&
            !preferences.getBoolean("notification_permission_requested", false)
        ) {
            preferences.edit().putBoolean("notification_permission_requested", true).apply()
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
    }
}

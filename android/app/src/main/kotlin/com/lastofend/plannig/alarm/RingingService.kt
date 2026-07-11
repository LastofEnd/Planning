package com.lastofend.plannig.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.lastofend.plannig.MainActivity
import com.lastofend.plannig.R

class RingingService : Service() {

    companion object {
        const val CHANNEL_ID = "smart_alarm_main"
        const val NOTIF_ID = 20001

        const val ACTION_START = "com.lastofend.plannig.ACTION_RING_START"
        const val ACTION_STOP = "com.lastofend.plannig.ACTION_RING_STOP"
        const val ACTION_SNOOZE = "com.lastofend.plannig.ACTION_RING_SNOOZE"
    }

    private var ringtone: Ringtone? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                val payload = intent.getStringExtra("payload") ?: ""
                val requireMathToDismiss = intent.getBooleanExtra("requireMathToDismiss", false) || payload.contains("|math")
                if (requireMathToDismiss) {
                    openAlarmScreen(payload, requireMathToDismiss)
                    return START_STICKY
                }
                stopRinging()
                return START_NOT_STICKY
            }

            ACTION_SNOOZE -> {
                val id = intent.getIntExtra("id", 0)
                val originalPayload = intent.getStringExtra("payload") ?: ""
                val payloadOnceNoSnooze =
                    if (originalPayload.endsWith("|nosnooze")) originalPayload
                    else "$originalPayload|nosnooze"
                val requireMathToDismiss = intent.getBooleanExtra("requireMathToDismiss", false) || payloadOnceNoSnooze.contains("|math")

                val strings = AlarmLocalization.load(this)
                val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val fireIntent = Intent(this, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_FIRE
                    putExtra("id", id)
                    putExtra("title", strings.snoozedTitle)
                    putExtra("body", strings.snoozedBody)
                    putExtra("payload", payloadOnceNoSnooze)
                    putExtra("canSnooze5", false)
                    putExtra("requireMathToDismiss", requireMathToDismiss)
                }
                val pi = PendingIntent.getBroadcast(
                    this,
                    id,
                    fireIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val whenMs = System.currentTimeMillis() + 5 * 60_000L
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, whenMs, pi)
                }

                stopRinging()
                return START_NOT_STICKY
            }

            else -> {
                val id = intent?.getIntExtra("id", 0) ?: 0
                val title = intent?.getStringExtra("title") ?: "Alarm"
                val body = intent?.getStringExtra("body") ?: "Time!"
                val payload = intent?.getStringExtra("payload") ?: ""
                val requireMathToDismiss = (intent?.getBooleanExtra("requireMathToDismiss", false) ?: false) || payload.contains("|math")

                var canSnooze5 = intent?.getBooleanExtra("canSnooze5", false) ?: false
                if (!canSnooze5 && payload.contains("|cansnooze") && !payload.contains("|nosnooze")) {
                    canSnooze5 = true
                }

                val strings = AlarmLocalization.load(this)
                createChannelIfNeeded(strings)

                val launchIntent = Intent(this, MainActivity::class.java).apply {
                    action = "com.lastofend.plannig.ACTION_ALARM_TAP"
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("payload", payload)
                    putExtra("requireMathToDismiss", requireMathToDismiss)
                }
                val fullScreenPi = PendingIntent.getActivity(
                    this,
                    id,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val stopPi = PendingIntent.getService(
                    this,
                    id xor 0x51AA,
                    Intent(this, RingingService::class.java).apply {
                        action = ACTION_STOP
                        putExtra("payload", payload)
                        putExtra("requireMathToDismiss", requireMathToDismiss)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val snoozePi = PendingIntent.getService(
                    this,
                    id xor 0x5A00,
                    Intent(this, RingingService::class.java).apply {
                        action = ACTION_SNOOZE
                        putExtra("id", id)
                        putExtra("payload", payload)
                        putExtra("requireMathToDismiss", requireMathToDismiss)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setFullScreenIntent(fullScreenPi, true)
                    .setContentIntent(fullScreenPi)
                    .setOngoing(true)

                if (canSnooze5) builder.addAction(0, strings.actionSnooze5, snoozePi)
                if (requireMathToDismiss) {
                    builder.addAction(0, strings.actionSolve, fullScreenPi)
                } else {
                    builder.addAction(0, strings.actionStop, stopPi)
                }

                startForeground(NOTIF_ID, builder.build())

                val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri).apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = true
                    audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    play()
                }

                return START_STICKY
            }
        }
    }

    private fun openAlarmScreen(payload: String, requireMathToDismiss: Boolean) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = "com.lastofend.plannig.ACTION_ALARM_TAP"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("payload", payload)
            putExtra("requireMathToDismiss", requireMathToDismiss)
        }
        startActivity(launchIntent)
    }

    private fun stopRinging() {
        try { ringtone?.stop() } catch (_: Throwable) {}
        ringtone = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        try { ringtone?.stop() } catch (_: Throwable) {}
        ringtone = null
        super.onDestroy()
    }

    private fun createChannelIfNeeded(strings: AlarmStrings) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID, strings.channelName, NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = strings.channelDescription
                setShowBadge(true)
                enableVibration(true)
            }
            nm.createNotificationChannel(ch)
        }
    }
}

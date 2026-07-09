package com.lastofend.plannig.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.lastofend.plannig.R

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE = "com.lastofend.plannig.ACTION_ALARM_FIRE"
        private const val WAKE_TAG = "plannig:alarm_wakelock"
        private const val FALLBACK_NOTIF_ID = 77
        private const val CHANNEL_ID = "smart_alarm_main"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE) return

        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "Alarm"
        val body = intent.getStringExtra("body") ?: ""
        val payload = intent.getStringExtra("payload") ?: ""
        val requireMathToDismiss = intent.getBooleanExtra("requireMathToDismiss", false) || payload.contains("|math")

        var canSnooze5 = intent.getBooleanExtra("canSnooze5", false)
        if (!canSnooze5 && payload.contains("|cansnooze") && !payload.contains("|nosnooze")) {
            canSnooze5 = true
        }

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_TAG).apply {
            setReferenceCounted(false)
            try { acquire(10_000L) } catch (_: Throwable) {}
        }

        val s = Intent(context, RingingService::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("payload", payload)
            putExtra("canSnooze5", canSnooze5)
            putExtra("requireMathToDismiss", requireMathToDismiss)
        }

        try {
            context.startForegroundService(s)
            Log.i("ALARM", "RingingService started id=$id requireMathToDismiss=$requireMathToDismiss")
        } catch (t: Throwable) {
            Log.e("ALARM", "Failed to start foreground service, fallback notif", t)
            try {
                val notif = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(title)
                    .setContentText(if (body.isEmpty()) "Час події" else body)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setAutoCancel(true)
                    .build()
                NotificationManagerCompat.from(context)
                    .notify(FALLBACK_NOTIF_ID + (id and 0x0FFF), notif)
            } catch (_: Throwable) {}
        } finally {
            try { wl.release() } catch (_: Throwable) {}
        }
    }
}

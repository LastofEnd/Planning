package com.lastofend.plannig.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.lastofend.plannig.MainActivity

class RingingActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            RingingService.ACTION_STOP -> {
                val payload = intent.getStringExtra("payload") ?: ""
                val requireMathToDismiss = intent.getBooleanExtra("requireMathToDismiss", false) || payload.contains("|math")
                if (requireMathToDismiss) {
                    val launch = Intent(context, MainActivity::class.java).apply {
                        action = "com.lastofend.plannig.ACTION_ALARM_TAP"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        putExtra("payload", payload)
                        putExtra("requireMathToDismiss", true)
                    }
                    context.startActivity(launch)
                } else {
                    context.stopService(Intent(context, RingingService::class.java))
                }
            }
            RingingService.ACTION_SNOOZE -> {
                context.stopService(Intent(context, RingingService::class.java))

                val id = intent.getIntExtra("id", 0)
                val payload = intent.getStringExtra("payload") ?: "test|notify"
                val requireMathToDismiss = intent.getBooleanExtra("requireMathToDismiss", false) || payload.contains("|math")

                val strings = AlarmLocalization.load(context)
                val schedule = Intent(AlarmReceiver.ACTION_FIRE).apply {
                    setPackage(context.packageName)
                    putExtra("id", id)
                    putExtra("title", strings.snoozedTitle)
                    putExtra("body", strings.snoozedBody)
                    putExtra("payload", if (payload.contains("|nosnooze")) payload else "$payload|nosnooze")
                    putExtra("repeatDaily", false)
                    putExtra("preCall", false)
                    putExtra("whenMs", System.currentTimeMillis() + 5 * 60_000)
                    putExtra("canSnooze5", false)
                    putExtra("requireMathToDismiss", requireMathToDismiss)
                }
                val pi = PendingIntent.getBroadcast(
                    context, id, schedule,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val whenMs = System.currentTimeMillis() + 5 * 60_000
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
            }
        }
    }
}

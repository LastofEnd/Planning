package com.lastofend.plannig

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.lastofend.plannig.alarm.AlarmLocalization
import com.lastofend.plannig.alarm.RingingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "plannig/alarm"
    private var methodChannel: MethodChannel? = null
    private var pendingAlarmPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pendingAlarmPayload = pendingAlarmPayload ?: extractAlarmPayload(intent)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val id = call.argument<Int>("id")!!
                    val whenMs = call.argument<Long>("whenMs")!!
                    val title = call.argument<String>("title") ?: "Alarm"
                    val body = call.argument<String>("body") ?: "Time!"
                    val payload = call.argument<String>("payload") ?: ""
                    val canSnooze5 = call.argument<Boolean>("canSnooze5") ?: false
                    val requireMathToDismiss =
                        (call.argument<Boolean>("requireMathToDismiss") ?: false) || payload.contains("|math")

                    scheduleExactAlarm(
                        id = id,
                        whenMs = whenMs,
                        title = title,
                        body = body,
                        payload = payload,
                        canSnooze5 = canSnooze5,
                        requireMathToDismiss = requireMathToDismiss
                    )
                    result.success(null)
                }
                "cancel" -> {
                    val id = call.argument<Int>("id")!!
                    cancelAlarm(id)
                    result.success(null)
                }
                "stopRinging" -> {
                    stopService(Intent(this, RingingService::class.java))
                    result.success(null)
                }
                "syncLocalization" -> {
                    val values = call.arguments as? Map<*, *> ?: emptyMap<String, String>()
                    AlarmLocalization.save(this, values)
                    result.success(null)
                }
                "consumeLaunchPayload" -> {
                    val payload = pendingAlarmPayload ?: extractAlarmPayload(intent)
                    pendingAlarmPayload = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractAlarmPayload(intent)
        if (!payload.isNullOrEmpty()) {
            pendingAlarmPayload = payload
            methodChannel?.invokeMethod("alarmLaunch", payload)
        }
    }

    private fun extractAlarmPayload(intent: Intent?): String? {
        val payload = intent?.getStringExtra("payload") ?: return null
        if (payload.isBlank()) return null
        return payload
    }

    private fun scheduleExactAlarm(
        id: Int,
        whenMs: Long,
        title: String,
        body: String,
        payload: String,
        canSnooze5: Boolean,
        requireMathToDismiss: Boolean
    ) {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val finalRequireMath = requireMathToDismiss || payload.contains("|math")

        val fireIntent = Intent("com.lastofend.plannig.ACTION_ALARM_FIRE").apply {
            setPackage(packageName)
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("payload", payload)
            putExtra("canSnooze5", canSnooze5)
            putExtra("requireMathToDismiss", finalRequireMath)
        }
        val firePi = PendingIntent.getBroadcast(
            this,
            id,
            fireIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val isMainAlarm = payload.contains("|alarm") && !payload.contains("precall")
        if (isMainAlarm) {
            val showIntent = Intent(this, MainActivity::class.java).apply {
                action = "com.lastofend.plannig.ACTION_SHOW_ALARM"
                putExtra("payload", payload)
                putExtra("requireMathToDismiss", finalRequireMath)
            }
            val showPi = PendingIntent.getActivity(
                this,
                id,
                showIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val info = AlarmManager.AlarmClockInfo(whenMs, showPi)
            am.setAlarmClock(info, firePi)
        } else {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, firePi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, whenMs, firePi)
            }
        }

        Log.i(
            "ALARM",
            "scheduled id=$id at=$whenMs via ${if (isMainAlarm) "AlarmClock" else "Exact"} canSnooze5=$canSnooze5 requireMathToDismiss=$finalRequireMath"
        )
    }

    private fun cancelAlarm(id: Int) {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent("com.lastofend.plannig.ACTION_ALARM_FIRE").apply {
            setPackage(packageName)
        }
        val pi = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) {
            am.cancel(pi)
            pi.cancel()
        }
        Log.i("ALARM", "cancelled id=$id")
    }
}

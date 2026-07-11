package com.lastofend.plannig.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import java.util.Calendar

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i("ALARM", "BootReceiver: $action → reschedule all")

        try {
            val strings = AlarmLocalization.load(context)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.events_v1", null) ?: return
            val arr = JSONArray(raw)

            for (i in 0 until arr.length()) {
                val e = arr.getJSONObject(i)
                val enabled = e.optBoolean("enabled", true)
                if (!enabled) continue

                val id = e.getString("id")
                val title = e.optString("title", "Alarm")
                val body = e.optString("description", strings.eventTime)
                val hour = e.optInt("hour", 9)
                val minute = e.optInt("minute", 0)
                val canSnooze5 = e.optBoolean("canSnooze5", false)
                val requireMathToDismiss = e.optBoolean("requireMathToDismiss", false)
                val callBefore5 = e.optBoolean("callBefore5", false)
                val repeatDaily = e.optBoolean("repeatDaily", false)
                val weekly = e.optBoolean("weekly", false)
                val weekdays = (e.opt("weekdays") as? JSONArray)?.let { ja ->
                    (0 until ja.length()).map { ja.getInt(it) }
                } ?: emptyList()

                val isOneOff = e.optBoolean("isOneOff", false)
                val oneOffIso = e.optString("oneOffDate", "")
                if (isOneOff && oneOffIso.isNotEmpty()) {
                    val parts = oneOffIso.split("-")
                    if (parts.size == 3) {
                        val y = parts[0].toIntOrNull() ?: 0
                        val m = parts[1].toIntOrNull() ?: 0
                        val d = parts[2].toIntOrNull() ?: 0
                        if (y > 0 && m in 1..12 && d in 1..31) {
                            val cal = Calendar.getInstance().apply {
                                set(Calendar.YEAR, y)
                                set(Calendar.MONTH, m - 1)
                                set(Calendar.DAY_OF_MONTH, d)
                                set(Calendar.HOUR_OF_DAY, hour)
                                set(Calendar.MINUTE, minute)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            val whenMs = cal.timeInMillis
                            if (whenMs > System.currentTimeMillis()) {
                                scheduleExact(
                                    context = context,
                                    id = mainId(id),
                                    whenMs = whenMs,
                                    title = title,
                                    body = body,
                                    payload = payload(id, canSnooze5, requireMathToDismiss)
                                )
                                if (callBefore5) {
                                    val preMs = whenMs - 5 * 60 * 1000
                                    if (preMs > System.currentTimeMillis()) {
                                        scheduleExact(
                                            context = context,
                                            id = preId(id),
                                            whenMs = preMs,
                                            title = strings.before5Title,
                                            body = strings.before5Body.replace("{title}", title),
                                            payload = "$id|precall"
                                        )
                                    }
                                }
                            }
                        }
                    }
                    continue
                }

                if (weekly && weekdays.isNotEmpty()) {
                    weekdays.forEach { wd ->
                        val whenMs = nextOccurrenceForWeekdayMs(wd, hour, minute)
                        scheduleExact(
                            context = context,
                            id = mainIdForDay(id, wd),
                            whenMs = whenMs,
                            title = title,
                            body = body,
                            payload = payload(id, canSnooze5, requireMathToDismiss)
                        )
                        if (callBefore5) {
                            val preMs = whenMs - 5 * 60 * 1000
                            if (preMs > System.currentTimeMillis()) {
                                scheduleExact(
                                    context = context,
                                    id = preIdForDay(id, wd),
                                    whenMs = preMs,
                                    title = strings.before5Title,
                                    body = strings.before5Body.replace("{title}", title),
                                    payload = "$id|precall"
                                )
                            }
                        }
                    }
                } else {
                    val whenMs = nextTodayOrTomorrowMs(hour, minute)
                    scheduleExact(
                        context = context,
                        id = mainId(id),
                        whenMs = whenMs,
                        title = title,
                        body = body,
                        payload = payload(id, canSnooze5, requireMathToDismiss)
                    )
                    if (callBefore5) {
                        val preMs = whenMs - 5 * 60 * 1000
                        if (preMs > System.currentTimeMillis()) {
                            scheduleExact(
                                context = context,
                                id = preId(id),
                                whenMs = preMs,
                                title = strings.before5Title,
                                body = strings.before5Body.replace("{title}", title),
                                payload = "$id|precall"
                            )
                        }
                    }
                }
            }
        } catch (t: Throwable) {
            Log.e("ALARM", "BootReceiver error: ${t.message}", t)
        }
    }

    private fun fnv1a32(s: String): Int {
        var hash = 0x811c9dc5u
        val prime = 0x01000193u
        s.encodeToByteArray().forEach { b ->
            hash = hash xor (b.toUByte().toUInt())
            hash *= prime
        }
        return hash.toInt()
    }
    private fun mainId(id: String) = fnv1a32(id)
    private fun preId(id: String) = fnv1a32(id) xor 777
    private fun mainIdForDay(id: String, weekday: Int) = fnv1a32(id) xor (weekday * 1111)
    private fun preIdForDay(id: String, weekday: Int) = fnv1a32(id) xor (weekday * 1111) xor 777
    private fun payload(id: String, canSnooze: Boolean, requireMathToDismiss: Boolean): String {
        val parts = mutableListOf(id, "alarm")
        if (canSnooze) parts.add("cansnooze")
        if (requireMathToDismiss) parts.add("math")
        return parts.joinToString("|")
    }

    private fun nextTodayOrTomorrowMs(h: Int, m: Int): Long {
        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, h)
            set(Calendar.MINUTE, m)
        }
        if (cal.timeInMillis <= now) cal.add(Calendar.DATE, 1)
        return cal.timeInMillis
    }

    private fun nextOccurrenceForWeekdayMs(weekday: Int, h: Int, m: Int): Long {
        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, h)
            set(Calendar.MINUTE, m)
        }
        val todayUs = cal.get(Calendar.DAY_OF_WEEK)
        fun toIso(dowUs: Int): Int = if (dowUs == Calendar.SUNDAY) 7 else dowUs - 1
        var addDays = (weekday - toIso(todayUs)) % 7
        if (addDays < 0) addDays += 7
        cal.add(Calendar.DATE, addDays)
        if (cal.timeInMillis <= now) cal.add(Calendar.DATE, 7)
        return cal.timeInMillis
    }

    private fun scheduleExact(
        context: Context,
        id: Int,
        whenMs: Long,
        title: String,
        body: String,
        payload: String
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val fireIntent = Intent("com.lastofend.plannig.ACTION_ALARM_FIRE").apply {
            setPackage(context.packageName)
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("payload", payload)
            putExtra("requireMathToDismiss", payload.contains("|math"))
        }
        val firePi = PendingIntent.getBroadcast(
            context, id, fireIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val isMainAlarm = payload.contains("|alarm") && !payload.contains("precall")
        if (isMainAlarm) {
          val showIntent = Intent(context, com.lastofend.plannig.MainActivity::class.java).apply {
              action = "com.lastofend.plannig.ACTION_SHOW_ALARM"
              putExtra("payload", payload)
              putExtra("requireMathToDismiss", payload.contains("|math"))
          }
          val showPi = PendingIntent.getActivity(
              context, id, showIntent,
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

        Log.i("ALARM", "BOOT schedule id=$id at=$whenMs via ${if (isMainAlarm) "AlarmClock" else "Exact"} requireMathToDismiss=${payload.contains("|math")}")
    }
}

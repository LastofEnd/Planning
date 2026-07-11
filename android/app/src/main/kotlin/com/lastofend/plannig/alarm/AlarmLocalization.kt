package com.lastofend.plannig.alarm

import android.content.Context

data class AlarmStrings(
    val actionStop: String,
    val actionSolve: String,
    val actionSnooze5: String,
    val snoozedTitle: String,
    val snoozedBody: String,
    val eventTime: String,
    val before5Title: String,
    val before5Body: String,
    val channelName: String,
    val channelDescription: String
)

object AlarmLocalization {
    private const val PREFS_NAME = "native_alarm_i18n"

    private const val KEY_ACTION_STOP = "actionStop"
    private const val KEY_ACTION_SOLVE = "actionSolve"
    private const val KEY_ACTION_SNOOZE_5 = "actionSnooze5"
    private const val KEY_SNOOZED_TITLE = "snoozedTitle"
    private const val KEY_SNOOZED_BODY = "snoozedBody"
    private const val KEY_EVENT_TIME = "eventTime"
    private const val KEY_BEFORE_5_TITLE = "before5Title"
    private const val KEY_BEFORE_5_BODY = "before5Body"
    private const val KEY_CHANNEL_NAME = "channelName"
    private const val KEY_CHANNEL_DESCRIPTION = "channelDescription"

    fun save(context: Context, values: Map<*, *>) {
        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        values.forEach { (key, value) ->
            if (key is String && value is String) {
                editor.putString(key, value)
            }
        }
        editor.apply()
    }

    fun load(context: Context): AlarmStrings {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return AlarmStrings(
            actionStop = prefs.getString(KEY_ACTION_STOP, "Stop") ?: "Stop",
            actionSolve = prefs.getString(KEY_ACTION_SOLVE, "Solve") ?: "Solve",
            actionSnooze5 = prefs.getString(KEY_ACTION_SNOOZE_5, "Snooze 5 min") ?: "Snooze 5 min",
            snoozedTitle = prefs.getString(KEY_SNOOZED_TITLE, "Snoozed: alarm") ?: "Snoozed: alarm",
            snoozedBody = prefs.getString(KEY_SNOOZED_BODY, "In 5 minutes") ?: "In 5 minutes",
            eventTime = prefs.getString(KEY_EVENT_TIME, "Event time") ?: "Event time",
            before5Title = prefs.getString(KEY_BEFORE_5_TITLE, "Reminder in 5 min") ?: "Reminder in 5 min",
            before5Body = prefs.getString(KEY_BEFORE_5_BODY, "{title} starts soon") ?: "{title} starts soon",
            channelName = prefs.getString(KEY_CHANNEL_NAME, "Smart Alarm") ?: "Smart Alarm",
            channelDescription = prefs.getString(KEY_CHANNEL_DESCRIPTION, "Alarm notifications") ?: "Alarm notifications"
        )
    }
}

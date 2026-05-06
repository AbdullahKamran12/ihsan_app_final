package com.ihsan.ihsanapp

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.IBinder
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.*

class WidgetClockService : Service() {

    private val tickReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            updateAllWidgets(context)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        registerReceiver(tickReceiver, IntentFilter(Intent.ACTION_TIME_TICK))
        updateAllWidgets(this)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(tickReceiver)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, PrayerWidgetProvider::class.java)
        )
        val prefs = HomeWidgetPlugin.getData(context)
        fun get(key: String) = prefs.getString(key, "--:--") ?: "--:--"

        val now = Calendar.getInstance()
        val hour = now.get(Calendar.HOUR_OF_DAY)
        val minute = now.get(Calendar.MINUTE)
        val clockTime = String.format("%02d:%02d", hour, minute)
        val ampm = if (hour < 12) "AM" else "PM"

        val nextName = prefs.getString("w_next_prayer", "-") ?: "-"
        val nextTime = get("w_next_time")

        val gold  = Color.parseColor("#D4AF5F")
        val white = Color.parseColor("#EEF0FF")

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_wide)
            views.setTextViewText(R.id.w_clock,         clockTime)
            views.setTextViewText(R.id.w_clock_ampm,    ampm)
            views.setTextViewText(R.id.w_next_name,     nextName)
            views.setTextViewText(R.id.w_next_time,     nextTime)
            views.setTextViewText(R.id.w_fajr_adhan,    get("w_fajr_adhan"))
            views.setTextViewText(R.id.w_fajr_jamaat,   get("w_fajr_jamaat"))
            views.setTextViewText(R.id.w_sunrise_adhan, get("w_sunrise_adhan"))
            views.setTextViewText(R.id.w_dhuhr_adhan,   get("w_dhuhr_adhan"))
            views.setTextViewText(R.id.w_dhuhr_jamaat,  get("w_dhuhr_jamaat"))
            views.setTextViewText(R.id.w_asr_adhan,     get("w_asr_adhan"))
            views.setTextViewText(R.id.w_asr_jamaat,    get("w_asr_jamaat"))
            views.setTextViewText(R.id.w_maghrib_adhan, get("w_maghrib_adhan"))
            views.setTextViewText(R.id.w_isha_adhan,    get("w_isha_adhan"))
            views.setTextViewText(R.id.w_isha_jamaat,   get("w_isha_jamaat"))

            val nameIds = mapOf(
                "Fajr"  to R.id.w_fajr_name,
                "Dhuhr" to R.id.w_dhuhr_name
            )
            nameIds.values.forEach { views.setTextColor(it, white) }
            nameIds[nextName]?.let { rid -> views.setTextColor(rid, gold) }

            manager.updateAppWidget(id, views)
        }
    }
}
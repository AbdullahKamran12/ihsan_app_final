package com.ihsan.ihsanapp

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import com.ihsan.ihsanapp.R
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidgetSmallProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateSmall(context, appWidgetManager, id)
        }
    }

    override fun onEnabled(context: Context) {
        // Ensure the clock service is running so small widget also gets minute ticks
        val intent = android.content.Intent(context, WidgetClockService::class.java)
        context.startService(intent)
        WidgetClockService.scheduleNextExactMinute(context)
    }

    private fun updateSmall(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        fun get(key: String) = prefs.getString(key, "--:--") ?: "--:--"

        val views = RemoteViews(context.packageName, R.layout.prayer_widget_small)

        views.setTextViewText(R.id.s_fajr_adhan,    get("w_fajr_adhan"))
        views.setTextViewText(R.id.s_fajr_jamaat,   get("w_fajr_jamaat"))
        views.setTextViewText(R.id.s_sunrise_adhan, get("w_sunrise_adhan"))
        views.setTextViewText(R.id.s_dhuhr_adhan,   get("w_dhuhr_adhan"))
        views.setTextViewText(R.id.s_dhuhr_jamaat,  get("w_dhuhr_jamaat"))
        views.setTextViewText(R.id.s_asr_adhan,     get("w_asr_adhan"))
        views.setTextViewText(R.id.s_asr_jamaat,    get("w_asr_jamaat"))
        views.setTextViewText(R.id.s_maghrib_adhan, get("w_maghrib_adhan"))
        views.setTextViewText(R.id.s_isha_adhan,    get("w_isha_adhan"))
        views.setTextViewText(R.id.s_isha_jamaat,   get("w_isha_jamaat"))

        val nextName = prefs.getString("w_next_prayer", "") ?: ""
        val gold  = Color.parseColor("#D4AF5F")
        val white = Color.parseColor("#EEF0FF")

        val initIds = mapOf(
            "Fajr"    to R.id.s_fajr_init,
            "Sunrise" to R.id.s_sunrise_init,
            "Dhuhr"   to R.id.s_dhuhr_init,
            "Asr"     to R.id.s_asr_init,
            "Maghrib" to R.id.s_maghrib_init,
            "Isha"    to R.id.s_isha_init
        )
        initIds.values.forEach { views.setTextColor(it, white) }
        initIds[nextName]?.let { id -> views.setTextColor(id, gold) }

        // Tap anywhere on the small widget → PrayerScreen
        views.setOnClickPendingIntent(
            android.R.id.content,   // root view fallback
            WidgetClockService.buildTapIntent(context)
        )
        // Also set on the layout root — use a full-width invisible overlay approach:
        // set the intent on each row layout ID isn't possible without extra IDs,
        // so set it on the background root instead
        try {
            // prayer_widget_small root LinearLayout has no explicit id; set intent
            // on a known child that covers most of the widget (first init TextView)
            // The cleanest approach is to add android:id="@+id/s_root" to the XML root.
            // If you've done that, replace android.R.id.content below with R.id.s_root.
            views.setOnClickPendingIntent(
                R.id.s_fajr_init,   // fallback: tap on initials column opens app
                WidgetClockService.buildTapIntent(context)
            )
            views.setOnClickPendingIntent(
                R.id.s_fajr_adhan,
                WidgetClockService.buildTapIntent(context)
            )
        } catch (_: Exception) {}

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
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

        val initIds = mapOf<String, Int>(
            "Fajr"    to R.id.s_fajr_init,
            "Sunrise" to R.id.s_sunrise_init,
            "Dhuhr"   to R.id.s_dhuhr_init,
            "Asr"     to R.id.s_asr_init,
            "Maghrib" to R.id.s_maghrib_init,
            "Isha"    to R.id.s_isha_init
        )
        initIds.values.forEach { views.setTextColor(it, white) }
        initIds[nextName]?.let { id -> views.setTextColor(id, gold) }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
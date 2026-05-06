package com.ihsan.ihsanapp  // ← your package

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.*

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        fun get(key: String) = prefs.getString(key, "--:--") ?: "--:--"

        val now = Calendar.getInstance()
        val hour = now.get(Calendar.HOUR_OF_DAY)
        val minute = now.get(Calendar.MINUTE)
        val clockTime = String.format("%02d:%02d", hour, minute)
        val ampm = if (hour < 12) "AM" else "PM"

        val nextName = prefs.getString("w_next_prayer", "—") ?: "—"
        val nextTime = get("w_next_time")

        // ── 2×2 small widget ──────────────────────────────────────────
        val small = RemoteViews(context.packageName, R.layout.prayer_widget_small)
        small.setTextViewText(R.id.s_fajr_adhan,    get("w_fajr_adhan"))
        small.setTextViewText(R.id.s_fajr_jamaat,   get("w_fajr_jamaat"))
        small.setTextViewText(R.id.s_sunrise_adhan, get("w_sunrise_adhan"))
        small.setTextViewText(R.id.s_dhuhr_adhan,   get("w_dhuhr_adhan"))
        small.setTextViewText(R.id.s_dhuhr_jamaat,  get("w_dhuhr_jamaat"))
        small.setTextViewText(R.id.s_asr_adhan,     get("w_asr_adhan"))
        small.setTextViewText(R.id.s_asr_jamaat,    get("w_asr_jamaat"))
        small.setTextViewText(R.id.s_maghrib_adhan, get("w_maghrib_adhan"))
        small.setTextViewText(R.id.s_isha_adhan,    get("w_isha_adhan"))
        small.setTextViewText(R.id.s_isha_jamaat,   get("w_isha_jamaat"))

        // Highlight current / next prayer row gold
        highlightSmallRow(small, nextName)

        // ── 2×4 wide widget ───────────────────────────────────────────
        val wide = RemoteViews(context.packageName, R.layout.prayer_widget_wide)
        wide.setTextViewText(R.id.w_clock,      clockTime)
        wide.setTextViewText(R.id.w_clock_ampm, ampm)
        wide.setTextViewText(R.id.w_next_name,  nextName)
        wide.setTextViewText(R.id.w_next_time,  nextTime)

        wide.setTextViewText(R.id.w_fajr_adhan,    get("w_fajr_adhan"))
        wide.setTextViewText(R.id.w_fajr_jamaat,   get("w_fajr_jamaat"))
        wide.setTextViewText(R.id.w_sunrise_adhan, get("w_sunrise_adhan"))
        wide.setTextViewText(R.id.w_dhuhr_adhan,   get("w_dhuhr_adhan"))
        wide.setTextViewText(R.id.w_dhuhr_jamaat,  get("w_dhuhr_jamaat"))
        wide.setTextViewText(R.id.w_asr_adhan,     get("w_asr_adhan"))
        wide.setTextViewText(R.id.w_asr_jamaat,    get("w_asr_jamaat"))
        wide.setTextViewText(R.id.w_maghrib_adhan, get("w_maghrib_adhan"))
        wide.setTextViewText(R.id.w_isha_adhan,    get("w_isha_adhan"))
        wide.setTextViewText(R.id.w_isha_jamaat,   get("w_isha_jamaat"))

        // Highlight next prayer column gold
        highlightWideCol(wide, nextName)

        appWidgetManager.updateAppWidget(widgetId, wide) // default to wide
        // If you register both providers separately, you'd pick here by widgetId
    }

    private val goldColor  = Color.parseColor("#D4AF5F")
    private val whiteColor = Color.parseColor("#EEF0FF")
    private val mutedColor = Color.parseColor("#8890C0")

    private fun highlightSmallRow(views: RemoteViews, nextPrayer: String) {
        // Map prayer name → initial TextView id
        val initIds = mapOf(
            "Fajr"    to R.id.s_fajr_init,
            "Sunrise" to R.id.s_sunrise_init,
            "Dhuhr"   to R.id.s_dhuhr_init,
            "Asr"     to R.id.s_asr_init,
            "Maghrib" to R.id.s_maghrib_init,
            "Isha"    to R.id.s_isha_init,
        )
        // Reset all to white, then gold the next
        initIds.values.forEach { views.setTextColor(it, whiteColor) }
        initIds[nextPrayer]?.let { views.setTextColor(it, goldColor) }
    }

    private fun highlightWideCol(views: RemoteViews, nextPrayer: String) {
        val nameIds = mapOf(
            "Fajr"  to R.id.w_fajr_name,
            "Dhuhr" to R.id.w_dhuhr_name,
        )
        nameIds.values.forEach { views.setTextColor(it, whiteColor) }
        nameIds[nextPrayer]?.let { views.setTextColor(it, goldColor) }
    }
}
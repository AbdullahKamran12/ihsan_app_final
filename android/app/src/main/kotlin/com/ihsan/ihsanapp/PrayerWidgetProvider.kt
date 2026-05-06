package com.ihsan.ihsanapp

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.*

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Start the clock service so it registers TIME_TICK dynamically
        context.startService(Intent(context, WidgetClockService::class.java))
    }

    override fun onEnabled(context: Context) {
        // First widget added — start service
        context.startService(Intent(context, WidgetClockService::class.java))
    }

    override fun onDisabled(context: Context) {
        // Last widget removed — stop service
        context.stopService(Intent(context, WidgetClockService::class.java))
    }
}
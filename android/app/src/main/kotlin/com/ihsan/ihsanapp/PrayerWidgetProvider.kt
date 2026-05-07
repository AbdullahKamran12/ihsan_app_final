package com.ihsan.ihsanapp

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Start the service for ongoing minute updates
        context.startService(Intent(context, WidgetClockService::class.java))
        // Force an immediate update for each widget (includes tap intent)
        for (id in appWidgetIds) {
            WidgetClockService.updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onEnabled(context: Context) {
        context.startService(Intent(context, WidgetClockService::class.java))
        WidgetClockService.scheduleNextExactMinute(context)
    }

    override fun onDisabled(context: Context) {
        context.stopService(Intent(context, WidgetClockService::class.java))
    }
}
package com.ihsan.ihsanapp

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Update all wide widgets
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, PrayerWidgetProvider::class.java)
        )
        for (id in ids) {
            WidgetClockService.updateWidget(context, manager, id)
        }

        // Also trigger small widget update
        val smallIds = manager.getAppWidgetIds(
            ComponentName(context, PrayerWidgetSmallProvider::class.java)
        )
        if (smallIds.isNotEmpty()) {
            val smallIntent = Intent(context, PrayerWidgetSmallProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, smallIds)
            }
            context.sendBroadcast(smallIntent)
        }

        // Chain next exact-minute alarm (keeps clock in perfect sync)
        WidgetClockService.scheduleNextExactMinute(context)
    }
}
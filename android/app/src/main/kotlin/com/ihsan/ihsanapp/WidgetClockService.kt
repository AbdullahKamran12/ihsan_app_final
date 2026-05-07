package com.ihsan.ihsanapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.*
import android.net.Uri
import android.os.Build
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
        try { registerReceiver(tickReceiver, IntentFilter(Intent.ACTION_TIME_TICK)) } catch (_: Exception) {}
        scheduleNextExactMinute(this)
        updateAllWidgets(this)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(tickReceiver) } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val wideIds = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
        for (id in wideIds) updateWidget(context, manager, id)

        val smallIds = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetSmallProvider::class.java))
        // Small widget has its own provider — trigger it via broadcast so its onUpdate fires
        if (smallIds.isNotEmpty()) {
            val smallIntent = Intent(context, PrayerWidgetSmallProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, smallIds)
            }
            context.sendBroadcast(smallIntent)
        }
    }

    companion object {

        const val ACTION_TICK = "com.ihsan.ihsanapp.WIDGET_TICK"

        // Deep-link URI that MainActivity should handle — adjust scheme/host to match your AndroidManifest intent-filter
        private const val PRAYER_SCREEN_URI = "ihsan://app/prayerScreen"

        private val COL_GRAD_TOP = Color.parseColor("#0A193C")
        private val COL_GRAD_BOT = Color.parseColor("#122A5F")
        private val COL_WHITE    = Color.parseColor("#FFFFFF")
        private val COL_GOLD     = Color.parseColor("#D4AF5F")
        private val COL_GREEN    = Color.parseColor("#90C8A0")
        private val COL_NAME     = Color.parseColor("#EEF0FF")
        private val COL_DIV      = Color.parseColor("#44FFFFFF")
        private val COL_MUTED    = Color.parseColor("#8890C8")

        private val PRAYERS = listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")

        // ── Tap intent ────────────────────────────────────────────────────────
        fun buildTapIntent(context: Context): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(PRAYER_SCREEN_URI)).apply {
                setPackage(context.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        // ── Clock-sync: schedule alarm at the NEXT exact minute boundary ──────
        //
        // ACTION_TIME_TICK fires ~every minute but Android can batch it late.
        // We chain setExact calls so the alarm always fires within ~1 s of :00.
        fun scheduleNextExactMinute(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetTickReceiver::class.java).apply {
                action = ACTION_TICK
            }
            val pi = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Next :00 second boundary
            val now        = System.currentTimeMillis()
            val nextMinute = (now / 60_000L + 1L) * 60_000L   // ms aligned to minute

            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms() -> {
                    // Fallback: inexact repeating (still usually within a few seconds)
                    am.setRepeating(AlarmManager.RTC_WAKEUP, nextMinute, 60_000L, pi)
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pi)
                }
                else -> {
                    am.setExact(AlarmManager.RTC_WAKEUP, nextMinute, pi)
                }
            }
        }

        // Keep old name so WidgetBootReceiver compiles without changes
        fun scheduleMinuteAlarm(context: Context) = scheduleNextExactMinute(context)

        private fun id(context: Context, name: String): Int =
            context.resources.getIdentifier(name, "id", context.packageName)

        private fun layout(context: Context, name: String): Int =
            context.resources.getIdentifier(name, "layout", context.packageName)

        // Returns true if any prayer data has been saved (widget not blank)
        private fun hasData(context: Context): Boolean {
            val prefs = HomeWidgetPlugin.getData(context)
            val v = prefs.getString("w_fajr_adhan", null)
            return !v.isNullOrBlank() && v != "--:--"
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = HomeWidgetPlugin.getData(context)
            fun get(key: String) = prefs.getString(key, "--:--") ?: "--:--"

            val dataReady = hasData(context)

            val now      = Calendar.getInstance()
            val hour     = now.get(Calendar.HOUR_OF_DAY)
            val minute   = now.get(Calendar.MINUTE)
            val clockStr = String.format("%02d:%02d", hour, minute)
            val ampm     = if (hour < 12) "AM" else "PM"

            val nextName = prefs.getString("w_next_prayer", "—") ?: "—"
            val nextTime = get("w_next_time")

            val adhan = listOf(
                get("w_fajr_adhan"),    get("w_sunrise_adhan"),
                get("w_dhuhr_adhan"),   get("w_asr_adhan"),
                get("w_maghrib_adhan"), get("w_isha_adhan")
            )
            val jamaat = listOf(
                get("w_fajr_jamaat"),   "",
                get("w_dhuhr_jamaat"),  get("w_asr_jamaat"),
                get("w_maghrib_adhan"), // Maghrib jamaat = adhan
                get("w_isha_jamaat")
            )

            val W    = 800
            val H    = 340
            val CR   = 24f
            val divY = 133f

            val bmp    = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val paint  = Paint(Paint.ANTI_ALIAS_FLAG)

            // ── Background gradient ───────────────────────────────────────────
            paint.shader = LinearGradient(
                0f, 0f, 0f, H.toFloat(),
                COL_GRAD_TOP, COL_GRAD_BOT,
                Shader.TileMode.CLAMP
            )
            canvas.drawRoundRect(RectF(0f, 0f, W.toFloat(), H.toFloat()), CR, CR, paint)
            paint.shader = null

            // ── Bottom panel tint ─────────────────────────────────────────────
            paint.color = Color.argb(60, 255, 255, 255)
            canvas.save()
            canvas.clipRect(0f, divY, W.toFloat(), H.toFloat())
            canvas.drawRoundRect(RectF(0f, 0f, W.toFloat(), H.toFloat()), CR, CR, paint)
            canvas.restore()

            // ── Divider ───────────────────────────────────────────────────────
            paint.color       = COL_DIV
            paint.strokeWidth = 1f
            paint.style       = Paint.Style.STROKE
            canvas.drawLine(0f, divY, W.toFloat(), divY, paint)
            paint.style = Paint.Style.FILL

            val headerCy   = divY / 2f
            val boldFace   = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            val normalFace = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)

            // ── Logo ──────────────────────────────────────────────────────────
            val logoId = context.resources.getIdentifier("logo", "drawable", context.packageName)
            if (logoId != 0) {
                val logoBmp = BitmapFactory.decodeResource(context.resources, logoId)
                if (logoBmp != null) {
                    val logoH  = (divY * 0.80f).toInt()
                    val logoW  = (logoBmp.width.toFloat() / logoBmp.height.toFloat() * logoH).toInt()
                    val scaled = Bitmap.createScaledBitmap(logoBmp, logoW, logoH, true)
                    canvas.drawBitmap(scaled, W / 2f - logoW / 2f, headerCy - logoH / 2f, Paint(Paint.ANTI_ALIAS_FLAG))
                }
            }

            // ── Clock ─────────────────────────────────────────────────────────
            paint.color     = COL_WHITE
            paint.typeface  = boldFace
            paint.textSize  = 85f
            paint.textAlign = Paint.Align.LEFT
            val clockW = paint.measureText(clockStr)
            canvas.drawText(clockStr, 28f, headerCy + 22f, paint)

            paint.typeface = normalFace
            paint.textSize = 32f
            canvas.drawText(ampm, 28f + clockW + 6f, headerCy + 22f, paint)

            // ── Next prayer (or loading hint) ─────────────────────────────────
            paint.color     = COL_GOLD
            paint.typeface  = boldFace
            paint.textAlign = Paint.Align.RIGHT

            if (!dataReady) {
                // Show a subtle "Open app to load" message instead of blank
                paint.textSize  = 26f
                paint.color     = COL_MUTED
                paint.typeface  = normalFace
                canvas.drawText("Open app to load times", W - 28f, headerCy - 8f, paint)
            } else {
                paint.textSize = 34f
                canvas.drawText(nextName, W - 28f, headerCy - 8f, paint)
                paint.textSize = 56f
                canvas.drawText(nextTime, W - 28f, headerCy + 52f, paint)
            }

            // ── Prayer columns ────────────────────────────────────────────────
            val colW    = W.toFloat() / PRAYERS.size
            val bodyTop = divY + 8f
            val bodyH   = H - divY - 8f
            val nameY   = bodyTop + bodyH * 0.28f
            val adhanY  = bodyTop + bodyH * 0.58f
            val jamaatY = bodyTop + bodyH * 0.90f

            for (i in PRAYERS.indices) {
                val cx     = colW * i + colW / 2f
                val isNext = PRAYERS[i].equals(nextName, ignoreCase = true) && dataReady

                if (i > 0) {
                    paint.color       = COL_DIV
                    paint.strokeWidth = 1f
                    paint.style       = Paint.Style.STROKE
                    canvas.drawLine(colW * i, divY + 10f, colW * i, H.toFloat() - 10f, paint)
                    paint.style = Paint.Style.FILL
                }

                paint.color     = if (isNext) COL_GOLD else COL_NAME
                paint.typeface  = boldFace
                paint.textSize  = 28f
                paint.textAlign = Paint.Align.CENTER
                canvas.drawText(PRAYERS[i], cx, nameY, paint)

                val adhanDisplay = if (dataReady) adhan[i] else "--:--"
                paint.color    = if (isNext) COL_GOLD else Color.argb(160, 0xD4, 0xAF, 0x5F)
                paint.typeface = normalFace
                paint.textSize = 30f
                canvas.drawText(adhanDisplay, cx, adhanY, paint)

                val jamaatDisplay = if (dataReady) jamaat[i] else ""
                if (jamaatDisplay.isNotEmpty()) {
                    paint.color    = if (isNext) COL_GOLD else COL_GREEN
                    paint.typeface = boldFace
                    paint.textSize = 34f
                    canvas.drawText(jamaatDisplay, cx, jamaatY, paint)
                }
            }

            // ── Write to RemoteViews ──────────────────────────────────────────
            val layoutId = layout(context, "prayer_widget_wide")
            val views    = RemoteViews(context.packageName, layoutId)
            views.setImageViewBitmap(id(context, "w_widget_image"), bmp)

            // Tap opens PrayerScreen
            views.setOnClickPendingIntent(id(context, "w_widget_image"), buildTapIntent(context))

            // Clear hidden stubs (keep R.id references alive)
            listOf(
                "w_clock", "w_next_name", "w_clock_ampm", "w_next_label",
                "w_next_time", "w_fajr_name", "w_fajr_adhan", "w_fajr_jamaat",
                "w_sunrise_adhan", "w_dhuhr_name", "w_dhuhr_adhan", "w_dhuhr_jamaat",
                "w_asr_adhan", "w_asr_jamaat", "w_maghrib_adhan",
                "w_isha_adhan", "w_isha_jamaat"
            ).forEach { name -> views.setTextViewText(id(context, name), "") }

            manager.updateAppWidget(widgetId, views)
        }
    }
}
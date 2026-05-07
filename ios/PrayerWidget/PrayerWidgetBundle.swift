import WidgetKit
import SwiftUI

// ── Timeline Provider — shared by both widgets ───────────────────────────────
struct PrayerTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), data: PrayerData.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(PrayerEntry(date: Date(), data: PrayerData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now  = Date()
        let data = PrayerData.load()

        // Generate one entry per minute for the next 60 minutes
        // This drives the live clock exactly like Android's minute-tick alarm
        var entries: [PrayerEntry] = []
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(
                byAdding: .minute, value: minuteOffset, to: now
            ) ?? now
            entries.append(PrayerEntry(date: entryDate, data: data))
        }

        // After 60 minutes, reload from scratch (picks up any new prayer data)
        let reloadDate = Calendar.current.date(byAdding: .minute, value: 60, to: now) ?? now
        let timeline   = Timeline(entries: entries, policy: .after(reloadDate))
        completion(timeline)
    }
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let data: PrayerData
}

// ── Wide Widget ───────────────────────────────────────────────────────────────
struct PrayerWidgetWide: Widget {
    let kind = "PrayerWidgetWide"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            WideWidgetView(data: entry.data, date: entry.date)
                .widgetURL(URL(string: "ihsan://app/prayerScreen"))
        }
        .configurationDisplayName("Ihsan Prayer Times")
        .description("Full prayer timetable with Jamaat times.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// ── Small Widget ──────────────────────────────────────────────────────────────
struct PrayerWidgetSmall: Widget {
    let kind = "PrayerWidgetSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            SmallWidgetView(data: entry.data)
                .widgetURL(URL(string: "ihsan://app/prayerScreen"))
        }
        .configurationDisplayName("Ihsan Prayer Times (Small)")
        .description("Compact prayer times with Jamaat.")
        .supportedFamilies([.systemSmall])
    }
}

// ── Bundle — registers both widgets ──────────────────────────────────────────
@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidgetWide()
        PrayerWidgetSmall()
    }
}
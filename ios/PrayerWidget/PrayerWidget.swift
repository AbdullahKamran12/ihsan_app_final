import WidgetKit
import SwiftUI

// MARK: - Keys
private enum K {
    static let group        = "group.com.ihsan.ihsanapp"
    static let fajrAdhan    = "w_fajr_adhan"
    static let sunriseAdhan = "w_sunrise_adhan"
    static let dhuhrAdhan   = "w_dhuhr_adhan"
    static let asrAdhan     = "w_asr_adhan"
    static let maghribAdhan = "w_maghrib_adhan"
    static let ishaAdhan    = "w_isha_adhan"
    static let fajrJamaat   = "w_fajr_jamaat"
    static let dhuhrJamaat  = "w_dhuhr_jamaat"
    static let asrJamaat    = "w_asr_jamaat"
    static let ishaJamaat   = "w_isha_jamaat"
    static let nextPrayer   = "w_next_prayer"
    static let nextTime     = "w_next_time"
}

// MARK: - Design tokens
private let navyDark  = Color(red: 0.04, green: 0.10, blue: 0.24)
private let navyMid   = Color(red: 0.07, green: 0.16, blue: 0.37)
private let gold      = Color(red: 0.83, green: 0.69, blue: 0.37)
private let mint      = Color(red: 0.56, green: 0.78, blue: 0.63)
private let offWhite  = Color(red: 0.93, green: 0.94, blue: 1.00)
private let textMuted = Color(red: 0.53, green: 0.56, blue: 0.75)

// MARK: - Entry
struct PrayerEntry: TimelineEntry {
    let date: Date
    // Adhan
    let fajrA, sunriseA, dhuhrA, asrA, maghribA, ishaA: String
    // Jamaat
    let fajrJ, dhuhrJ, asrJ, ishaJ: String
    // Next
    let nextPrayer: String
    let nextTime: String
}

extension PrayerEntry {
    static var placeholder: Self {
        PrayerEntry(date: Date(),
            fajrA: "04:48", sunriseA: "06:15", dhuhrA: "01:04",
            asrA: "04:32", maghribA: "06:56", ishaA: "08:20",
            fajrJ: "05:30", dhuhrJ: "01:30", asrJ: "05:15", ishaJ: "08:45",
            nextPrayer: "Dhuhr", nextTime: "01:30")
    }
    static func from(_ d: UserDefaults?) -> Self {
        func s(_ k: String) -> String { d?.string(forKey: k) ?? "--:--" }
        return PrayerEntry(date: Date(),
            fajrA: s(K.fajrAdhan), sunriseA: s(K.sunriseAdhan),
            dhuhrA: s(K.dhuhrAdhan), asrA: s(K.asrAdhan),
            maghribA: s(K.maghribAdhan), ishaA: s(K.ishaAdhan),
            fajrJ: s(K.fajrJamaat), dhuhrJ: s(K.dhuhrJamaat),
            asrJ: s(K.asrJamaat), ishaJ: s(K.ishaJamaat),
            nextPrayer: d?.string(forKey: K.nextPrayer) ?? "—",
            nextTime: s(K.nextTime))
    }
}

// MARK: - Provider
struct PrayerProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrayerEntry { .placeholder }
    func getSnapshot(in _: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(.from(UserDefaults(suiteName: K.group)))
    }
    func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        // Rebuild every minute so the live clock in medium widget stays fresh
        var entries: [PrayerEntry] = []
        let base = UserDefaults(suiteName: K.group)
        for i in 0..<30 {
            let e = PrayerEntry(
                date: Calendar.current.date(byAdding: .minute, value: i, to: Date())!,
                fajrA: base?.string(forKey: K.fajrAdhan) ?? "--:--",
                sunriseA: base?.string(forKey: K.sunriseAdhan) ?? "--:--",
                dhuhrA: base?.string(forKey: K.dhuhrAdhan) ?? "--:--",
                asrA: base?.string(forKey: K.asrAdhan) ?? "--:--",
                maghribA: base?.string(forKey: K.maghribAdhan) ?? "--:--",
                ishaA: base?.string(forKey: K.ishaAdhan) ?? "--:--",
                fajrJ: base?.string(forKey: K.fajrJamaat) ?? "--:--",
                dhuhrJ: base?.string(forKey: K.dhuhrJamaat) ?? "--:--",
                asrJ: base?.string(forKey: K.asrJamaat) ?? "--:--",
                ishaJ: base?.string(forKey: K.ishaJamaat) ?? "--:--",
                nextPrayer: base?.string(forKey: K.nextPrayer) ?? "—",
                nextTime: base?.string(forKey: K.nextTime) ?? "--:--"
            )
            entries.append(e)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Small view (systemSmall — 2×2)
struct SmallWidgetView: View {
    let e: PrayerEntry

    struct Row {
        let initial: String
        let adhan: String
        let jamaat: String?
        let isNext: Bool
    }

    var rows: [Row] {
        [
            Row(initial: "F", adhan: e.fajrA,    jamaat: e.fajrJ,  isNext: e.nextPrayer == "Fajr"),
            Row(initial: "S", adhan: e.sunriseA,  jamaat: nil,       isNext: e.nextPrayer == "Sunrise"),
            Row(initial: "D", adhan: e.dhuhrA,   jamaat: e.dhuhrJ, isNext: e.nextPrayer == "Dhuhr"),
            Row(initial: "A", adhan: e.asrA,     jamaat: e.asrJ,   isNext: e.nextPrayer == "Asr"),
            Row(initial: "M", adhan: e.maghribA,  jamaat: nil,       isNext: e.nextPrayer == "Maghrib"),
            Row(initial: "E", adhan: e.ishaA,    jamaat: e.ishaJ,  isNext: e.nextPrayer == "Isha"),
        ]
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(navyMid.gradient)
            VStack(spacing: 3) {
                ForEach(rows, id: \.initial) { row in
                    HStack(spacing: 0) {
                        Text(row.initial)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(row.isNext ? gold : offWhite)
                            .frame(width: 18, alignment: .leading)
                        Text(row.adhan)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(row.isNext ? gold : gold.opacity(0.8))
                            .frame(maxWidth: .infinity)
                        Text(row.jamaat ?? "")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(row.jamaat != nil ? mint : Color.clear)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Medium view (systemMedium — 2×4)
struct MediumWidgetView: View {
    let e: PrayerEntry

    // Live clock computed from entry.date (refreshes every minute via timeline)
    var clockString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: e.date)
    }
    var ampmString: String {
        let h = Calendar.current.component(.hour, from: e.date)
        return h < 12 ? "AM" : "PM"
    }

    struct Col {
        let name: String
        let adhan: String
        let jamaat: String?
        let isNext: Bool
    }

    var cols: [Col] {
        [
            Col(name: "Fajr",    adhan: e.fajrA,    jamaat: e.fajrJ,  isNext: e.nextPrayer == "Fajr"),
            Col(name: "Sunrise", adhan: e.sunriseA,  jamaat: nil,       isNext: e.nextPrayer == "Sunrise"),
            Col(name: "Dhuhr",   adhan: e.dhuhrA,   jamaat: e.dhuhrJ, isNext: e.nextPrayer == "Dhuhr"),
            Col(name: "Asr",     adhan: e.asrA,     jamaat: e.asrJ,   isNext: e.nextPrayer == "Asr"),
            Col(name: "Maghrib", adhan: e.maghribA,  jamaat: nil,       isNext: e.nextPrayer == "Maghrib"),
            Col(name: "Esha",    adhan: e.ishaA,    jamaat: e.ishaJ,  isNext: e.nextPrayer == "Isha"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── TOP: Clock | Logo | Next prayer ──────────────────────
            HStack(alignment: .center) {
                // Live clock
                VStack(alignment: .leading, spacing: 0) {
                    Text(clockString)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(ampmString)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(textMuted)
                }

                Spacer()

                // App logo — replace "logo" with your asset name
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Spacer()

                // Next prayer
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Next")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(textMuted)
                    Text(e.nextPrayer)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(gold)
                    Text(e.nextTime)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(gold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(navyDark)

            // Divider
            Rectangle()
                .fill(gold.opacity(0.25))
                .frame(height: 0.5)

            // ── BOTTOM: All 6 prayers ─────────────────────────────────
            HStack(spacing: 0) {
                ForEach(cols, id: \.name) { col in
                    VStack(spacing: 2) {
                        Text(col.name)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(col.isNext ? gold : offWhite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(col.adhan)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(col.isNext ? gold : gold.opacity(0.75))
                        Text(col.jamaat ?? "—")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(col.jamaat != nil ? mint : textMuted.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity)
        }
        .background(
            ContainerRelativeShape().fill(navyMid)
        )
    }
}

// MARK: - Entry view dispatcher
struct PrayerWidgetEntryView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(e: entry)
        case .systemMedium: MediumWidgetView(e: entry)
        default:            MediumWidgetView(e: entry)
        }
    }
}

// MARK: - Widget declaration
@main
struct PrayerWidget: Widget {
    let kind = "PrayerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Prayer Times")
        .description("Adhan & Jamaat times from your mosque.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
struct PrayerWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PrayerWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("2×2")
            PrayerWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("2×4")
        }
    }
}
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
    static let prayerScreenURL = URL(string: "ihsan://app/prayerScreen")!
}

// MARK: - Colours (exact hex match to Android)
// All values taken directly from WidgetClockService companion object
private extension Color {
    static let gradTop  = Color(red: 0x0A/255, green: 0x19/255, blue: 0x3C/255) // #0A193C
    static let gradBot  = Color(red: 0x12/255, green: 0x2A/255, blue: 0x5F/255) // #122A5F
    static let wGold    = Color(red: 0xD4/255, green: 0xAF/255, blue: 0x5F/255) // #D4AF5F
    static let wGreen   = Color(red: 0x90/255, green: 0xC8/255, blue: 0xA0/255) // #90C8A0
    static let wName    = Color(red: 0xEE/255, green: 0xF0/255, blue: 0xFF/255) // #EEF0FF
    static let wDiv     = Color.white.opacity(0x44 / 255.0)                     // #44FFFFFF
    static let wMuted   = Color(red: 0x88/255, green: 0x90/255, blue: 0xC8/255) // #8890C8
    // Gold at alpha 160/255 (adhan colour for non-next columns)
    static let wGoldDim = Color(red: 0xD4/255, green: 0xAF/255, blue: 0x5F/255)
                              .opacity(160.0 / 255.0)
    // White alpha 60/255 (bottom panel tint)
    static let wPanelTint = Color.white.opacity(60.0 / 255.0)
}

private let PRAYERS = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]

// MARK: - Entry
struct PrayerEntry: TimelineEntry {
    let date: Date
    let fajrA, sunriseA, dhuhrA, asrA, maghribA, ishaA: String
    let fajrJ, dhuhrJ, asrJ, ishaJ: String
    let nextPrayer: String
    let nextTime: String
    let hasData: Bool
}

extension PrayerEntry {
    static var placeholder: Self {
        PrayerEntry(date: Date(),
                    fajrA: "04:45", sunriseA: "06:12", dhuhrA: "13:05",
                    asrA: "16:38", maghribA: "20:51", ishaA: "22:18",
                    fajrJ: "05:00", dhuhrJ: "13:30", asrJ: "17:00", ishaJ: "22:30",
                    nextPrayer: "Dhuhr", nextTime: "13:05", hasData: true)
    }

    static func from(_ d: UserDefaults?) -> Self {
        func s(_ k: String) -> String { d?.string(forKey: k) ?? "--:--" }
        let fajr  = d?.string(forKey: K.fajrAdhan)
        let ready = fajr != nil && fajr != "--:--" && !(fajr!.isEmpty)
        return PrayerEntry(date: Date(),
                           fajrA: s(K.fajrAdhan),    sunriseA: s(K.sunriseAdhan),
                           dhuhrA: s(K.dhuhrAdhan),  asrA: s(K.asrAdhan),
                           maghribA: s(K.maghribAdhan), ishaA: s(K.ishaAdhan),
                           fajrJ: s(K.fajrJamaat),   dhuhrJ: s(K.dhuhrJamaat),
                           asrJ: s(K.asrJamaat),     ishaJ: s(K.ishaJamaat),
                           nextPrayer: d?.string(forKey: K.nextPrayer) ?? "—",
                           nextTime: s(K.nextTime),
                           hasData: ready)
    }

    // Convenience arrays matching Android's adhan / jamaat lists
    // Sunrise has no jamaat; Maghrib jamaat = maghribA (same as adhan)
    func adhanTimes() -> [String] { [fajrA, sunriseA, dhuhrA, asrA, maghribA, ishaA] }
    func jamaatTimes() -> [String] { [fajrJ, "", dhuhrJ, asrJ, maghribA, ishaJ] }
}

// MARK: - Provider
// Entries aligned to exact minute boundaries → clock never drifts
struct PrayerProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrayerEntry { .placeholder }

    func getSnapshot(in _: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(PrayerEntry.from(UserDefaults(suiteName: K.group)))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let base       = UserDefaults(suiteName: K.group)
        let src        = PrayerEntry.from(base)
        let cal        = Calendar.current
        let startOfMin = cal.dateInterval(of: .minute, for: Date())!.start
        var entries: [PrayerEntry] = []
        for i in 0..<60 {
            guard let d = cal.date(byAdding: .minute, value: i, to: startOfMin) else { continue }
            entries.append(PrayerEntry(date: d,
                                       fajrA: src.fajrA,       sunriseA: src.sunriseA,
                                       dhuhrA: src.dhuhrA,     asrA: src.asrA,
                                       maghribA: src.maghribA, ishaA: src.ishaA,
                                       fajrJ: src.fajrJ,       dhuhrJ: src.dhuhrJ,
                                       asrJ: src.asrJ,         ishaJ: src.ishaJ,
                                       nextPrayer: src.nextPrayer, nextTime: src.nextTime,
                                       hasData: src.hasData))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Small widget (mirrors prayer_widget_small.xml + PrayerWidgetSmallProvider)
struct SmallWidgetView: View {
    let e: PrayerEntry

    private struct Row: Identifiable {
        let id: String        // prayer name key for next-highlighting
        let initial: String
        let adhan: String
        let jamaat: String?
    }

    private var rows: [Row] {[
        Row(id: "Fajr",    initial: "F", adhan: e.fajrA,    jamaat: e.fajrJ),
        Row(id: "Sunrise", initial: "S", adhan: e.sunriseA,  jamaat: nil),
        Row(id: "Dhuhr",   initial: "Z", adhan: e.dhuhrA,   jamaat: e.dhuhrJ),
        Row(id: "Asr",     initial: "A", adhan: e.asrA,     jamaat: e.asrJ),
        Row(id: "Maghrib", initial: "M", adhan: e.maghribA,  jamaat: nil),
        Row(id: "Isha",    initial: "I", adhan: e.ishaA,    jamaat: e.ishaJ),
    ]}

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(LinearGradient(colors: [.gradTop, .gradBot],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    let isNext = row.id == e.nextPrayer && e.hasData
                    HStack(spacing: 0) {
                        Text(row.initial)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isNext ? .wGold : .wName)
                            .frame(width: 18, alignment: .leading)
                        Text(row.adhan)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(isNext ? .wGold : .wGoldDim)
                            .frame(maxWidth: .infinity)
                        Text(row.jamaat ?? "")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(row.jamaat != nil ? .wGreen : .clear)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(10)
        }
        .widgetURL(K.prayerScreenURL)
    }
}

// MARK: - Medium widget
// Uses SwiftUI Canvas so drawing calls mirror Android's Canvas/Paint API
// exactly — same coordinate fractions, same font-size ratios, same colours.
//
// Android reference canvas: 800 × 340 px
//   divY     = 133          → 133/340 = 0.39118 of height
//   headerCy = divY / 2     → 66.5 px from top
//   leftPad  = 28           → 28/800 = 0.035 of width
//
// Font sizes scaled by (actual_height / 340):
//   clock 85sp, ampm 32sp, nextName 34sp, nextTime 56sp
//   prayerName 28sp, adhan 30sp, jamaat 34sp, hint 26sp
struct MediumWidgetView: View {
    let e: PrayerEntry

    private var clockStr: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: e.date)
    }
    private var ampmStr: String {
        Calendar.current.component(.hour, from: e.date) < 12 ? "AM" : "PM"
    }

    var body: some View {
        Canvas { ctx, size in
            let W = size.width
            let H = size.height

            // ── Proportions (all derived from Android's 800×340 canvas) ──────
            let divY    = H * (133.0 / 340.0)   // header / body split
            let headerCy = divY / 2.0
            let lPad    = W * (28.0  / 800.0)   // left padding
            let rPad    = W * (28.0  / 800.0)   // right padding

            // Font scale factor: actual height vs reference 340
            let fs = H / 340.0

            // ── Background gradient ───────────────────────────────────────────
            let grad = LinearGradient(colors: [.gradTop, .gradBot],
                                      startPoint: .top, endPoint: .bottom)
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: W, height: H),
                          cornerRadius: 0),   // WidgetKit clips to ContainerRelativeShape
                     with: .linearGradient(Gradient(colors: [.gradTop, .gradBot]),
                                           startPoint: .zero,
                                           endPoint: CGPoint(x: 0, y: H)))

            // ── Bottom panel tint (white alpha 60/255) ────────────────────────
            ctx.fill(Path(CGRect(x: 0, y: divY, width: W, height: H - divY)),
                     with: .color(.wPanelTint))

            // ── Divider line ──────────────────────────────────────────────────
            var divPath = Path()
            divPath.move(to:    CGPoint(x: 0, y: divY))
            divPath.addLine(to: CGPoint(x: W, y: divY))
            ctx.stroke(divPath, with: .color(.wDiv), lineWidth: 0.5)

            // ── Clock ─────────────────────────────────────────────────────────
            // Baseline in Android = headerCy + 22. In SwiftUI Canvas, Text is
            // placed by its top-left, so we offset by the font's cap-height ≈ 0.72×size.
            let clockSize = 85.0 * fs
            let ampmSize  = 32.0 * fs
            let clockText = Text(clockStr)
                .font(.system(size: clockSize, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            let clockRes = ctx.resolve(clockText)
            let clockW   = clockRes.measure(in: CGSize(width: W, height: H)).width
            // baseline target = headerCy + 22*fs → top = baseline - cap-height
            let clockBaseline = headerCy + 22.0 * fs
            ctx.draw(clockRes, at: CGPoint(x: lPad, y: clockBaseline - clockSize * 0.72),
                     anchor: .topLeading)

            let ampmText = Text(ampmStr)
                .font(.system(size: ampmSize, weight: .regular))
                .foregroundColor(.white)
            let ampmRes = ctx.resolve(ampmText)
            ctx.draw(ampmRes, at: CGPoint(x: lPad + clockW + 6.0 * fs,
                                          y: clockBaseline - ampmSize * 0.72),
                     anchor: .topLeading)

            // ── Logo (centred in header) ──────────────────────────────────────
            // Drawn as SwiftUI Image via ImageRenderer — simplest is to resolve
            // a symbol; for a real asset we just draw it in the symbol layer below.
            // (Canvas can't easily draw asset-catalog images; use the overlay approach.)

            // ── Next prayer (right-aligned) ───────────────────────────────────
            if e.hasData {
                let nameSize = 34.0 * fs
                let nameBaseline = headerCy - 8.0 * fs
                let nameText = Text(e.nextPrayer)
                    .font(.system(size: nameSize, weight: .bold))
                    .foregroundColor(.wGold)
                let nameRes = ctx.resolve(nameText)
                let nameW   = nameRes.measure(in: CGSize(width: W, height: H)).width
                ctx.draw(nameRes, at: CGPoint(x: W - rPad - nameW,
                                              y: nameBaseline - nameSize * 0.72),
                         anchor: .topLeading)

                let timeSize = 56.0 * fs
                let timeBaseline = headerCy + 52.0 * fs
                let timeText = Text(e.nextTime)
                    .font(.system(size: timeSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.wGold)
                let timeRes = ctx.resolve(timeText)
                let timeW   = timeRes.measure(in: CGSize(width: W, height: H)).width
                ctx.draw(timeRes, at: CGPoint(x: W - rPad - timeW,
                                              y: timeBaseline - timeSize * 0.72),
                         anchor: .topLeading)
            } else {
                let hintSize = 26.0 * fs
                let hintBaseline = headerCy - 8.0 * fs
                let hintText = Text("Open app to load times")
                    .font(.system(size: hintSize, weight: .regular))
                    .foregroundColor(.wMuted)
                let hintRes = ctx.resolve(hintText)
                let hintW   = hintRes.measure(in: CGSize(width: W, height: H)).width
                ctx.draw(hintRes, at: CGPoint(x: W - rPad - hintW,
                                              y: hintBaseline - hintSize * 0.72),
                         anchor: .topLeading)
            }

            // ── Prayer columns ────────────────────────────────────────────────
            let colW    = W / 6.0
            let bodyTop = divY + 8.0 * fs
            let effBodyH = H - divY - 8.0 * fs
            let nameOffY  = bodyTop + effBodyH * 0.28
            let adhanOffY = bodyTop + effBodyH * 0.58
            let jamOffY   = bodyTop + effBodyH * 0.90

            let pNameSize  = 28.0 * fs
            let adhanSize  = 30.0 * fs
            let jamSize    = 34.0 * fs

            let adhan  = e.adhanTimes()
            let jamaat = e.jamaatTimes()

            for i in 0..<6 {
                let cx = colW * CGFloat(i) + colW / 2.0
                let isNext = PRAYERS[i].lowercased() == e.nextPrayer.lowercased() && e.hasData

                // Column divider (skip first)
                if i > 0 {
                    var dv = Path()
                    dv.move(to:    CGPoint(x: colW * CGFloat(i), y: divY + 10.0 * fs))
                    dv.addLine(to: CGPoint(x: colW * CGFloat(i), y: H - 10.0 * fs))
                    ctx.stroke(dv, with: .color(.wDiv), lineWidth: 0.5)
                }

                // Prayer name
                let nameCol: Color = isNext ? .wGold : .wName
                let nameT = Text(PRAYERS[i])
                    .font(.system(size: pNameSize, weight: .bold))
                    .foregroundColor(nameCol)
                let nameR = ctx.resolve(nameT)
                let nameW2 = nameR.measure(in: CGSize(width: colW, height: H)).width
                ctx.draw(nameR, at: CGPoint(x: cx - nameW2 / 2.0,
                                            y: nameOffY - pNameSize * 0.72),
                         anchor: .topLeading)

                // Adhan
                let adhanDisplay = e.hasData ? adhan[i] : "--:--"
                let adhanCol: Color = isNext ? .wGold : .wGoldDim
                let adhanT = Text(adhanDisplay)
                    .font(.system(size: adhanSize, weight: .regular, design: .monospaced))
                    .foregroundColor(adhanCol)
                let adhanR = ctx.resolve(adhanT)
                let adhanW = adhanR.measure(in: CGSize(width: colW, height: H)).width
                ctx.draw(adhanR, at: CGPoint(x: cx - adhanW / 2.0,
                                             y: adhanOffY - adhanSize * 0.72),
                         anchor: .topLeading)

                // Jamaat (empty string = skip, same as Android)
                let jamDisplay = e.hasData ? jamaat[i] : ""
                if !jamDisplay.isEmpty {
                    let jamCol: Color = isNext ? .wGold : .wGreen
                    let jamT = Text(jamDisplay)
                        .font(.system(size: jamSize, weight: .bold, design: .monospaced))
                        .foregroundColor(jamCol)
                    let jamR = ctx.resolve(jamT)
                    let jamW = jamR.measure(in: CGSize(width: colW, height: H)).width
                    ctx.draw(jamR, at: CGPoint(x: cx - jamW / 2.0,
                                               y: jamOffY - jamSize * 0.72),
                             anchor: .topLeading)
                }
            }
        }
        // Logo overlay — Canvas can't load asset images, so overlay it in SwiftUI
        .overlay(
            GeometryReader { geo in
                let divY = geo.size.height * (133.0 / 340.0)
                let logoH = divY * 0.80
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: logoH)
                    .frame(width: geo.size.width, height: divY, alignment: .center)
            }
        )
        .widgetURL(K.prayerScreenURL)
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
                .previewDisplayName("2×2 Small")
            PrayerWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("2×4 Medium")
        }
    }
}
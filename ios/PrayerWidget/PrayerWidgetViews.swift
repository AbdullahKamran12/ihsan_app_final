import SwiftUI
import WidgetKit

// ── Colours matching Android exactly ─────────────────────────────────────────
private let colGradTop  = Color(red: 0.039, green: 0.098, blue: 0.235) // #0A193C
private let colGradBot  = Color(red: 0.071, green: 0.165, blue: 0.373) // #122A5F
private let colGold     = Color(red: 0.831, green: 0.686, blue: 0.373) // #D4AF5F
private let colGreen    = Color(red: 0.565, green: 0.784, blue: 0.627) // #90C8A0
private let colName     = Color(red: 0.933, green: 0.941, blue: 1.000) // #EEF0FF
private let colMuted    = Color(red: 0.533, green: 0.565, blue: 0.784) // #8890C8
private let colAdhanDim = Color(red: 0.831, green: 0.686, blue: 0.373).opacity(0.65)

private let prayers     = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
private let initials    = ["F", "S", "Z", "A", "M", "I"]

// ── Shared background ─────────────────────────────────────────────────────────
struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [colGradTop, colGradBot],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDE WIDGET  (matches Android PrayerWidgetProvider / WidgetClockService)
// ─────────────────────────────────────────────────────────────────────────────
struct WideWidgetView: View {
    let data: PrayerData
    let date: Date   // passed from timeline — drives the live clock

    private var clockString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    private var ampm: String {
        Calendar.current.component(.hour, from: date) < 12 ? "AM" : "PM"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let divY = h * 0.39   // matches Android divY = 133/340

            ZStack(alignment: .topLeading) {
                WidgetBackground()

                // Bottom panel tint
                VStack {
                    Spacer(minLength: divY)
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                }

                // Divider line
                Rectangle()
                    .fill(Color.white.opacity(0.27))
                    .frame(height: 1)
                    .offset(y: divY)

                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────────
                    headerSection(w: w, h: divY)
                        .frame(height: divY)

                    // ── Prayer columns ────────────────────────────────────────
                    columnsSection(w: w, h: h - divY)
                        .frame(height: h - divY)
                }
            }
        }
        .widgetBackground(WidgetBackground())
    }

    @ViewBuilder
    private func headerSection(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Clock — left
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(clockString)
                    .font(.system(size: h * 0.62, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(ampm)
                    .font(.system(size: h * 0.24, weight: .regular))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)

            // Logo — centre
            if let uiImg = UIImage(named: "logo") {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(height: h * 0.75)
            }

            // Next prayer — right
            if data.hasData {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(data.nextPrayer)
                        .font(.system(size: h * 0.26, weight: .bold))
                        .foregroundColor(colGold)
                    Text(data.nextTime)
                        .font(.system(size: h * 0.40, weight: .bold))
                        .foregroundColor(colGold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
            } else {
                Text("Open app to load times")
                    .font(.system(size: h * 0.19))
                    .foregroundColor(colMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
            }
        }
    }

    @ViewBuilder
    private func columnsSection(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<6) { i in
                let isNext = prayers[i].lowercased() == data.nextPrayer.lowercased() && data.hasData

                ZStack {
                    if i > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.27))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 0) {
                        Spacer()
                        // Prayer name
                        Text(prayers[i])
                            .font(.system(size: h * 0.22, weight: .bold))
                            .foregroundColor(isNext ? colGold : colName)
                        Spacer()
                        // Adhan time
                        Text(data.hasData ? adhanFor(i) : "--:--")
                            .font(.system(size: h * 0.23, weight: .regular))
                            .foregroundColor(isNext ? colGold : colAdhanDim)
                            .monospacedDigit()
                        Spacer()
                        // Jamaat time
                        let jamaat = jamaatFor(i)
                        if jamaat.isEmpty {
                            Text(" ").font(.system(size: h * 0.26))
                        } else {
                            Text(jamaat)
                                .font(.system(size: h * 0.26, weight: .bold))
                                .foregroundColor(isNext ? colGold : colGreen)
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func adhanFor(_ i: Int) -> String {
        switch i {
        case 0: return data.fajrAdhan
        case 1: return data.sunriseAdhan
        case 2: return data.dhuhrAdhan
        case 3: return data.asrAdhan
        case 4: return data.maghribAdhan
        case 5: return data.ishaAdhan
        default: return "--:--"
        }
    }

    private func jamaatFor(_ i: Int) -> String {
        switch i {
        case 0: return data.fajrJamaat
        case 1: return ""               // Sunrise — no jamaat
        case 2: return data.dhuhrJamaat
        case 3: return data.asrJamaat
        case 4: return data.maghribAdhan // Maghrib jamaat = adhan (matches Android)
        case 5: return data.ishaJamaat
        default: return ""
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGET  (matches Android PrayerWidgetSmallProvider)
// ─────────────────────────────────────────────────────────────────────────────
struct SmallWidgetView: View {
    let data: PrayerData

    var body: some View {
        GeometryReader { geo in
            let rowH = geo.size.height / 6.0

            VStack(spacing: 0) {
                ForEach(0..<6) { i in
                    smallRow(i: i, rowH: rowH)
                        .frame(height: rowH)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .widgetBackground(WidgetBackground())
    }

    @ViewBuilder
    private func smallRow(i: Int, rowH: CGFloat) -> some View {
        let isNext   = prayers[i].lowercased() == data.nextPrayer.lowercased()
        let adhan    = adhanFor(i)
        let jamaat   = jamaatFor(i)
        let fontSize = rowH * 0.52

        HStack(spacing: 0) {
            // Initial letter
            Text(initials[i])
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(isNext ? colGold : colName)
                .frame(width: 18, alignment: .leading)

            Spacer(minLength: 4)

            // Adhan time
            Text(adhan)
                .font(.system(size: fontSize, weight: .regular).monospacedDigit())
                .foregroundColor(colGold)
                .frame(maxWidth: .infinity, alignment: .center)

            // Jamaat time (blank for Sunrise and Maghrib)
            if jamaat.isEmpty {
                Spacer().frame(maxWidth: .infinity)
            } else {
                Text(jamaat)
                    .font(.system(size: fontSize, weight: .regular).monospacedDigit())
                    .foregroundColor(colGreen)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func adhanFor(_ i: Int) -> String {
        switch i {
        case 0: return data.fajrAdhan
        case 1: return data.sunriseAdhan
        case 2: return data.dhuhrAdhan
        case 3: return data.asrAdhan
        case 4: return data.maghribAdhan
        case 5: return data.ishaAdhan
        default: return "--:--"
        }
    }

    private func jamaatFor(_ i: Int) -> String {
        switch i {
        case 0: return data.fajrJamaat
        case 1: return ""
        case 2: return data.dhuhrJamaat
        case 3: return data.asrJamaat
        case 4: return ""               // Maghrib — no jamaat column in small widget
        case 5: return data.ishaJamaat
        default: return ""
        }
    }
}

// ── WidgetBackground helper (iOS 17 API bridged to iOS 14) ───────────────────
extension View {
    func widgetBackground(_ content: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return AnyView(containerBackground(for: .widget) { content })
        } else {
            return AnyView(background(content))
        }
    }
}
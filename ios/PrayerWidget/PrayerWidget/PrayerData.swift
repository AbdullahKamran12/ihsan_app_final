import Foundation

// Keys must match widget_service.dart exactly
struct PrayerData {
    let fajrAdhan:    String
    let sunriseAdhan: String
    let dhuhrAdhan:   String
    let asrAdhan:     String
    let maghribAdhan: String
    let ishaAdhan:    String

    let fajrJamaat:  String
    let dhuhrJamaat: String
    let asrJamaat:   String
    let ishaJamaat:  String

    let mosqueName:    String
    let nextPrayer:    String
    let nextTime:      String
    let currentPrayer: String

    static func load() -> PrayerData {
        let defaults = UserDefaults(suiteName: "group.com.ihsan.ihsanapp")

        func get(_ key: String) -> String {
            let v = defaults?.string(forKey: key) ?? ""
            return v.isEmpty ? "--:--" : v
        }
        func getOrEmpty(_ key: String) -> String {
            return defaults?.string(forKey: key) ?? ""
        }

        return PrayerData(
            fajrAdhan:    get("w_fajr_adhan"),
            sunriseAdhan: get("w_sunrise_adhan"),
            dhuhrAdhan:   get("w_dhuhr_adhan"),
            asrAdhan:     get("w_asr_adhan"),
            maghribAdhan: get("w_maghrib_adhan"),
            ishaAdhan:    get("w_isha_adhan"),

            fajrJamaat:  getOrEmpty("w_fajr_jamaat"),
            dhuhrJamaat: getOrEmpty("w_dhuhr_jamaat"),
            asrJamaat:   getOrEmpty("w_asr_jamaat"),
            ishaJamaat:  getOrEmpty("w_isha_jamaat"),

            mosqueName:    getOrEmpty("w_mosque_name"),
            nextPrayer:    getOrEmpty("w_next_prayer"),
            nextTime:      get("w_next_time"),
            currentPrayer: getOrEmpty("w_current_prayer")
        )
    }

    var hasData: Bool {
        return fajrAdhan != "--:--" && !fajrAdhan.isEmpty
    }
}
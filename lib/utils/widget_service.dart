import 'package:home_widget/home_widget.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:intl/intl.dart';

class WidgetService {
  // ── iOS App Group — MUST match Xcode App Group exactly ───────────────
  static const _appGroupId = 'group.com.ihsan.ihsanapp';

  // ── Data keys — identical strings used on native side ────────────────
  static const _fajrAdhan = 'w_fajr_adhan';
  static const _sunriseAdhan = 'w_sunrise_adhan';
  static const _dhuhrAdhan = 'w_dhuhr_adhan';
  static const _asrAdhan = 'w_asr_adhan';
  static const _maghribAdhan = 'w_maghrib_adhan';
  static const _ishaAdhan = 'w_isha_adhan';

  static const _fajrJamaat = 'w_fajr_jamaat';
  static const _dhuhrJamaat = 'w_dhuhr_jamaat';
  static const _asrJamaat = 'w_asr_jamaat';
  static const _ishaJamaat = 'w_isha_jamaat';

  static const _mosqueName = 'w_mosque_name';
  static const _nextPrayer = 'w_next_prayer'; // e.g. "Dhuhr"
  static const _nextTime = 'w_next_time'; // jamaat time of next prayer
  static const _currentPrayer = 'w_current_prayer';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Call after prayer times are loaded or mosque changes.
  static Future<void> update({
    required PrayerTimes adhan,
    PrayerTimesJamaat? jamaat,
    String? mosqueName,
    String? nextPrayerName,
    String? currentPrayerName,
  }) async {
    // Adhan times
    await HomeWidget.saveWidgetData(_fajrAdhan, adhan.fajr);
    await HomeWidget.saveWidgetData(_sunriseAdhan, adhan.sunrise);
    await HomeWidget.saveWidgetData(_dhuhrAdhan, adhan.dhuhr);
    await HomeWidget.saveWidgetData(_asrAdhan, adhan.asr);
    await HomeWidget.saveWidgetData(_maghribAdhan, adhan.maghrib);
    await HomeWidget.saveWidgetData(_ishaAdhan, adhan.isha);

    // Jamaat times (only favourited mosque's times)
    if (jamaat != null) {
      await HomeWidget.saveWidgetData(_fajrJamaat, jamaat.fajr);
      await HomeWidget.saveWidgetData(_dhuhrJamaat, jamaat.dhuhr);
      await HomeWidget.saveWidgetData(_asrJamaat, jamaat.asr);
      await HomeWidget.saveWidgetData(_ishaJamaat, jamaat.isha);
    }

    if (mosqueName != null) {
      await HomeWidget.saveWidgetData(_mosqueName, mosqueName);
    }

    // Determine next prayer jamaat time for the 2x4 header
    if (nextPrayerName != null) {
      await HomeWidget.saveWidgetData(_nextPrayer, nextPrayerName);
      // Store the jamaat time of the next prayer for the header
      if (jamaat != null) {
        final nextJamaat = _jamaatForPrayer(nextPrayerName, jamaat, adhan);
        await HomeWidget.saveWidgetData(_nextTime, nextJamaat);
      }
    }

    if (currentPrayerName != null) {
      await HomeWidget.saveWidgetData(_currentPrayer, currentPrayerName);
    }

    await HomeWidget.updateWidget(
      androidName: 'PrayerWidgetProvider',
      iOSName: 'PrayerWidget',
    );
  }

  static String _jamaatForPrayer(
      String name, PrayerTimesJamaat jamaat, PrayerTimes adhan) {
    switch (name) {
      case 'Fajr':
        return jamaat.fajr.isNotEmpty ? jamaat.fajr : adhan.fajr;
      case 'Sunrise':
        return adhan.sunrise; // no separate jamaat
      case 'Dhuhr':
        return jamaat.dhuhr.isNotEmpty ? jamaat.dhuhr : adhan.dhuhr;
      case 'Asr':
        return jamaat.asr.isNotEmpty ? jamaat.asr : adhan.asr;
      case 'Maghrib':
        return adhan.maghrib; // no separate jamaat
      case 'Isha':
        return jamaat.isha.isNotEmpty ? jamaat.isha : adhan.isha;
      default:
        return '--:--';
    }
  }
}

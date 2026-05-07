import 'package:home_widget/home_widget.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Re-pushes whatever prayer times were last saved to SharedPreferences
  /// back into HomeWidget shared prefs. Call at app startup so the widget
  /// is never blank even before prayerScreen has been visited this session.
  static Future<void> pushPrayerDataToWidget() async {
    final prefs = await SharedPreferences.getInstance();

    // Read the last-saved values (same keys used by prayerScreen to persist times)
    String get(String key) => prefs.getString(key) ?? '--:--';

    await HomeWidget.saveWidgetData(_fajrAdhan, get(_fajrAdhan));
    await HomeWidget.saveWidgetData(_sunriseAdhan, get(_sunriseAdhan));
    await HomeWidget.saveWidgetData(_dhuhrAdhan, get(_dhuhrAdhan));
    await HomeWidget.saveWidgetData(_asrAdhan, get(_asrAdhan));
    await HomeWidget.saveWidgetData(_maghribAdhan, get(_maghribAdhan));
    await HomeWidget.saveWidgetData(_ishaAdhan, get(_ishaAdhan));

    await HomeWidget.saveWidgetData(_fajrJamaat, get(_fajrJamaat));
    await HomeWidget.saveWidgetData(_dhuhrJamaat, get(_dhuhrJamaat));
    await HomeWidget.saveWidgetData(_asrJamaat, get(_asrJamaat));
    await HomeWidget.saveWidgetData(_ishaJamaat, get(_ishaJamaat));

    await HomeWidget.saveWidgetData(
        _mosqueName, prefs.getString(_mosqueName) ?? '');
    await HomeWidget.saveWidgetData(
        _nextPrayer, prefs.getString(_nextPrayer) ?? '');
    await HomeWidget.saveWidgetData(_nextTime, get(_nextTime));
    await HomeWidget.saveWidgetData(
        _currentPrayer, prefs.getString(_currentPrayer) ?? '');

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

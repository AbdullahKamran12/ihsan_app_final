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
  /// All saves run in parallel via Future.wait — updateWidget is only
  /// called once every key is guaranteed written. This is what prevents
  /// the blank-widget bug in release/AOT builds.
  static Future<void> update({
    required PrayerTimes adhan,
    PrayerTimesJamaat? jamaat,
    String? mosqueName,
    String? nextPrayerName,
    String? currentPrayerName,
  }) async {
    final saves = <Future<void>>[
      HomeWidget.saveWidgetData(_fajrAdhan, adhan.fajr),
      HomeWidget.saveWidgetData(_sunriseAdhan, adhan.sunrise),
      HomeWidget.saveWidgetData(_dhuhrAdhan, adhan.dhuhr),
      HomeWidget.saveWidgetData(_asrAdhan, adhan.asr),
      HomeWidget.saveWidgetData(_maghribAdhan, adhan.maghrib),
      HomeWidget.saveWidgetData(_ishaAdhan, adhan.isha),
    ];

    if (jamaat != null) {
      saves.addAll([
        HomeWidget.saveWidgetData(_fajrJamaat, jamaat.fajr),
        HomeWidget.saveWidgetData(_dhuhrJamaat, jamaat.dhuhr),
        HomeWidget.saveWidgetData(_asrJamaat, jamaat.asr),
        HomeWidget.saveWidgetData(_ishaJamaat, jamaat.isha),
      ]);
    }

    if (mosqueName != null) {
      saves.add(HomeWidget.saveWidgetData(_mosqueName, mosqueName));
    }

    if (nextPrayerName != null && nextPrayerName.isNotEmpty) {
      saves.add(HomeWidget.saveWidgetData(_nextPrayer, nextPrayerName));
      if (jamaat != null) {
        saves.add(HomeWidget.saveWidgetData(
            _nextTime, _jamaatForPrayer(nextPrayerName, jamaat, adhan)));
      } else {
        // No jamaat yet — use adhan time so header never shows --:--
        saves.add(HomeWidget.saveWidgetData(
            _nextTime, _adhanForPrayer(nextPrayerName, adhan)));
      }
    }

    if (currentPrayerName != null) {
      saves.add(HomeWidget.saveWidgetData(_currentPrayer, currentPrayerName));
    }

    // All keys written before we tell the widget to redraw
    await Future.wait(saves);
    await HomeWidget.updateWidget(
      androidName: 'PrayerWidgetProvider',
      iOSName: 'PrayerWidget',
    );
  }

  static String _adhanForPrayer(String name, PrayerTimes adhan) {
    switch (name) {
      case 'Fajr':
        return adhan.fajr;
      case 'Sunrise':
        return adhan.sunrise;
      case 'Dhuhr':
        return adhan.dhuhr;
      case 'Asr':
        return adhan.asr;
      case 'Maghrib':
        return adhan.maghrib;
      case 'Isha':
        return adhan.isha;
      default:
        return '--:--';
    }
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

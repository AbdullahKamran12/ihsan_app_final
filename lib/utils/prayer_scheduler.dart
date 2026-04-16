import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:ihsan_app_final/utils/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/utils/prayer_scheduler.dart
//
// Handles:
//  1. Registering the daily midnight WorkManager task
//  2. The top-level callback that WorkManager calls in the background
//  3. The scheduling logic that reads prefs + prayer times and fires notifications
//
// Background task flow (runs at midnight without opening the app):
//  a. Read tomorrow's beginning times from the cached yearly prayer data
//  b. Fetch tomorrow's jamaat times from Firestore (if network available)
//  c. Save both to SharedPreferences
//  d. Reschedule all enabled notifications for the new day
// ─────────────────────────────────────────────────────────────────────────────

const String _kDailyTaskName = 'dailyPrayerNotifTask';
const String _kDailyTaskUnique = 'prayer_daily_midnight';

// ── Top-level callback — MUST be top-level (not inside a class) ───────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _kDailyTaskName) {
      await _refreshAndSchedule();
    }
    return Future.value(true);
  });
}

// ── Main background logic ─────────────────────────────────────────────────────
// Called at midnight by WorkManager. Pulls tomorrow's data and reschedules.
Future<void> _refreshAndSchedule() async {
  try {
    await NotificationService.init();
    final prefs = await SharedPreferences.getInstance();

    // Step 1: Update beginning times from the cached yearly data in prefs
    await _updateBeginningTimesFromCache(prefs);

    // Step 2: Fetch tomorrow's jamaat times from Firestore
    await _fetchAndSaveJamaahTimesFromFirestore(prefs);

    // Step 3: Reschedule notifications — pass tomorrow so DateTimes are built
    // against the correct date (prefs now hold tomorrow's times)
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await _scheduleTodayNotifications(prefs, targetDate: tomorrow);
  } catch (e) {
    print('PrayerScheduler background error: $e');
  }
}

// ── Reads tomorrow's beginning times from the cached yearly JSON ──────────────
// Supports both Aladhan format (item['date']['gregorian']['date'] + item['timings'])
// and mosque timetable format (item['date'] string + item['fajr'] etc.).
// Falls back to the plain pref keys if neither cache is found.
Future<void> _updateBeginningTimesFromCache(SharedPreferences prefs) async {
  try {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowAladhan = DateFormat('dd-MM-yyyy').format(tomorrow);
    final yearKey = 'prayerTimes_${tomorrow.year}';

    final jsonString = prefs.getString(yearKey);
    if (jsonString == null || jsonString.isEmpty) {
      // No yearly cache at all — plain prefs are our only fallback, leave them
      print(
          'PrayerScheduler: no yearly cache found, using existing plain prefs');
      return;
    }

    final List<dynamic> jsonList = jsonDecode(jsonString);
    String clean(String t) => t.replaceAll(RegExp(r'\s*\(GMT\)'), '').trim();

    for (final item in jsonList) {
      // ── Aladhan format ──
      final aladhanDate = item['date']?['gregorian']?['date'];
      if (aladhanDate == tomorrowAladhan) {
        final timings = item['timings'];
        await prefs.setString('fajr', clean(timings['Fajr'] ?? ''));
        await prefs.setString('sunrise', clean(timings['Sunrise'] ?? ''));
        await prefs.setString('dhuhr', clean(timings['Dhuhr'] ?? ''));
        await prefs.setString('asr', clean(timings['Asr'] ?? ''));
        await prefs.setString('maghrib', clean(timings['Maghrib'] ?? ''));
        await prefs.setString('isha', clean(timings['Isha'] ?? ''));
        await prefs.setString('prayerTimesDate', tomorrowAladhan);
        return;
      }

      // ── Mosque timetable format (date stored as 'dd-MM-yyyy' string) ──
      final mosqueDate = item['date'];
      if (mosqueDate is String && mosqueDate == tomorrowAladhan) {
        await prefs.setString('fajr', clean(item['fajr'] ?? ''));
        await prefs.setString('sunrise', clean(item['sunrise'] ?? ''));
        await prefs.setString('dhuhr', clean(item['dhuhr'] ?? ''));
        await prefs.setString('asr', clean(item['asr'] ?? ''));
        await prefs.setString('maghrib', clean(item['maghrib'] ?? ''));
        await prefs.setString('isha', clean(item['isha'] ?? ''));
        await prefs.setString('prayerTimesDate', tomorrowAladhan);
        return;
      }
    }

    print('PrayerScheduler: tomorrow not found in yearly cache');
  } catch (e) {
    print('PrayerScheduler: failed to update beginning times from cache: $e');
  }
}

// ── Fetches tomorrow's jamaat times ───────────────────────────────────────────
// First tries the locally cached full-year jamaat JSON (saved by prayerScreen).
// Only hits Firestore if the local cache is missing — avoids network dependency.
Future<void> _fetchAndSaveJamaahTimesFromFirestore(
    SharedPreferences prefs) async {
  try {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowKey = DateFormat('yyyy-MM-dd').format(tomorrow);
    final isFriday = tomorrow.weekday == DateTime.friday;

    // ── Try local year cache first ──
    final yearJson = prefs.getString('jamaahTimes_year');
    if (yearJson != null && yearJson.isNotEmpty) {
      final List<dynamic> yearList = jsonDecode(yearJson);
      for (final item in yearList) {
        if (item['date'] == tomorrowKey) {
          String dhuhrJamaah;
          if (isFriday) {
            final jummahList = item['jummahTimes'];
            dhuhrJamaah = (jummahList is List && jummahList.isNotEmpty)
                ? jummahList.first.toString()
                : item['dhuhr'] ?? '';
          } else {
            dhuhrJamaah = item['dhuhr'] ?? '';
          }

          await prefs.setString('jamaah_fajr', item['fajr'] ?? '');
          await prefs.setString('jamaah_sunrise', item['sunrise'] ?? '');
          await prefs.setString('jamaah_dhuhr', dhuhrJamaah);
          await prefs.setString('jamaah_asr', item['asr'] ?? '');
          await prefs.setString('jamaah_maghrib', item['maghrib'] ?? '');
          await prefs.setString('jamaah_isha', item['isha'] ?? '');
          return; // done — no Firestore needed
        }
      }
    }

    // ── Fallback: Firestore (only if local cache missing/incomplete) ──
    final mosqueId = prefs.getString('localMosqueId') ?? '';
    if (mosqueId.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('mosques')
        .doc(mosqueId)
        .collection('prayerTimes')
        .doc(tomorrowKey)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    String dhuhrJamaah;
    if (isFriday) {
      final jummahList = data['jummahTimes'];
      dhuhrJamaah = (jummahList is List && jummahList.isNotEmpty)
          ? jummahList.first.toString()
          : data['dhuhrJ'] ?? data['dhuhrB'] ?? '';
    } else {
      dhuhrJamaah = data['dhuhrJ'] ?? data['dhuhrB'] ?? '';
    }

    await prefs.setString('jamaah_fajr', data['fajrJ'] ?? data['fajrB'] ?? '');
    await prefs.setString('jamaah_sunrise', data['sunrise'] ?? '');
    await prefs.setString('jamaah_dhuhr', dhuhrJamaah);
    await prefs.setString(
        'jamaah_asr', data['asrJ'] ?? data['asarJ'] ?? data['asrB'] ?? '');
    await prefs.setString('jamaah_maghrib', data['maghrib'] ?? '');
    await prefs.setString('jamaah_isha', data['ishaJ'] ?? data['ishaB'] ?? '');
  } catch (e) {
    print('PrayerScheduler: failed to fetch jamaat times: $e');
  }
}

// ── Core scheduling logic ─────────────────────────────────────────────────────
Future<void> _scheduleTodayNotifications(SharedPreferences prefs,
    {DateTime? targetDate}) async {
  try {
    final state = await NotificationService.loadAll();

    final beginningTimes =
        _readBeginningTimesFromPrefs(prefs, date: targetDate);
    final jamaahTimes = _readJamaahTimesFromPrefs(prefs, date: targetDate);

    // Safety check — don't cancel if a notification is imminent
    final now = DateTime.now();
    final safetyWindow = now.add(const Duration(minutes: 2));

    for (int i = 0; i < 6; i++) {
      if (state.beginningOn[i] && beginningTimes[i] != null) {
        if (beginningTimes[i]!.isAfter(now) &&
            beginningTimes[i]!.isBefore(safetyWindow)) {
          return;
        }
      }
      if (state.jamaahOn[i] && jamaahTimes[i] != null) {
        final fireTime =
            jamaahTimes[i]!.subtract(Duration(minutes: state.jamaahMinutes[i]));
        if (fireTime.isAfter(now) && fireTime.isBefore(safetyWindow)) {
          return;
        }
      }
    }

    await NotificationService.cancelAll();

    for (int i = 0; i < 6; i++) {
      if (state.beginningOn[i] && beginningTimes[i] != null) {
        DateTime target = beginningTimes[i]!;
        if (target.isBefore(now)) target = target.add(const Duration(days: 1));
        await NotificationService.scheduleBeginning(
            index: i, prayerDateTime: target);
      }

      if (state.jamaahOn[i] && jamaahTimes[i] != null) {
        DateTime target = jamaahTimes[i]!;
        if (target.isBefore(now)) target = target.add(const Duration(days: 1));
        await NotificationService.scheduleJamaah(
            index: i,
            jamaahDateTime: target,
            minutesBefore: state.jamaahMinutes[i]);
      }
    }
  } catch (e) {
    print('PrayerScheduler: scheduling error: $e');
  }
}

// ── Reads the 6 beginning prayer DateTimes ────────────────────────────────────
// Always reads from the yearly JSON cache keyed to [date] (or today).
// This means even if WorkManager never ran, we always get the correct day's
// times rather than stale yesterday values from plain prefs.
// Falls back to plain prefs only if the yearly cache is missing entirely.
List<DateTime?> _readBeginningTimesFromPrefs(SharedPreferences prefs,
    {DateTime? date}) {
  final d = date ?? DateTime.now();
  final dateStr = DateFormat('dd-MM-yyyy').format(d);
  final yearKey = 'prayerTimes_${d.year}';

  try {
    final jsonString = prefs.getString(yearKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      String clean(String t) => t.replaceAll(RegExp(r'\s*\(GMT\)'), '').trim();

      for (final item in jsonList) {
        // Aladhan format
        final aladhanDate = item['date']?['gregorian']?['date'];
        if (aladhanDate == dateStr) {
          final timings = item['timings'];
          return _timingsToDateTimes({
            'fajr': clean(timings['Fajr'] ?? ''),
            'sunrise': clean(timings['Sunrise'] ?? ''),
            'dhuhr': clean(timings['Dhuhr'] ?? ''),
            'asr': clean(timings['Asr'] ?? ''),
            'maghrib': clean(timings['Maghrib'] ?? ''),
            'isha': clean(timings['Isha'] ?? ''),
          }, d);
        }

        // Mosque timetable format
        final mosqueDate = item['date'];
        if (mosqueDate is String && mosqueDate == dateStr) {
          return _timingsToDateTimes({
            'fajr': item['fajr'] ?? '',
            'sunrise': item['sunrise'] ?? '',
            'dhuhr': item['dhuhr'] ?? '',
            'asr': item['asr'] ?? '',
            'maghrib': item['maghrib'] ?? '',
            'isha': item['isha'] ?? '',
          }, d);
        }
      }
    }
  } catch (_) {}

  // Fallback: plain pref keys (may be yesterday's if WorkManager didn't run)
  final keys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  return keys.map((key) {
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return null;
    try {
      final parts = str.split(':');
      return DateTime(
          d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }).toList();
}

// Helper: converts a map of 'HH:mm' strings to DateTimes on [d]
List<DateTime?> _timingsToDateTimes(Map<String, String> map, DateTime d) {
  final order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  return order.map((key) {
    final str = map[key];
    if (str == null || str.isEmpty) return null;
    try {
      final parts = str.split(':');
      return DateTime(
          d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }).toList();
}

// ── Reads the 6 jamaat DateTimes from SharedPreferences ──────────────────────
// [date] is the day these times belong to — pass tomorrow when called from the
// background task after updating prefs with tomorrow's data.
List<DateTime?> _readJamaahTimesFromPrefs(SharedPreferences prefs,
    {DateTime? date}) {
  final keys = [
    'jamaah_fajr',
    'jamaah_sunrise',
    'jamaah_dhuhr',
    'jamaah_asr',
    'jamaah_maghrib',
    'jamaah_isha'
  ];
  final d = date ?? DateTime.now();
  return keys.map((key) {
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return null;
    try {
      final parts = str.split(':');
      return DateTime(
          d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────────────

class PrayerScheduler {
  /// Call this once from main() after Firebase init.
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await _registerDailyTask();
  }

  static Future<void> _registerDailyTask() async {
    await Workmanager().registerPeriodicTask(
      _kDailyTaskUnique,
      _kDailyTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: _timeUntilMidnight(),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Duration _timeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    return midnight.difference(now);
  }

  /// Call this immediately after prayer times are loaded in-app.
  /// Only saves jamaahTimes to prefs if the map is non-empty —
  /// prevents homeScreen from wiping jamaat prefs that prayerScreen already set.
  static Future<void> scheduleNow({
    required Map<String, String> beginningTimes,
    required Map<String, String> jamaahTimes,
  }) async {
    if (jamaahTimes.isNotEmpty) await saveJamaahTimes(jamaahTimes);
    final prefs = await SharedPreferences.getInstance();
    await _scheduleTodayNotifications(prefs);
  }

  /// Saves the full year's jamaat data to prefs as JSON so the midnight
  /// background task can read tomorrow's row without hitting Firestore.
  /// Call this from prayerScreen after loadFullYearJamaatFromFirebase completes.
  static Future<void> saveFullYearJamaahTimes(
      List<Map<String, dynamic>> yearData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jamaahTimes_year', jsonEncode(yearData));
  }

  /// Saves jama'ah times to SharedPreferences under 'jamaah_fajr' etc.
  static Future<void> saveJamaahTimes(Map<String, String> jamaahTimes) async {
    final prefs = await SharedPreferences.getInstance();
    const keyMap = {
      'fajr': 'jamaah_fajr',
      'sunrise': 'jamaah_sunrise',
      'dhuhr': 'jamaah_dhuhr',
      'asr': 'jamaah_asr',
      'maghrib': 'jamaah_maghrib',
      'isha': 'jamaah_isha',
    };
    for (final entry in jamaahTimes.entries) {
      final prefKey = keyMap[entry.key.toLowerCase()];
      if (prefKey != null) {
        await prefs.setString(prefKey, entry.value);
      }
    }
  }

  /// Cancel everything and stop the background task.
  static Future<void> cancelAll() async {
    await NotificationService.cancelAll();
    await Workmanager().cancelAll();
  }
}

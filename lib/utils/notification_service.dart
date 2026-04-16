import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION ID MAP
//
//  Beginning notifications : 0–5
//  Jama'ah  notifications  : 10–15
//
//  Index → Prayer
//  0 = Fajr   1 = Sunrise   2 = Dhuhr
//  3 = Asr    4 = Maghrib   5 = Isha
// ─────────────────────────────────────────────────────────────────────────────

// Result object returned from every toggle action so the UI can react
class NotifResult {
  final bool success;
  final String? errorMessage;
  const NotifResult.ok()
      : success = true,
        errorMessage = null;
  const NotifResult.fail(this.errorMessage) : success = false;
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  // ── Prayer name helpers ───────────────────────────────────────────────────

  static const List<String> prayerNames = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha'
  ];

  // ── Pref keys ─────────────────────────────────────────────────────────────

  static String _beginningKey(int index) =>
      'notif_${prayerNames[index].toLowerCase()}_b';

  static String _jamaahActiveKey(int index) =>
      'notif_${prayerNames[index].toLowerCase()}_j_active';

  static String _jamaahMinutesKey(int index) =>
      'notif_${prayerNames[index].toLowerCase()}_j_minutes';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialised) return;

    tz.initializeTimeZones();
    final TimezoneInfo timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    // Register channels explicitly — required for Android 8+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(AndroidNotificationChannel(
      'prayer_beginning_adhan',
      'Prayer Beginning',
      description: 'Notifications at the beginning of each prayer time',
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('adhan_app'),
      playSound: true,
    ));

    await android?.createNotificationChannel(AndroidNotificationChannel(
      'prayer_jamaah_iqamah',
      "Jama'ah Reminders",
      description: "Reminders before jama'ah time",
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('iqamah_app'),
      playSound: true,
    ));

    await android?.requestNotificationsPermission();

    _initialised = true;
  }

  // ── Permission check ──────────────────────────────────────────────────────

  static Future<bool> hasExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  static Future<void> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  // ── Pref readers ──────────────────────────────────────────────────────────

  static Future<bool> getBeginningEnabled(int index) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_beginningKey(index)) ?? false;
  }

  static Future<bool> getJamaahEnabled(int index) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_jamaahActiveKey(index)) ?? false;
  }

  static Future<int> getJamaahMinutes(int index) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_jamaahMinutesKey(index)) ?? 10;
  }

  // Load all toggles at once for the UI — returns two lists of length 6
  static Future<NotifState> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final beginningOn =
        List.generate(6, (i) => prefs.getBool(_beginningKey(i)) ?? false);
    final jamaahOn =
        List.generate(6, (i) => prefs.getBool(_jamaahActiveKey(i)) ?? false);
    final jamaahMins =
        List.generate(6, (i) => prefs.getInt(_jamaahMinutesKey(i)) ?? 10);
    return NotifState(beginningOn, jamaahOn, jamaahMins);
  }

  // ── Core scheduling ───────────────────────────────────────────────────────

  /// Schedule a beginning notification for a prayer.
  /// [prayerDateTime] must be today's actual DateTime for that prayer.
  static Future<NotifResult> scheduleBeginning({
    required int index,
    required DateTime prayerDateTime,
  }) async {
    try {
      if (!await hasExactAlarmPermission()) {
        return const NotifResult.fail('exact_alarm_permission');
      }

      // If time already passed today, schedule for tomorrow same time
      DateTime target = prayerDateTime;
      if (target.isBefore(DateTime.now())) {
        target = target.add(const Duration(days: 1));
      }

      final tzTime = tz.TZDateTime.from(target, tz.local);

      await _plugin.zonedSchedule(
        id: index, // 0–5
        title: prayerNames[index],
        body: 'It\'s time for ${prayerNames[index]}',
        scheduledDate: tzTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_beginning_adhan',
            'Prayer Beginning',
            channelDescription:
                'Notifications at the beginning of each prayer time',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('adhan_app'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      return const NotifResult.ok();
    } catch (e) {
      return NotifResult.fail(e.toString());
    }
  }

  /// Schedule a jama'ah reminder [minutesBefore] minutes before [jamaahDateTime].
  static Future<NotifResult> scheduleJamaah({
    required int index,
    required DateTime jamaahDateTime,
    required int minutesBefore,
  }) async {
    try {
      if (!await hasExactAlarmPermission()) {
        return const NotifResult.fail('exact_alarm_permission');
      }

      DateTime target =
          jamaahDateTime.subtract(Duration(minutes: minutesBefore));

      if (target.isBefore(DateTime.now())) {
        target = target.add(const Duration(days: 1));
      }

      final tzTime = tz.TZDateTime.from(target, tz.local);

      await _plugin.zonedSchedule(
        id: index + 10, // 10–15
        title: "${prayerNames[index]} Jama'ah",
        body:
            "Jama'ah in $minutesBefore minute${minutesBefore == 1 ? '' : 's'}",
        scheduledDate: tzTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_jamaah_iqamah',
            "Jama'ah Reminders",
            channelDescription: "Reminders before jama'ah time",
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('iqamah_app'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      return const NotifResult.ok();
    } catch (e) {
      return NotifResult.fail(e.toString());
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  static Future<void> cancelBeginning(int index) async {
    await _plugin.cancel(id: index);
  }

  static Future<void> cancelJamaah(int index) async {
    await _plugin.cancel(id: index + 10);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Toggle handlers (called from UI) ──────────────────────────────────────

  /// Toggle beginning notification ON or OFF.
  /// Pass [prayerDateTime] = today's DateTime for this prayer.
  /// Returns [NotifResult] for the UI to handle.
  static Future<NotifResult> toggleBeginning({
    required int index,
    required bool enable,
    DateTime? prayerDateTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_beginningKey(index), enable);

    if (!enable) {
      await cancelBeginning(index);
      return const NotifResult.ok();
    }

    if (prayerDateTime == null) {
      return const NotifResult.fail('no_prayer_time');
    }

    return scheduleBeginning(index: index, prayerDateTime: prayerDateTime);
  }

  /// Toggle jama'ah notification ON or OFF.
  /// Pass [jamaahDateTime] = today's DateTime for jama'ah.
  static Future<NotifResult> toggleJamaah({
    required int index,
    required bool enable,
    required int minutesBefore,
    DateTime? jamaahDateTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_jamaahActiveKey(index), enable);
    await prefs.setInt(_jamaahMinutesKey(index), minutesBefore);

    if (!enable) {
      await cancelJamaah(index);
      return const NotifResult.ok();
    }

    if (jamaahDateTime == null) {
      return const NotifResult.fail('no_jamaah_time');
    }

    return scheduleJamaah(
      index: index,
      jamaahDateTime: jamaahDateTime,
      minutesBefore: minutesBefore,
    );
  }

  // ── Debug helper ──────────────────────────────────────────────────────────

  static Future<List<PendingNotificationRequest>> getPending() async {
    return await _plugin.pendingNotificationRequests();
  }
}

// ── State container returned to UI ────────────────────────────────────────────

class NotifState {
  final List<bool> beginningOn; // length 6
  final List<bool> jamaahOn; // length 6
  final List<int> jamaahMinutes; // length 6

  const NotifState(this.beginningOn, this.jamaahOn, this.jamaahMinutes);
}

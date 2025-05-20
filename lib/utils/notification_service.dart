import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/prayerTimesClass.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'prayer_channel',
      'Prayer Notifications',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('azan8'),
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> schedulePrayerNotification({
    required int index,
    required List<PrayerTimes> monthlyPrayerTimesList,
  }) async {
    try {
      print('Scheduling notification for index $index');
      final String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final PrayerTimes todayPrayerTimes = monthlyPrayerTimesList.firstWhere(
        (prayer) => prayer.date == todayDate,
        orElse: () => PrayerTimes(
          date: todayDate,
          fajr: "00:00",
          sunrise: "00:00",
          dhuhr: "00:00",
          asr: "00:00",
          maghrib: "00:00",
          isha: "00:00",
        ),
      );

      final List<String> prayerTimes = [
        todayPrayerTimes.fajr,
        todayPrayerTimes.sunrise,
        todayPrayerTimes.dhuhr,
        todayPrayerTimes.asr,
        todayPrayerTimes.maghrib,
        todayPrayerTimes.isha,
      ];

      final List<String> prayerNames = [
        'Fajr',
        'Sunrise',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha'
      ];

      final timeParts = prayerTimes[index].split(':');
      final DateTime prayerTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (prayerTime.isAfter(DateTime.now())) {
        final tz.TZDateTime scheduledTime =
            tz.TZDateTime.from(prayerTime, tz.local);

        await _notificationsPlugin.zonedSchedule(
          index,
          "It's ${prayerNames[index]} time",
          'Time for ${prayerNames[index]} prayer!',
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_channel',
              'Prayer Notifications',
              sound: RawResourceAndroidNotificationSound('azan8'),
              playSound: true,
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        print(
            'Notification scheduled for ${prayerNames[index]} at $scheduledTime');
      } else {
        print(
            'Notification not scheduled for ${prayerNames[index]} (time is in the past)');
      }
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }

  static Future<void> cancelNotification(int index) async {
    await _notificationsPlugin.cancel(index);
  }
}

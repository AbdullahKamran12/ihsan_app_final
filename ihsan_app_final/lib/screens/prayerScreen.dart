import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/homeScreen.dart';
import 'package:ihsan_app_final/main.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/qiblaScreen.dart';
import 'package:ihsan_app_final/screens/quranScreen.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/utils/notification_service.dart';

bool change = false;

PrayerTimes? todayPrayerTimes;
PrayerTimes? otherDayPrayerTimes;
List<PrayerTimes> monthlyPrayerTimesList = [];
Future<PrayerTimes>? prayerTimesFuture;

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  _PrayerTimesScreenState createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  int _selectedIndex = 0;
  List<PrayerTimesJamaat> prayerTimesListJamaat = [];
  Timer? _timer;
  String timeRemaining = '';
  String nextPrayerName = '';

  DateTime _displayDate = DateTime.now();
  final DateTime _todayDate = DateTime.now();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool checkMonthDate = false;
  bool _notificationsScheduled = false;

  List<bool> notificationToggles = List.generate(6, (_) => false);

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    loadAdjustments();
    initializeMonthlyPrayerTimes();
    loadPrayerTimesFromCSV();
    loadNotificationToggles();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    DateTime now = DateTime.now();
    int secondsUntilNextMinute = 60 - now.second;

    Future.delayed(Duration(seconds: secondsUntilNextMinute), () {
      _updateRemainingTime();
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        _updateRemainingTime();
      });
    });
  }

  void _updateRemainingTime() {
    DateTime now = DateTime.now();
    String nextPrayerName = '';
    String timeRemaining = '';

    List<String> prayerTimesList = [
      todayPrayerTimes!.fajr,
      todayPrayerTimes!.sunrise,
      todayPrayerTimes!.dhuhr,
      todayPrayerTimes!.asr,
      todayPrayerTimes!.maghrib,
      todayPrayerTimes!.isha,
    ];

    List<String> prayerNames = [
      'Fajr',
      'Sunrise',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];

    for (int i = 0; i < prayerTimesList.length; i++) {
      final timeParts = prayerTimesList[i].split(':');
      DateTime prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (prayerTime.isAfter(now)) {
        nextPrayerName = prayerNames[i];
        Duration remaining = prayerTime.difference(now);
        timeRemaining =
            '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        break;
      }
    }

    if (nextPrayerName.isEmpty) {
      nextPrayerName = 'Fajr';
      final fajrParts = todayPrayerTimes!.fajr.split(':');
      DateTime nextFajrTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        int.parse(fajrParts[0]),
        int.parse(fajrParts[1]),
      );

      Duration remaining = nextFajrTime.difference(now);
      timeRemaining =
          '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }

    setState(() {
      this.nextPrayerName = nextPrayerName;
      this.timeRemaining = timeRemaining;
    });
  }

  void _settingsPageGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingScreen()),
    );
  }

  Future<void> loadNotificationToggles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationToggles = [
        prefs.getBool('notif_fajr') ?? false,
        prefs.getBool('notif_sunrise') ?? false,
        prefs.getBool('notif_dhuhr') ?? false,
        prefs.getBool('notif_asr') ?? false,
        prefs.getBool('notif_maghrib') ?? false,
        prefs.getBool('notif_isha') ?? false,
      ];
    });
  }

  void _toggleNotification(int index) {
    setState(() {
      notificationToggles[index] = !notificationToggles[index];
    });
    updateNotificationToggle(index, notificationToggles[index]);
  }

  Future<void> updateNotificationToggle(int index, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (index) {
      case 0:
        await prefs.setBool('notif_fajr', value);
        break;
      case 1:
        await prefs.setBool('notif_sunrise', value);
        break;
      case 2:
        await prefs.setBool('notif_dhuhr', value);
        break;
      case 3:
        await prefs.setBool('notif_asr', value);
        break;
      case 4:
        await prefs.setBool('notif_maghrib', value);
        break;
      case 5:
        await prefs.setBool('notif_isha', value);
        break;
    }
    if (value) {
      await _schedulePrayerNotification(index);
    } else {
      await NotificationService.cancelNotification(index);
    }
  }

  Future<void> _schedulePrayerNotification(int index) async {
    await NotificationService.schedulePrayerNotification(
      index: index,
      monthlyPrayerTimesList: monthlyPrayerTimesList,
    );
  }

  Future<void> initializeMonthlyPrayerTimes() async {
    List<PrayerTimes> storedPrayerTimes = await loadMonthlyPrayerTimes();
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    DateTime now = DateTime.now();

    if (storedPrayerTimes.isEmpty ||
        storedPrayerTimes.any((prayerTime) {
          DateTime prayerDate = DateFormat('dd-MM-yyyy').parse(prayerTime.date);
          return prayerDate.month != now.month || prayerDate.year != now.year;
        }) ||
        change == true ||
        prayerTimesFuture == null) {
      try {
        prayerTimesFuture = fetchMonthlyPrayerTimes(
                latitude, longitude, method, school, year, month)
            .then((monthlyPrayerTimes) {
          monthlyPrayerTimesList = monthlyPrayerTimes;
          saveMonthlyPrayerTimes(monthlyPrayerTimesList);

          todayPrayerTimes = monthlyPrayerTimes.firstWhere(
              (prayerTime) => prayerTime.date == todayDate,
              orElse: () => throw Exception('No prayer times for today'));

          _savePrayerTimesToLocal(todayPrayerTimes!, todayPrayerTimes!.date);
          setState(() {
            change = false;
          });

          return todayPrayerTimes!;
        });
      } catch (error) {
        print("Error fetching prayer times from API: $error");
      }
    } else {
      setState(() {
        monthlyPrayerTimesList = storedPrayerTimes;
        prayerTimesFuture = setFuturePrayerTimes();
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QiblaScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QuranScreen()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MoreOptionsScreen()),
        );
        break;
    }
  }

  Future<void> saveMonthlyPrayerTimes(List<PrayerTimes> prayerTimesList) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList =
        prayerTimesList.map((prayer) => prayer.toJson()).toList();
    String jsonString = jsonEncode(jsonList);
    await prefs.setString('monthlyPrayerTimes', jsonString);
  }

  Future<List<PrayerTimes>> loadMonthlyPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('monthlyPrayerTimes');

    if (jsonString != null) {
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => PrayerTimes.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  Future<PrayerTimes> setFuturePrayerTimes() async {
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    todayPrayerTimes = monthlyPrayerTimesList.firstWhere(
        (prayerTime) => prayerTime.date == todayDate,
        orElse: () => throw Exception('No prayer times for today'));

    return todayPrayerTimes!;
  }

  Future<void> loadPrayerTimesFromCSV() async {
    final csvData = await rootBundle
        .loadString('assets/Bolton, Lancashire, UK Prayer Times.csv');

    List<List<dynamic>> rows = CsvToListConverter().convert(csvData);

    for (var row in rows.skip(1)) {
      String date = row[0];
      String fajr = row[1];
      String sunrise = row[2];
      String dhuhr = row[3];
      String asr = row[4];
      String maghrib = row[5];
      String isha = row[6];

      prayerTimesListJamaat.add(PrayerTimesJamaat(
        date: date,
        fajr: fajr,
        sunrise: sunrise,
        dhuhr: dhuhr,
        asr: asr,
        maghrib: maghrib,
        isha: isha,
      ));
    }
    setState(() {});
  }

  void _incrementDisplayDate() {
    if (_checkIfMonthMatches(_displayDate.add(const Duration(days: 1)))) {
      setState(() {
        _displayDate = _displayDate.add(const Duration(days: 1));
      });
    } else {
      setState(() {
        checkMonthDate = true;
      });
    }
  }

  void _decrementDisplayDate() {
    if (_checkIfMonthMatches(_displayDate.subtract(const Duration(days: 1)))) {
      setState(() {
        _displayDate = _displayDate.subtract(const Duration(days: 1));
      });
    } else {
      setState(() {
        checkMonthDate = true;
      });
    }
  }

  bool _checkIfMonthMatches(DateTime dateToCheck) {
    if (monthlyPrayerTimesList.isEmpty) {
      return false;
    }

    DateTime firstPrayerDate =
        DateFormat('dd-MM-yyyy').parse(monthlyPrayerTimesList.first.date);

    return firstPrayerDate.month == dateToCheck.month &&
        firstPrayerDate.year == dateToCheck.year;
  }

  void _todayDisplayDate() {
    setState(() {
      _displayDate = _todayDate;
      checkMonthDate = false;
    });
  }

  Future<void> _savePrayerTimesToLocal(
      PrayerTimes prayerTimes, String date) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setString('fajr', prayerTimes.fajr);
    prefs.setString('sunrise', prayerTimes.sunrise);
    prefs.setString('dhuhr', prayerTimes.dhuhr);
    prefs.setString('asr', prayerTimes.asr);
    prefs.setString('maghrib', prayerTimes.maghrib);
    prefs.setString('isha', prayerTimes.isha);
    prefs.setString('prayerTimesDate', date);
  }

  @override
  Widget build(BuildContext context) {
    const Color deepBlue =
        Color.fromARGB(255, 41, 82, 122); // Blueish, instead of deepTeal
    const Color lightGold = const Color(0xFFFFD700); // Light Gold remains
    const Color offWhite = Color(0xFFF8F8F8);
    return Scaffold(
      backgroundColor: deepBlue,
      appBar: buildAppBar(context, 'Prayer Times', const HomeScreen(), null),
      body: FutureBuilder<PrayerTimes>(
        future: prayerTimesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: offWhite));
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: offWhite),
              ),
            );
          } else if (snapshot.hasData) {
            final prayerTimes = snapshot.data!;

            DateTime now = DateTime.now();

            List<String> beginingTimes = [];
            List<String> jamaatTimes = [];

            for (var prayerTime in prayerTimesListJamaat) {
              DateTime prayerDate =
                  DateFormat('EEE d MMM yyyy').parse(prayerTime.date);
              if (prayerDate.year == _displayDate.year &&
                  prayerDate.month == _displayDate.month &&
                  prayerDate.day == _displayDate.day) {
                jamaatTimes = [
                  prayerTime.fajr,
                  prayerTime.sunrise,
                  prayerTime.dhuhr,
                  prayerTime.asr,
                  prayerTime.maghrib,
                  prayerTime.isha,
                ];
                break;
              }
            }

            for (var prayerTime in monthlyPrayerTimesList) {
              DateTime prayerDate =
                  DateFormat('dd-MM-yyyy').parse(prayerTime.date);
              if (prayerDate.year == _displayDate.year &&
                  prayerDate.month == _displayDate.month &&
                  prayerDate.day == _displayDate.day) {
                beginingTimes = [
                  prayerTime.fajr,
                  prayerTime.sunrise,
                  prayerTime.dhuhr,
                  prayerTime.asr,
                  prayerTime.maghrib,
                  prayerTime.isha,
                ];
                break;
              }
            }

            List<PrayerTime> prayerTimesList = [
              PrayerTime('Fajr', beginingTimes[0], jamaatTimes[0]),
              PrayerTime('Sunrise', beginingTimes[1], jamaatTimes[1]),
              PrayerTime('Dhuhr', beginingTimes[2], jamaatTimes[2]),
              PrayerTime('Asr', beginingTimes[3], jamaatTimes[3]),
              PrayerTime('Maghrib', beginingTimes[4], jamaatTimes[4]),
              PrayerTime('Isha', beginingTimes[5], jamaatTimes[5]),
            ];

            if (todayPrayerTimes != null) {
              List<String> prayerTimesList = [
                todayPrayerTimes!.fajr,
                todayPrayerTimes!.sunrise,
                todayPrayerTimes!.dhuhr,
                todayPrayerTimes!.asr,
                todayPrayerTimes!.maghrib,
                todayPrayerTimes!.isha,
              ];

              List<String> prayerNames = [
                'Fajr',
                'Sunrise',
                'Dhuhr',
                'Asr',
                'Maghrib',
                'Isha',
              ];

              for (int i = 0; i < prayerTimesList.length; i++) {
                final timeParts = prayerTimesList[i].split(':');
                DateTime prayerTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                );

                if (prayerTime.isAfter(now)) {
                  nextPrayerName = prayerNames[i];
                  Duration remaining = prayerTime.difference(now);
                  timeRemaining =
                      '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
                  break;
                }
              }

              if (nextPrayerName.isEmpty) {
                nextPrayerName = 'Fajr';

                final fajrParts = todayPrayerTimes!.fajr.split(':');
                DateTime nextFajrTime = DateTime(
                  now.year,
                  now.month,
                  now.day + 1,
                  int.parse(fajrParts[0]),
                  int.parse(fajrParts[1]),
                );

                Duration remaining = nextFajrTime.difference(now);
                timeRemaining =
                    '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
              }
            }
            if (checkMonthDate == false) {
              return Column(
                children: [
                  // Next prayer card with shadow and rounded corners
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          townName,
                          style: const TextStyle(
                            color: lightGold,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  "Next Prayer",
                                  style: TextStyle(
                                    color: offWhite,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  nextPrayerName,
                                  style: const TextStyle(
                                    color: lightGold,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 50),
                            Column(
                              children: [
                                const Text(
                                  "Remaining",
                                  style: TextStyle(
                                    color: offWhite,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  timeRemaining,
                                  style: const TextStyle(
                                    color: lightGold,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _settingsPageGoTo(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lightGold,
                              foregroundColor: deepBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Settings",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _todayDisplayDate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: offWhite,
                              foregroundColor: deepBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Go to Today",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Date navigation
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _decrementDisplayDate,
                          icon:
                              const Icon(Icons.arrow_back_ios, color: offWhite),
                        ),
                        Text(
                          DateFormat.yMMMMd().format(_displayDate),
                          style: const TextStyle(
                            color: offWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: _incrementDisplayDate,
                          icon: const Icon(Icons.arrow_forward_ios,
                              color: offWhite),
                        ),
                      ],
                    ),
                  ),

                  // Table header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: lightGold,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                        ),
                      ),
                      child: todayPrayerTimes != null
                          ? Row(
                              children: const [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Salaah',
                                    style: TextStyle(
                                      color: Color(0xFF003366),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Beginning',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF003366),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Jama\'ah',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF003366),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Adhan',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Color(0xFF003366),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              "No prayer times available",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF003366),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // Prayer times list
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                      ),
                      child: todayPrayerTimes != null
                          ? ListView.separated(
                              itemCount: prayerTimesList.length,
                              separatorBuilder: (context, index) => Divider(
                                color: Colors.white.withOpacity(0.2),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                bool isNextPrayer =
                                    prayerTimesList[index].name ==
                                        nextPrayerName;
                                return Container(
                                  decoration: isNextPrayer
                                      ? BoxDecoration(
                                          color: lightGold.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        )
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12.0, horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          prayerTimesList[index].name,
                                          style: TextStyle(
                                            color: isNextPrayer
                                                ? lightGold
                                                : offWhite,
                                            fontSize: 16,
                                            fontWeight: isNextPrayer
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          prayerTimesList[index].time,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isNextPrayer
                                                ? lightGold
                                                : offWhite,
                                            fontSize: 16,
                                            fontWeight: isNextPrayer
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          prayerTimesList[index].jamaatTime,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isNextPrayer
                                                ? lightGold
                                                : offWhite,
                                            fontSize: 16,
                                            fontWeight: isNextPrayer
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            onPressed: () =>
                                                _toggleNotification(index),
                                            icon: Icon(
                                              notificationToggles[index]
                                                  ? Icons.notifications_active
                                                  : Icons.notifications_off,
                                              color: notificationToggles[index]
                                                  ? lightGold
                                                  : offWhite,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "No prayer times available for this date.",
                                    style: TextStyle(
                                        color: offWhite, fontSize: 16),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _todayDisplayDate,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: lightGold,
                                      foregroundColor: deepBlue,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(16),
                                    ),
                                    child: const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No data available for this month',
                    style: TextStyle(color: offWhite, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _todayDisplayDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightGold,
                      foregroundColor: deepBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Go to today',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }
          } else {
            return const Center(
              child: Text(
                'No data available',
                style: TextStyle(color: offWhite, fontSize: 18),
              ),
            );
          }
        },
      ),
      bottomNavigationBar: buildBottomNavigationBar(context, 1, _onItemTapped),
    );
  }
}

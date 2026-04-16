import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ihsan_app_final/utils/prayer_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
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

  String _hijriDate = '';
  final Map<String, String> _hijriCache = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _notificationsScheduled = false;
  bool _jummahExpanded = false;

  List<bool> notifBeginningOn = List.generate(6, (_) => false);
  List<bool> notifJamaahOn = List.generate(6, (_) => false);
  List<int> notifJamaahMins = List.generate(6, (_) => 10);

  // Per-bell loading flags (true while async toggle is in progress)
  List<bool> notifBeginningLoading = List.generate(6, (_) => false);
  List<bool> notifJamaahLoading = List.generate(6, (_) => false);

  // Last result per bell — shown as a brief tick/cross then clears
  // null = idle, true = success, false = failed
  List<bool?> notifBeginningResult = List.generate(6, (_) => null);
  List<bool?> notifJamaahResult = List.generate(6, (_) => null);

  @override
  void initState() {
    super.initState();
    loadAdjustments();
    _loadCachedPrayerTimes();
    initializeMonthlyPrayerTimes();
    _loadMosquePreference().then((_) => loadFullYearJamaatFromFirebase());
    _initNotificationsAndLoad();
    _startTimer();
    _fetchHijriDate(_displayDate);
  }

  Future<void> _fetchHijriDate(DateTime date) async {
    final key =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    // Return cached result immediately
    if (_hijriCache.containsKey(key)) {
      if (mounted) setState(() => _hijriDate = _hijriCache[key]!);
      return;
    }
    try {
      final response = await http
          .get(Uri.parse('https://api.aladhan.com/v1/gToH?date=$key'));
      if (response.statusCode == 200) {
        final hijri = jsonDecode(response.body)['data']['hijri'];
        final result =
            '${hijri['day']} ${hijri['month']['en']} ${hijri['year']}';
        _hijriCache[key] = result;
        if (mounted) setState(() => _hijriDate = result);
      }
    } catch (e) {
      debugPrint('Hijri date fetch error: $e');
    }
  }

  Future<void> _initNotificationsAndLoad() async {
    await NotificationService.init();
    final state = await NotificationService.loadAll();
    if (!mounted) return;
    setState(() {
      notifBeginningOn = state.beginningOn;
      notifJamaahOn = state.jamaahOn;
      notifJamaahMins = state.jamaahMinutes;
    });
  }

  void _showNotifSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error
          ? const Color.fromARGB(255, 180, 50, 50)
          : const Color.fromARGB(255, 18, 42, 95),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _handleNotifError(String? error) {
    switch (error) {
      case 'exact_alarm_permission':
        _showNotifSnack(
            'Enable "Alarms & reminders" in Settings for exact prayer times',
            error: true);
        break;
      case 'no_prayer_time':
        _showNotifSnack('Prayer times not loaded yet', error: true);
        break;
      case 'no_jamaah_time':
        _showNotifSnack('Select a mosque to enable Jama\'ah notifications',
            error: true);
        break;
      default:
        _showNotifSnack('Something went wrong — please try again', error: true);
    }
  }

  Future<void> _toggleBeginning(int index) async {
    // Guard: need prayer times loaded
    if (todayPrayerTimes == null) {
      _showNotifSnack('Prayer times not loaded yet', error: true);
      return;
    }

    // Check exact alarm permission first
    if (!await NotificationService.hasExactAlarmPermission()) {
      await NotificationService.requestExactAlarmPermission();
      _showNotifSnack(
          'Please enable "Alarms & reminders" for exact prayer times',
          error: true);
      return;
    }

    final enabling = !notifBeginningOn[index];

    setState(() {
      notifBeginningLoading[index] = true;
      notifBeginningResult[index] = null;
    });

    // Build today's DateTime for this prayer
    DateTime? prayerDT;
    if (enabling) {
      prayerDT = _prayerDateTime(index);
    }

    final result = await NotificationService.toggleBeginning(
      index: index,
      enable: enabling,
      prayerDateTime: prayerDT,
    );

    if (!mounted) return;

    setState(() {
      notifBeginningLoading[index] = false;
      notifBeginningOn[index] = enabling && result.success;
      notifBeginningResult[index] = result.success;
    });

    if (result.success) {
      _showNotifSnack(
        enabling
            ? '${NotificationService.prayerNames[index]} beginning notification set ✓'
            : '${NotificationService.prayerNames[index]} beginning notification removed',
      );
    } else {
      _handleNotifError(result.errorMessage);
    }

    // Clear the tick/cross icon after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => notifBeginningResult[index] = null);
    });
  }

  Future<void> _toggleJamaah(int index) async {
    // If already ON → just turn off
    if (notifJamaahOn[index]) {
      setState(() {
        notifJamaahLoading[index] = true;
        notifJamaahResult[index] = null;
      });

      final result = await NotificationService.toggleJamaah(
        index: index,
        enable: false,
        minutesBefore: notifJamaahMins[index],
      );

      if (!mounted) return;
      setState(() {
        notifJamaahLoading[index] = false;
        notifJamaahOn[index] = false;
        notifJamaahResult[index] = result.success;
      });
      _showNotifSnack(
          "${NotificationService.prayerNames[index]} Jama'ah reminder removed");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => notifJamaahResult[index] = null);
      });
      return;
    }

    // Guard: need jama'ah times
    if (prayerTimesListJamaat.isEmpty) {
      _showNotifSnack('Select a mosque first to set Jama\'ah notifications',
          error: true);
      return;
    }

    if (todayPrayerTimes == null) {
      _showNotifSnack('Prayer times not loaded yet', error: true);
      return;
    }

    if (!await NotificationService.hasExactAlarmPermission()) {
      await NotificationService.requestExactAlarmPermission();
      _showNotifSnack(
          'Please enable "Alarms & reminders" for exact prayer times',
          error: true);
      return;
    }

    // Open minutes picker
    final minutes = await _showMinutesPicker(notifJamaahMins[index]);
    if (minutes == null || !mounted) return; // user cancelled

    setState(() {
      notifJamaahLoading[index] = true;
      notifJamaahResult[index] = null;
    });

    final jamaahDT = _jamaahDateTime(index);

    final result = await NotificationService.toggleJamaah(
      index: index,
      enable: true,
      minutesBefore: minutes,
      jamaahDateTime: jamaahDT,
    );

    if (!mounted) return;
    setState(() {
      notifJamaahLoading[index] = false;
      notifJamaahOn[index] = result.success;
      notifJamaahMins[index] = minutes;
      notifJamaahResult[index] = result.success;
    });

    if (result.success) {
      _showNotifSnack(
          "${NotificationService.prayerNames[index]} Jama'ah reminder set — $minutes min before ✓");
    } else {
      _handleNotifError(result.errorMessage);
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => notifJamaahResult[index] = null);
    });
  }

  DateTime? _prayerDateTime(int index) {
    if (todayPrayerTimes == null) return null;
    final timeStr = [
      todayPrayerTimes!.fajr,
      todayPrayerTimes!.sunrise,
      todayPrayerTimes!.dhuhr,
      todayPrayerTimes!.asr,
      todayPrayerTimes!.maghrib,
      todayPrayerTimes!.isha,
    ][index];
    return _parseTimeToToday(timeStr);
  }

  DateTime? _jamaahDateTime(int index) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    PrayerTimesJamaat? entry;
    try {
      entry = prayerTimesListJamaat.firstWhere((e) => e.date == today);
    } catch (_) {
      return null;
    }

    final timeStr = [
      entry.fajr,
      entry.sunrise,
      entry.dhuhr,
      entry.asr,
      entry.maghrib,
      entry.isha,
    ][index];

    // Jumu'ah special case — use first jama'ah time
    if (index == 2 &&
        entry.jummahTimes != null &&
        entry.jummahTimes!.isNotEmpty) {
      return _parseTimeToToday(entry.jummahTimes!.first);
    }

    return _parseTimeToToday(timeStr);
  }

  DateTime _parseTimeToToday(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(
        now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<int?> _showMinutesPicker(int currentMinutes) async {
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color offWhite = Color.fromARGB(255, 247, 248, 252);
    const Color border = Color.fromARGB(255, 220, 224, 235);
    const Color textDark = Color.fromARGB(255, 20, 30, 60);

    int selected = currentMinutes;

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.mosque_outlined,
                      size: 18, color: Color.fromARGB(255, 10, 25, 60)),
                  SizedBox(width: 8),
                  Text(
                    "Minutes before Jama'ah",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color.fromARGB(255, 10, 25, 60),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Notification will fire this many minutes before Jama\'ah',
                style: TextStyle(
                    fontSize: 12, color: Color.fromARGB(255, 110, 120, 150)),
              ),
            ),
            const SizedBox(height: 16),

            // Grid of minute options 1–30
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(30, (i) {
                  final mins = i + 1;
                  final isSelected = selected == mins;
                  return GestureDetector(
                    onTap: () => setLocal(() => selected = mins),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? navy : offWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? gold.withOpacity(0.7) : border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$mins',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? gold : textDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, selected),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: gold.withOpacity(0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'Set $selected minute${selected == 1 ? '' : 's'} before',
                      style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMosquePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.doc('UserData/${user.uid}').get();
      final pref = (doc.data()?['mosquePreference'] as String?) ?? '';
      if (pref.isNotEmpty) {
        mosqueIdFind = pref;
      }
    } catch (e) {
      debugPrint('Failed to load mosque preference: $e');
    }
  }

  Widget _buildMosqueNameRow() {
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);

    if (_isFavouriting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          color: gold,
          strokeWidth: 2,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            _mosqueName.isNotEmpty
                ? _mosqueName
                : (mosqueIdFind.isEmpty &&
                        (tempMosqueId == null || tempMosqueId!.isEmpty))
                    ? 'No mosque selected'
                    : _mosqueName,
            style: const TextStyle(
              color: gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_mosqueName.isNotEmpty) ...[
          const SizedBox(width: 8),
          if (tempMosqueId != null && tempMosqueId!.isNotEmpty)
            GestureDetector(
              onTap: _favouriteMosque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withOpacity(0.6), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_border_rounded, size: 13, color: gold),
                    SizedBox(width: 4),
                    Text('Set Favourite',
                        style: TextStyle(
                            fontSize: 11,
                            color: gold,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'To change favourite, select another mosque from the home screen'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color.fromARGB(255, 18, 42, 95),
                ));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withOpacity(0.7), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 13, color: gold),
                    SizedBox(width: 4),
                    Text('Favourited',
                        style: TextStyle(
                            fontSize: 11,
                            color: gold,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> openNavigation(double lat, double lng) async {
    final appUri = Uri.parse('google.navigation:q=$lat,$lng');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  String getTodayDateId() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  List<String> _displayedJummahTimes = [];

  Future<void> loadFullYearJamaatFromFirebase() async {
    try {
      final activeId = tempMosqueId ?? mosqueIdFind;

      if (activeId.isEmpty) {
        setState(() {
          prayerTimesListJamaat = [];
          mosqueLat = null;
          mosqueLong = null;
          _mosqueName = '';
        });
        return;
      }
      final mosqueDoc = await FirebaseFirestore.instance
          .collection('mosques')
          .doc(activeId)
          .get();

      final snapshot = await FirebaseFirestore.instance
          .collection('mosques')
          .doc(activeId)
          .collection('prayerTimes')
          .get();

      final List<PrayerTimesJamaat> loaded = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        loaded.add(
          PrayerTimesJamaat(
            date: doc.id,
            fajr: data['fajrJ'] ?? '',
            sunrise: data['sunrise'] ?? '',
            dhuhr: data['dhuhrJ'] ?? '',
            asr: data['asrJ'] ?? '',
            maghrib: data['maghrib'] ?? '',
            isha: data['ishaJ'] ?? '',
            jummahTimes: data['jummahTimes'] != null // ← add this
                ? List<String>.from(data['jummahTimes'])
                : null,
          ),
        );
      }

      loaded.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        prayerTimesListJamaat = loaded;
        mosqueLat = mosqueDoc.data()?['lat'];
        mosqueLong = mosqueDoc.data()?['long'];
        _mosqueName = mosqueDoc.data()?['name'] ?? activeId;
      });

      // ── Save jama'ah times for background scheduler ──────────────────
      // 1. Save the full year as JSON so midnight task never needs Firestore
      final fullYearForPrefs = loaded
          .map((e) => {
                'date': e.date,
                'fajr': e.fajr,
                'sunrise': e.sunrise,
                'dhuhr': e.dhuhr,
                'asr': e.asr,
                'maghrib': e.maghrib,
                'isha': e.isha,
                if (e.jummahTimes != null) 'jummahTimes': e.jummahTimes,
              })
          .toList();
      await PrayerScheduler.saveFullYearJamaahTimes(fullYearForPrefs);

      // 2. Also save today's times to plain jamaah_ prefs for immediate use
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      try {
        final todayJamaat = loaded.firstWhere((e) => e.date == todayStr);

        final isFriday = DateTime.now().weekday == DateTime.friday;
        final dhuhrJamaah = isFriday &&
                todayJamaat.jummahTimes != null &&
                todayJamaat.jummahTimes!.isNotEmpty
            ? todayJamaat.jummahTimes!.first
            : todayJamaat.dhuhr;

        await PrayerScheduler.saveJamaahTimes({
          'fajr': todayJamaat.fajr,
          'sunrise': todayJamaat.sunrise,
          'dhuhr': dhuhrJamaah,
          'asr': todayJamaat.asr,
          'maghrib': todayJamaat.maghrib,
          'isha': todayJamaat.isha,
        });
      } catch (_) {
        // Today not in loaded list — no jama'ah times to save
      }
    } catch (e) {
      debugPrint('Failed to load yearly jamaat times: $e');
    }
  }

  double? mosqueLat;
  double? mosqueLong;
  String _mosqueName = '';
  bool _isFavouriting = false;

  Future<void> _favouriteMosque() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Log in to save a favourite mosque'),
        backgroundColor: Color.fromARGB(255, 18, 42, 95),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (tempMosqueId == null || tempMosqueId!.isEmpty) return;

    setState(() => _isFavouriting = true);
    try {
      await FirebaseFirestore.instance
          .doc('UserData/${user.uid}')
          .update({'mosquePreference': tempMosqueId});

      // Promote temp to permanent
      mosqueIdFind = tempMosqueId!;
      tempMosqueId = null;

      setState(() => _isFavouriting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$_mosqueName set as your favourite mosque'),
          backgroundColor: const Color.fromARGB(255, 72, 200, 155),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isFavouriting = false);
      debugPrint('Failed to save favourite: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    tempMosqueId = null;
    mosqueLat = null;
    mosqueLong = null;
    _mosqueName = '';
    super.dispose();
  }

  void _startTimer() {
    // Countdown display is handled by _PrayerCountdown (owns its own timer).
    // This timer only needs to update nextPrayerName once per minute.
    _timer?.cancel();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    DateTime now = DateTime.now();
    String nextPrayerName = '';
    if (todayPrayerTimes == null) return;

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
      '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    if (!mounted) return;

    setState(() {
      this.nextPrayerName = nextPrayerName;
    });
  }

  void _settingsPageGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingScreen()),
    );
  }

  Future<void> _loadCachedPrayerTimes() async {
    final stored = await loadMonthlyPrayerTimes();

    if (stored.isNotEmpty) {
      monthlyPrayerTimesList = stored;

      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());

      todayPrayerTimes =
          stored.firstWhere((p) => p.date == today, orElse: () => stored.first);

      if (mounted) setState(() {});
    }
  }

  Future<void> initializeMonthlyPrayerTimes() async {
    // ===== NEW: Check for saved mosque preference FIRST =====
    final savedMosqueId = await getLocalMosqueId();

    if (savedMosqueId.isNotEmpty) {
      try {
        if (await isConnected()) {
          final mosqueTimes = await fetchMosquePrayerTimes(savedMosqueId);

          if (mosqueTimes.isNotEmpty) {
            monthlyPrayerTimesList = mosqueTimes;
            await saveMonthlyPrayerTimes(monthlyPrayerTimesList);

            final todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

            // Find today's times
            try {
              todayPrayerTimes = monthlyPrayerTimesList.firstWhere(
                (prayerTime) => prayerTime.date == todayDate,
              );
            } catch (e) {
              // Today not in mosque data - use closest available
              if (monthlyPrayerTimesList.isNotEmpty) {
                todayPrayerTimes = monthlyPrayerTimesList.first;
              }
            }

            if (todayPrayerTimes != null) {
              _savePrayerTimesToLocal(
                  todayPrayerTimes!, todayPrayerTimes!.date);

              if (mounted) {
                setState(() {
                  change = false;
                  prayerTimesFuture = Future.value(todayPrayerTimes);
                });
              }

              // Success - exit early
              return;
            }
          }
        }
      } catch (e) {
        print("Error fetching mosque prayer times: $e");
        // Fall through to Aladhan
      }
    }

    // ===== ORIGINAL Aladhan flow (unchanged) =====
    List<PrayerTimes> storedPrayerTimes = await loadMonthlyPrayerTimes();
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    DateTime now = DateTime.now();

    if (storedPrayerTimes.isEmpty ||
        storedPrayerTimes.any((prayerTime) {
          DateTime prayerDate = DateFormat('dd-MM-yyyy').parse(prayerTime.date);
          return prayerDate.year != now.year;
        }) ||
        change == true ||
        prayerTimesFuture == null ||
        (await SharedPreferences.getInstance()).getString('prayerTimesDate') !=
            todayDate) {
      try {
        if (await isConnected()) {
          prayerTimesFuture = () async {
            List<PrayerTimes> yearlyTimes = [];

            for (int m = 1; m <= 12; m++) {
              final monthlyTimes = await fetchMonthlyPrayerTimes(
                latitude,
                longitude,
                method,
                school,
                year,
                m,
              );
              yearlyTimes.addAll(monthlyTimes);
            }

            monthlyPrayerTimesList = yearlyTimes;
            await saveMonthlyPrayerTimes(yearlyTimes);

            todayPrayerTimes = yearlyTimes.firstWhere(
              (prayerTime) => prayerTime.date == todayDate,
              orElse: () => throw Exception('No prayer times for today'),
            );

            _savePrayerTimesToLocal(todayPrayerTimes!, todayPrayerTimes!.date);

            if (mounted) {
              setState(() {
                change = false;
              });
            }

            return todayPrayerTimes!;
          }();
        } else {
          if (mounted) {
            setState(() {
              monthlyPrayerTimesList = storedPrayerTimes;
              prayerTimesFuture = setFuturePrayerTimes();
            });
          }
        }
      } catch (error) {
        print("Error fetching prayer times from API: $error");
      }
    } else {
      if (mounted) {
        setState(() {
          monthlyPrayerTimesList = storedPrayerTimes;
          prayerTimesFuture = setFuturePrayerTimes();
        });
      }
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

  Future<PrayerTimes> setFuturePrayerTimes() async {
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    todayPrayerTimes = monthlyPrayerTimesList.firstWhere(
        (prayerTime) => prayerTime.date == todayDate,
        orElse: () => throw Exception('No prayer times for today'));

    return todayPrayerTimes!;
  }

  void _incrementDisplayDate() {
    setState(() {
      _displayDate = _displayDate.add(const Duration(days: 1));
      _jummahExpanded = false;
    });
    _fetchHijriDate(_displayDate);
  }

  void _decrementDisplayDate() {
    setState(() {
      _displayDate = _displayDate.subtract(const Duration(days: 1));
      _jummahExpanded = false;
    });
    _fetchHijriDate(_displayDate);
  }

  void _todayDisplayDate() {
    setState(() {
      _displayDate = _todayDate;
      _jummahExpanded = false;
    });
    _fetchHijriDate(_displayDate);
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
    // ── Palette ───────────────────────────────────────────────────────
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color navyLight = Color.fromARGB(255, 28, 58, 120);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldLight = Color.fromARGB(255, 252, 243, 210);
    const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
    const Color skyLight = Color.fromARGB(255, 220, 240, 255);
    const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
    const Color mintLight = Color.fromARGB(255, 210, 245, 232);
    const Color white = Color.fromARGB(255, 255, 255, 255);
    const Color offWhite = Color.fromARGB(255, 247, 249, 255);
    const Color textDark = Color.fromARGB(255, 15, 30, 65);
    const Color textMid = Color.fromARGB(255, 90, 115, 160);
    const Color border = Color.fromARGB(255, 210, 220, 240);

    Widget headerCell(String text, TextAlign align) => Expanded(
          child: Text(text,
              textAlign: align,
              style: const TextStyle(
                color: gold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              )),
        );

    Widget timeChip(
      String time, {
      required bool isNext,
      required Color bg,
      required Color textColor,
      required Color borderColor,
    }) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              )),
        );

    return Scaffold(
      backgroundColor: navy,
      appBar: buildAppBar(context, 'Prayer Times', const HomeScreen(), null),
      bottomNavigationBar: buildBottomNavigationBar(context, 1, _onItemTapped),
      body: FutureBuilder<PrayerTimes>(
        future: prayerTimesFuture,
        builder: (context, snapshot) {
          final bool loading =
              snapshot.connectionState == ConnectionState.waiting;
          final bool hasError = snapshot.hasError;

          // If we have absolutely nothing yet (first ever load)
          if (loading &&
              monthlyPrayerTimesList.isEmpty &&
              prayerTimesListJamaat.isEmpty &&
              todayPrayerTimes == null) {
            return const Center(
              child: CircularProgressIndicator(color: gold),
            );
          }

          // If there was an error but we still have cached/local data,
          // allow the UI to render instead of blocking the screen
          if (hasError &&
              monthlyPrayerTimesList.isEmpty &&
              prayerTimesListJamaat.isEmpty) {
            return Center(
              child: Text(
                'Failed to load prayer times',
                style: const TextStyle(color: gold, fontSize: 15),
              ),
            );
          }

          // ── Data logic (unchanged) ────────────────────────────────
          final DateTime now = DateTime.now();
          List<String> beginningTimes = [];
          List<String> jamaatTimes = [];
          List<String>? jummahTime;

          for (var pt in prayerTimesListJamaat) {
            final d = DateFormat('yyyy-MM-dd').parse(pt.date);
            if (d.year == _displayDate.year &&
                d.month == _displayDate.month &&
                d.day == _displayDate.day) {
              jamaatTimes = [
                pt.fajr,
                pt.sunrise,
                pt.dhuhr,
                pt.asr,
                pt.maghrib,
                pt.isha
              ];
              jummahTime = pt.jummahTimes;
              break;
            }
          }

          for (var pt in monthlyPrayerTimesList) {
            final d = DateFormat('dd-MM-yyyy').parse(pt.date);
            if (d.year == _displayDate.year &&
                d.month == _displayDate.month &&
                d.day == _displayDate.day) {
              beginningTimes = [
                pt.fajr,
                pt.sunrise,
                pt.dhuhr,
                pt.asr,
                pt.maghrib,
                pt.isha
              ];
              break;
            }
          }

          String bv(int i) =>
              beginningTimes.isNotEmpty ? beginningTimes[i] : '--';
          String jv(int i) => jamaatTimes.isNotEmpty ? jamaatTimes[i] : '--';

          final List<PrayerTime> rows = [
            PrayerTime('Fajr', bv(0), jv(0)),
            PrayerTime('Sunrise', bv(1), jv(1)),
            PrayerTime(
                _displayDate.weekday == DateTime.friday ? "Jumu'ah" : 'Dhuhr',
                bv(2),
                jv(2)),
            PrayerTime('Asr', bv(3), jv(3)),
            PrayerTime('Maghrib', bv(4), jv(4)),
            PrayerTime('Isha', bv(5), jv(5)),
          ];

          if (todayPrayerTimes != null) {
            final times = [
              todayPrayerTimes!.fajr,
              todayPrayerTimes!.sunrise,
              todayPrayerTimes!.dhuhr,
              todayPrayerTimes!.asr,
              todayPrayerTimes!.maghrib,
              todayPrayerTimes!.isha,
            ];
            const names = [
              'Fajr',
              'Sunrise',
              'Dhuhr',
              'Asr',
              'Maghrib',
              'Isha'
            ];
            bool found = false;
            for (int i = 0; i < times.length; i++) {
              final p = times[i].split(':');
              final pt = DateTime(now.year, now.month, now.day, int.parse(p[0]),
                  int.parse(p[1]));
              if (pt.isAfter(now)) {
                nextPrayerName = names[i];
                final rem = pt.difference(now);
                timeRemaining =
                    '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
                found = true;
                break;
              }
            }
            if (!found) {
              nextPrayerName = 'Fajr';
              final p = todayPrayerTimes!.fajr.split(':');
              final nextFajr = DateTime(now.year, now.month, now.day + 1,
                  int.parse(p[0]), int.parse(p[1]));
              final rem = nextFajr.difference(now);
              timeRemaining = '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
            }
          }

          // ══════════════════════════════════════════════════════════
          // UI — hero takes ~42% of screen, table the remaining ~58%
          // ══════════════════════════════════════════════════════════
          return Column(
            children: [
              // ── HERO — flex 42 ─────────────────────────────────────
              if (loading && change)
                Container(
                  width: double.infinity,
                  color: navyMid,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            color: gold, strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Updating prayer times, please wait a coule seconds…',
                        style: TextStyle(
                            color: gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              Flexible(
                flex: 42,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(26),
                      bottomRight: Radius.circular(26),
                    ),
                    border: Border(
                      bottom:
                          BorderSide(color: gold.withOpacity(0.45), width: 1.5),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Town name
                      Text(townName,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          )),
                      _buildMosqueNameRow(),

                      // Next + Remaining cards — tall, prominent
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            // Next prayer
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: navyMid,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: gold.withOpacity(0.5), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                              color: skyBlue,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      const Text('NEXT PRAYER',
                                          style: TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 1.4,
                                              fontWeight: FontWeight.w700,
                                              color: skyBlue)),
                                    ]),
                                    const SizedBox(height: 8),
                                    Text(nextPrayerName,
                                        style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: white,
                                            letterSpacing: 0.3)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Remaining — shows a big countdown
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: navyMid,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: gold.withOpacity(0.5), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                              color: mintGreen,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      const Text('TIME LEFT',
                                          style: TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 1.4,
                                              fontWeight: FontWeight.w700,
                                              color: mintGreen)),
                                    ]),
                                    const SizedBox(height: 8),
                                    _PrayerCountdown(
                                      nextPrayerName: nextPrayerName,
                                      prayerTimes: todayPrayerTimes,
                                      textStyle: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: white,
                                          letterSpacing: 0.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Until $nextPrayerName',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: mintGreen.withOpacity(0.85),
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Settings + Today buttons
                      // Settings + Today + Navigate buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _settingsPageGoTo,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: gold,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: gold.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.settings_outlined,
                                        size: 16, color: navy),
                                    SizedBox(width: 6),
                                    Text('Settings',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: navy)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _todayDisplayDate,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: white.withOpacity(0.22), width: 1),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.today_outlined,
                                        size: 16, color: white),
                                    SizedBox(width: 6),
                                    Text('Go to Today',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (mosqueLat != null && mosqueLong != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () =>
                                  openNavigation(mosqueLat!, mosqueLong!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: skyBlue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: skyBlue.withOpacity(0.5),
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: skyBlue.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions_car_outlined,
                                        size: 16, color: skyBlue),
                                    SizedBox(width: 5),
                                    Text('Go To',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: skyBlue)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Date navigator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 6),
                        decoration: BoxDecoration(
                          color: navyLight.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: gold.withOpacity(0.28), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _decrementDisplayDate,
                              icon: const Icon(Icons.arrow_back_ios_rounded,
                                  color: gold, size: 15),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      DateFormat('EEEE, d MMM yyyy')
                                          .format(_displayDate),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2)),
                                  if (_hijriDate.isNotEmpty)
                                    Text(
                                      _hijriDate,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: gold.withOpacity(0.75),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _incrementDisplayDate,
                              icon: const Icon(Icons.arrow_forward_ios_rounded,
                                  color: gold, size: 15),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // At the top of your table build, add this banner if no mosque is set:
              if (prayerTimesListJamaat.isEmpty)
                Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: navyMid,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gold.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mosque_outlined,
                          size: 15, color: gold.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Select a mosque from the home screen to see Jamaat times',
                          style: TextStyle(fontSize: 10.5, color: gold),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── TABLE — flex 58 — rows fill every pixel ─────────────
              Flexible(
                flex: 58,
                child: Container(
                  color: offWhite,
                  child: todayPrayerTimes != null
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 11, horizontal: 14),
                              decoration: BoxDecoration(
                                color: navy,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                ),
                                border: Border.all(
                                    color: gold.withOpacity(0.5), width: 1.5),
                              ),
                              child: Row(children: [
                                headerCell('Salaah', TextAlign.left),
                                headerCell('Beginning', TextAlign.center),
                                headerCell("Jama'ah", TextAlign.center),
                                headerCell("Adhan/Jama'ah", TextAlign.right),
                              ]),
                            ),

                            // Rows — Expanded column, each row equal share
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: white,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                  border: Border.all(color: border, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: navy.withOpacity(0.07),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: rows.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final prayer = entry.value;
                                    final bool isNext =
                                        prayer.name == nextPrayerName;
                                    final bool isLast =
                                        index == rows.length - 1;

                                    return Expanded(
                                      child: Column(children: [
                                        Expanded(
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            color: isNext
                                                ? navy.withOpacity(0.05)
                                                : Colors.transparent,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14),
                                            child: Row(children: [
                                              // Name
                                              Expanded(
                                                child: Row(children: [
                                                  if (isNext)
                                                    Container(
                                                      width: 3,
                                                      height: 24,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              right: 8),
                                                      decoration: BoxDecoration(
                                                          color: gold,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(2)),
                                                    ),
                                                  Text(prayer.name,
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight: isNext
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: isNext
                                                            ? navy
                                                            : textDark,
                                                      )),
                                                ]),
                                              ),

                                              // Beginning
                                              Expanded(
                                                child: Center(
                                                  child: timeChip(
                                                    prayer.time,
                                                    isNext: isNext,
                                                    bg: isNext
                                                        ? skyLight
                                                        : offWhite,
                                                    textColor: isNext
                                                        ? const Color.fromARGB(
                                                            255, 30, 90, 160)
                                                        : textMid,
                                                    borderColor: isNext
                                                        ? skyBlue
                                                            .withOpacity(0.5)
                                                        : border,
                                                  ),
                                                ),
                                              ),

                                              // Jamaat
                                              Expanded(
                                                child: Center(
                                                  child: prayer.name ==
                                                              "Jumu'ah" &&
                                                          jummahTime != null &&
                                                          jummahTime!.isNotEmpty
                                                      ? PopupMenuButton<void>(
                                                          color: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10)),
                                                          offset: const Offset(
                                                              0, 32),
                                                          itemBuilder: (_) {
                                                            final labels = [
                                                              '1st',
                                                              '2nd',
                                                              '3rd',
                                                              '4th'
                                                            ];
                                                            return jummahTime!
                                                                .asMap()
                                                                .entries
                                                                .map((e) {
                                                              final label = e
                                                                          .key <
                                                                      labels
                                                                          .length
                                                                  ? labels[
                                                                      e.key]
                                                                  : '${e.key + 1}th';
                                                              return PopupMenuItem<
                                                                  void>(
                                                                child: Text(
                                                                  '$label  ${e.value}',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Color
                                                                        .fromARGB(
                                                                            255,
                                                                            15,
                                                                            30,
                                                                            65),
                                                                  ),
                                                                ),
                                                              );
                                                            }).toList();
                                                          },
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        9,
                                                                    vertical:
                                                                        5),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: offWhite,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              border: Border.all(
                                                                  color:
                                                                      border),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                    jummahTime![
                                                                        0],
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w500,
                                                                        color:
                                                                            textMid)),
                                                                const SizedBox(
                                                                    width: 3),
                                                                const Icon(
                                                                    Icons
                                                                        .expand_more,
                                                                    size: 13,
                                                                    color:
                                                                        textMid),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                      : timeChip(
                                                          prayer.jamaatTime,
                                                          isNext: isNext,
                                                          bg: isNext
                                                              ? mintLight
                                                              : offWhite,
                                                          textColor: isNext
                                                              ? const Color
                                                                  .fromARGB(255,
                                                                  20, 120, 85)
                                                              : textMid,
                                                          borderColor: isNext
                                                              ? mintGreen
                                                                  .withOpacity(
                                                                      0.5)
                                                              : border,
                                                        ),
                                                ),
                                              ),

                                              // Notification
                                              _buildBellPair(index),
                                            ]),
                                          ),
                                        ),
                                        if (!isLast)
                                          const Divider(
                                              height: 1, color: border),
                                      ]),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ]),
                        )

                      // ── Empty state ──────────────────────────────────
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 52, color: textMid.withOpacity(0.35)),
                              const SizedBox(height: 16),
                              const Text(
                                'No prayer times available\nfor this date.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: textMid, fontSize: 16, height: 1.5),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: _todayDisplayDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: navy,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: gold.withOpacity(0.5),
                                        width: 1.5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded,
                                          size: 17, color: gold),
                                      SizedBox(width: 8),
                                      Text('Go to Today',
                                          style: TextStyle(
                                              color: gold,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBellPair(int index) {
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldLight = Color.fromARGB(255, 255, 248, 225);
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color offWhite = Color.fromARGB(255, 247, 248, 252);
    const Color border = Color.fromARGB(255, 220, 224, 235);
    const Color textMid = Color.fromARGB(255, 110, 120, 150);
    const Color mintGreen = Color.fromARGB(255, 60, 200, 140);
    const Color mintLight = Color.fromARGB(255, 230, 255, 245);
    const Color errorRed = Color.fromARGB(255, 200, 60, 60);

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // ── Beginning bell ───────────────────────────────────────────────
          _bellButton(
            isOn: notifBeginningOn[index],
            isLoading: notifBeginningLoading[index],
            result: notifBeginningResult[index],
            onTap: () => _toggleBeginning(index),
            tooltip: 'Beginning time notification',
            activeColor: gold,
            activeLight: goldLight,
            navy: navy,
            offWhite: offWhite,
            border: border,
            textMid: textMid,
            errorRed: errorRed,
          ),

          const SizedBox(width: 6),

          // ── Jama'ah bell (with badge) ────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              _bellButton(
                isOn: notifJamaahOn[index],
                isLoading: notifJamaahLoading[index],
                result: notifJamaahResult[index],
                onTap: () => _toggleJamaah(index),
                tooltip: "Jama'ah reminder",
                activeColor: mintGreen,
                activeLight: mintLight,
                navy: navy,
                offWhite: offWhite,
                border: border,
                textMid: textMid,
                errorRed: errorRed,
                isJamaah: true,
              ),

              // Minutes badge — only shown when jama'ah is ON
              if (notifJamaahOn[index])
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: navy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: mintGreen.withOpacity(0.7), width: 1),
                    ),
                    child: Text(
                      '${notifJamaahMins[index]}m',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 60, 200, 140),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

// ─────────────────────────────────────────────────────────────────────────────
// 13. HELPER WIDGET — single animated bell button (reused for both bells)
// ─────────────────────────────────────────────────────────────────────────────

  Widget _bellButton({
    required bool isOn,
    required bool isLoading,
    required bool? result,
    required VoidCallback onTap,
    required String tooltip,
    required Color activeColor,
    required Color activeLight,
    required Color navy,
    required Color offWhite,
    required Color border,
    required Color textMid,
    required Color errorRed,
    bool isJamaah = false,
  }) {
    // Determine icon / content
    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isOn ? activeColor : textMid,
        ),
      );
    } else if (result != null) {
      // Brief feedback icon
      child = Icon(
        result ? Icons.check_rounded : Icons.close_rounded,
        size: 16,
        color: result ? activeColor : errorRed,
      );
    } else {
      child = Icon(
        isOn
            ? Icons.notifications_active_rounded
            : isJamaah
                ? Icons.access_time_rounded
                : Icons.notifications_off_outlined,
        size: 16,
        color: isOn ? activeColor : textMid,
      );
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isOn ? activeLight : offWhite,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isOn ? activeColor.withOpacity(0.6) : border,
              width: 1,
            ),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Self-contained countdown widget ──────────────────────────────────────────
// Owns its own 1-second timer so the parent screen never rebuilds on each tick.
class _PrayerCountdown extends StatefulWidget {
  final String nextPrayerName;
  final PrayerTimes? prayerTimes;
  final TextStyle textStyle;

  const _PrayerCountdown({
    required this.nextPrayerName,
    required this.prayerTimes,
    required this.textStyle,
  });

  @override
  State<_PrayerCountdown> createState() => _PrayerCountdownState();
}

class _PrayerCountdownState extends State<_PrayerCountdown> {
  Timer? _timer;
  String _display = '';

  @override
  void initState() {
    super.initState();
    _update();
    final msUntilNextSecond = 1000 - DateTime.now().millisecond;
    Future.delayed(Duration(milliseconds: msUntilNextSecond), () {
      if (!mounted) return;
      _update();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _update();
      });
    });
  }

  @override
  void didUpdateWidget(_PrayerCountdown old) {
    super.didUpdateWidget(old);
    if (old.nextPrayerName != widget.nextPrayerName ||
        old.prayerTimes != widget.prayerTimes) {
      _update();
    }
  }

  void _update() {
    if (widget.prayerTimes == null) return;
    final now = DateTime.now();

    final timeStrs = [
      widget.prayerTimes!.fajr,
      widget.prayerTimes!.sunrise,
      widget.prayerTimes!.dhuhr,
      widget.prayerTimes!.asr,
      widget.prayerTimes!.maghrib,
      widget.prayerTimes!.isha,
    ];
    final names = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    DateTime? target;
    for (int i = 0; i < timeStrs.length; i++) {
      final parts = timeStrs[i].split(':');
      if (parts.length < 2) continue;
      final t = DateTime(now.year, now.month, now.day, int.parse(parts[0]),
          int.parse(parts[1]));
      if (t.isAfter(now)) {
        target = t;
        break;
      }
    }
    // After Isha — count down to next day's Fajr
    if (target == null) {
      final parts = widget.prayerTimes!.fajr.split(':');
      target = DateTime(now.year, now.month, now.day + 1, int.parse(parts[0]),
          int.parse(parts[1]));
    }

    final remaining = target.difference(now);
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final str = h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
    if (mounted) setState(() => _display = str);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_display, style: widget.textStyle);
  }
}

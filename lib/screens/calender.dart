import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/dailyActivities.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class DailyActivity {
  final DateTime date;
  final Map<String, bool> prayers;
  bool isFasting;
  int quranPagesRead;
  bool zikrCount;

  DailyActivity({
    required this.date,
    required this.prayers,
    this.isFasting = false,
    this.quranPagesRead = 0,
    this.zikrCount = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'prayers': prayers,
      'isFasting': isFasting,
      'quranPagesRead': quranPagesRead,
      'zikrCount': zikrCount,
    };
  }

  static DailyActivity fromMap(Map<String, dynamic> map) {
    return DailyActivity(
      date: DateTime.parse(map['date']),
      prayers: Map<String, bool>.from(map['prayers']),
      isFasting: map['isFasting'],
      quranPagesRead: map['quranPagesRead'],
      zikrCount: map['zikrCount'],
    );
  }
}

Map<DateTime, DailyActivity> dailyActivities = {};

Future<void> saveDailyActivitiesToSharedPreferences(
    SharedPreferences prefs) async {
  String serializedActivities = jsonEncode(dailyActivities.map((key, activity) {
    return MapEntry(key.toIso8601String(), jsonEncode(activity.toMap()));
  }));

  await prefs.setString('daily_activities', serializedActivities);
}

class _CalendarScreenState extends State<CalendarScreen> {
  Map<DateTime, String> _hijriDates = {};
  List<Map<String, dynamic>> _importantDates = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();

  // ── Hijri calendar adjustment (Aladhan ?adjustment= param) ───────────────
  // -2 to +2 days, 0 = default. Persisted in SharedPreferences.
  int _hijriAdjustment = 0;
  static const String _kAdjustmentKey = 'hijri_adjustment';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    _hijriAdjustment = prefs.getInt(_kAdjustmentKey) ?? 0;
    await loadDailyActivitiesFromSharedPreferences(prefs); // Load activities
    fetchFullYearHijriCalendar(DateTime.now().year); // Fetch Hijri calendar
  }

  Future<void> saveHijriCalendarToSharedPreferences(
      SharedPreferences prefs) async {
    String hijriDatesJson = jsonEncode(_hijriDates
        .map((key, value) => MapEntry(key.toIso8601String(), value)));
    String importantDatesJson = jsonEncode(_importantDates.map((event) => {
          'date': event['date'].toIso8601String(),
          'event': event['event'],
        }));

    await prefs.setString('hijri_dates', hijriDatesJson);
    await prefs.setString('important_dates', importantDatesJson);
  }

  Future<bool> loadHijriCalendarFromSharedPreferences(
      SharedPreferences prefs) async {
    String? hijriDatesJson = prefs.getString('hijri_dates');
    String? importantDatesJson = prefs.getString('important_dates');

    if (hijriDatesJson != null && importantDatesJson != null) {
      Map<String, dynamic> hijriDatesMap = jsonDecode(hijriDatesJson);
      _hijriDates = hijriDatesMap
          .map((key, value) => MapEntry(DateTime.parse(key), value));

      List<dynamic> importantDatesList = jsonDecode(importantDatesJson);
      _importantDates = importantDatesList.map<Map<String, dynamic>>((event) {
        return {
          'date': DateTime.parse(event['date']),
          'event': event['event'],
        };
      }).toList();

      return true;
    }

    return false;
  }

  Future<void> loadDailyActivitiesFromSharedPreferences(
      SharedPreferences prefs) async {
    String? serializedActivities = prefs.getString('daily_activities');

    if (serializedActivities != null) {
      Map<String, dynamic> activitiesMap = jsonDecode(serializedActivities);

      activitiesMap.forEach((key, value) {
        DateTime date = DateTime.parse(key);
        Map<String, dynamic> activityMap = jsonDecode(value);
        dailyActivities[date] = DailyActivity.fromMap(activityMap);
      });
    }
  }

  Future<void> fetchHijriCalendar(int month, int year) async {
    final prefs = await SharedPreferences.getInstance();

    await loadDailyActivitiesFromSharedPreferences(prefs);

    bool dataLoaded = await loadHijriCalendarFromSharedPreferences(prefs);
    if (dataLoaded) {
      setState(() => _isLoading = false);
      return;
    }

    final String url = 'https://api.aladhan.com/v1/gToHCalendar/$month/$year'
        '${_hijriAdjustment != 0 ? '?adjustment=$_hijriAdjustment' : ''}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          List<dynamic> dates = data['data'];

          for (var date in dates) {
            String gregorianDate = date['gregorian']['date'];
            String hijriDate = date['hijri']['date'];

            DateTime parsedDate = DateTime.parse(
                "${gregorianDate.substring(6)}-${gregorianDate.substring(3, 5)}-${gregorianDate.substring(0, 2)}");
            DateTime normalizedDate =
                DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

            if (!dailyActivities.containsKey(normalizedDate)) {
              dailyActivities[normalizedDate] = DailyActivity(
                date: normalizedDate,
                prayers: {
                  'Fajr': false,
                  'Dhuhr': false,
                  'Asr': false,
                  'Maghrib': false,
                  'Isha': false,
                },
                isFasting: false,
                quranPagesRead: 0,
                zikrCount: false,
              );
            }

            _hijriDates[normalizedDate] = hijriDate;

            if (date['hijri'].containsKey('holidays')) {
              List holidays = date['hijri']['holidays'];
              if (holidays.isNotEmpty) {
                for (var holiday in holidays) {
                  if (!holiday.toLowerCase().contains('urs') &&
                      !holiday.toLowerCase().contains('birth')) {
                    _importantDates.add({
                      'date': normalizedDate,
                      'event': holiday,
                    });
                  }
                }
              }
            }
          }

          await saveHijriCalendarToSharedPreferences(prefs);
        } else {
          print("Error: ${data['status']}");
        }
      } else {
        print("Failed to load calendar: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchFullYearHijriCalendar(int year) async {
    for (int month = 1; month <= 12; month++) {
      await fetchHijriCalendar(month, year);
    }
    final prefs = await SharedPreferences.getInstance();
    await loadDailyActivitiesFromSharedPreferences(prefs);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── Clear cached hijri data and re-fetch with new adjustment ─────────────
  Future<void> _clearAndRefetch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hijri_dates');
    await prefs.remove('important_dates');
    setState(() {
      _hijriDates = {};
      _importantDates = [];
      _isLoading = true;
    });
    await fetchFullYearHijriCalendar(DateTime.now().year);
  }

  // ── Calendar settings bottom sheet ───────────────────────────────────────
  Future<void> _openCalendarSettings() async {
    int tempAdj = _hijriAdjustment;

    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldLight = Color.fromARGB(255, 252, 243, 210);
    const Color offWhite = Color.fromARGB(255, 247, 249, 255);
    const Color textDark = Color.fromARGB(255, 15, 30, 65);
    const Color textMid = Color.fromARGB(255, 90, 115, 160);
    const Color border = Color.fromARGB(255, 210, 220, 240);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: offWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMid.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withOpacity(0.35), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child:
                          const Icon(Icons.tune_rounded, color: gold, size: 25),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Calendar Settings',
                              style: TextStyle(
                                  color: gold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Adjust Hijri date display',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Hijri Adjustment ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: goldLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.calendar_today_outlined,
                              size: 14, color: navy),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hijri Date Adjustment',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textDark)),
                              Text('Shift the displayed Hijri date by ±2 days',
                                  style:
                                      TextStyle(fontSize: 11, color: textMid)),
                            ],
                          ),
                        ),
                        // Current value badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: tempAdj == 0
                                ? const Color.fromARGB(255, 220, 235, 255)
                                : goldLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tempAdj == 0
                                  ? const Color.fromARGB(255, 80, 120, 200)
                                      .withOpacity(0.4)
                                  : gold.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tempAdj == 0
                                ? 'Default'
                                : tempAdj > 0
                                    ? '+$tempAdj day${tempAdj == 1 ? '' : 's'}'
                                    : '$tempAdj day${tempAdj == -1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tempAdj == 0
                                  ? const Color.fromARGB(255, 40, 80, 180)
                                  : const Color.fromARGB(255, 140, 105, 30),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor:
                            const Color.fromARGB(255, 212, 175, 95),
                        inactiveTrackColor:
                            const Color.fromARGB(255, 212, 175, 95)
                                .withOpacity(0.2),
                        thumbColor: navy,
                        overlayColor: gold.withOpacity(0.15),
                        valueIndicatorColor: navy,
                        valueIndicatorTextStyle:
                            const TextStyle(color: gold, fontSize: 13),
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: tempAdj.toDouble(),
                        min: -2,
                        max: 2,
                        divisions: 4,
                        label: tempAdj == 0
                            ? 'Default'
                            : tempAdj > 0
                                ? '+$tempAdj'
                                : '$tempAdj',
                        onChanged: (v) => setS(() => tempAdj = v.round()),
                      ),
                    ),
                    // Tick labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['-2', '-1', '0', '+1', '+2']
                            .map((l) => Text(l,
                                style: const TextStyle(
                                    fontSize: 10, color: textMid)))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Info box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 220, 240, 255),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: const Color.fromARGB(255, 100, 180, 240)
                                .withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 13,
                              color: Color.fromARGB(255, 30, 90, 160)),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Hijri dates can differ by ±1–2 days depending on '
                              'moon sighting convention. Use this to match your '
                              'local Islamic authority.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color.fromARGB(255, 30, 90, 160),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Action buttons ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: textMid, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (tempAdj == _hijriAdjustment) return;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(_kAdjustmentKey, tempAdj);
                        setState(() => _hijriAdjustment = tempAdj);
                        await _clearAndRefetch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: gold,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Apply',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Palette ────────────────────────────────────────────────────────
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color navyLight = Color.fromARGB(255, 28, 58, 120);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldLight = Color.fromARGB(255, 252, 243, 210);
    const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
    const Color skyLight = Color.fromARGB(255, 220, 240, 255);
    const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
    const Color white = Color.fromARGB(255, 255, 255, 255);
    const Color offWhite = Color.fromARGB(255, 247, 249, 255);
    const Color textDark = Color.fromARGB(255, 15, 30, 65);
    const Color textMid = Color.fromARGB(255, 90, 115, 160);
    const Color border = Color.fromARGB(255, 210, 220, 240);

    final filteredImportantDates = _importantDates.where((event) {
      DateTime eventDate = event['date'];
      return eventDate.month == _focusedDay.month &&
          eventDate.year == _focusedDay.year;
    }).toList();

    return Scaffold(
      backgroundColor: navy,
      appBar: buildAppBar(
          context, 'Calendar', const MoreOptionsScreen(), screenFrom),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : Column(
              children: [
                // ── HERO — calendar lives here ──────────────────────────
                Container(
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  child: Column(
                    children: [
                      // Hint bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 7, horizontal: 14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: navyMid,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: gold.withOpacity(0.28), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined,
                                size: 16, color: gold.withOpacity(0.75)),
                            const SizedBox(width: 7),
                            Text(
                              'Select a date to set or view your daily activities',
                              style: TextStyle(
                                fontSize: 14,
                                color: white,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _openCalendarSettings,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: gold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: gold.withOpacity(0.3), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune_rounded,
                                        size: 13, color: gold.withOpacity(0.9)),
                                    if (_hijriAdjustment != 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        _hijriAdjustment > 0
                                            ? '+$_hijriAdjustment'
                                            : '$_hijriAdjustment',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: gold.withOpacity(0.9)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // TableCalendar
                      TableCalendar(
                        focusedDay: _focusedDay,
                        firstDay: DateTime(_focusedDay.year, 1, 1),
                        lastDay: DateTime(_focusedDay.year, 12, 31),
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        onPageChanged: (day) =>
                            setState(() => _focusedDay = day),

                        onDaySelected: (selectedDay, focusedDay) async {
                          DateTime normalizedDay = DateTime(selectedDay.year,
                              selectedDay.month, selectedDay.day);
                          DailyActivity? selectedActivity =
                              dailyActivities[normalizedDay];
                          if (selectedActivity == null) {
                            selectedActivity = DailyActivity(
                              date: normalizedDay,
                              prayers: {
                                'Fajr': false,
                                'Dhuhr': false,
                                'Asr': false,
                                'Maghrib': false,
                                'Isha': false,
                              },
                              isFasting: false,
                              quranPagesRead: 0,
                              zikrCount: false,
                            );
                            dailyActivities[normalizedDay] = selectedActivity;
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => dailyActivitiesScreen(
                                selectedDate: normalizedDay,
                                dailyActivity: selectedActivity,
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        },

                        // ── Header ──────────────────────────────────────
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: const TextStyle(
                            color: gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          leftChevronIcon: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: gold.withOpacity(0.85),
                            size: 15,
                          ),
                          rightChevronIcon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: gold.withOpacity(0.85),
                            size: 15,
                          ),
                          headerPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: navyMid,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: gold.withOpacity(0.3), width: 1),
                          ),
                        ),

                        // ── Days of week row ─────────────────────────────
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: skyBlue.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendStyle: TextStyle(
                            color: gold.withOpacity(0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        calendarStyle: const CalendarStyle(
                          outsideDaysVisible: false,
                          cellMargin: EdgeInsets.all(2),
                          // Defaults hidden behind calendarBuilders
                          todayDecoration:
                              BoxDecoration(color: Colors.transparent),
                          selectedDecoration:
                              BoxDecoration(color: Colors.transparent),
                        ),

                        // ── Day cells ────────────────────────────────────
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final norm = DateTime(day.year, day.month, day.day);
                            final String hijri = _hijriDates[norm] ?? "";
                            final DailyActivity? activity =
                                dailyActivities[norm];
                            final int done = activity != null
                                ? activity.prayers.values
                                    .where((v) => v == true)
                                    .length
                                : 0;

                            return _dayCell(
                              day: day.day,
                              hijri: hijri,
                              prayersDone: done,
                              hasFasted: activity?.isFasting ?? false,
                              bg: navyMid.withOpacity(0.75),
                              dayColor: white,
                              hijriColor: gold.withOpacity(0.6),
                              borderColor: done > 0
                                  ? mintGreen.withOpacity(0.3)
                                  : white.withOpacity(0.07),
                            );
                          },

                          // Today
                          todayBuilder: (context, day, focusedDay) {
                            final norm = DateTime(day.year, day.month, day.day);
                            final String hijri = _hijriDates[norm] ?? "";
                            final DailyActivity? activity =
                                dailyActivities[norm];
                            final int done = activity != null
                                ? activity.prayers.values
                                    .where((v) => v == true)
                                    .length
                                : 0;
                            return _dayCell(
                              day: day.day,
                              hijri: hijri,
                              prayersDone: done,
                              hasFasted: activity?.isFasting ?? false,
                              bg: navyLight,
                              dayColor: gold,
                              hijriColor: gold.withOpacity(0.7),
                              borderColor: gold,
                              borderWidth: 1.5,
                            );
                          },

                          // Selected
                          selectedBuilder: (context, day, focusedDay) {
                            final norm = DateTime(day.year, day.month, day.day);
                            final String hijri = _hijriDates[norm] ?? "";
                            final DailyActivity? activity =
                                dailyActivities[norm];
                            final int done = activity != null
                                ? activity.prayers.values
                                    .where((v) => v == true)
                                    .length
                                : 0;
                            return _dayCell(
                              day: day.day,
                              hijri: hijri,
                              prayersDone: done,
                              hasFasted: activity?.isFasting ?? false,
                              bg: gold,
                              dayColor: navy,
                              hijriColor: navy.withOpacity(0.6),
                              borderColor: Colors.transparent,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ── ISLAMIC DATES LIST ──────────────────────────────────
                Expanded(
                  child: Container(
                    color: offWhite,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.star_outline_rounded,
                                  size: 15, color: navy),
                              const SizedBox(width: 7),
                              Text(
                                'ISLAMIC DATES  ·  ${DateFormat('MMMM yyyy').format(_focusedDay).toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.3,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                              const Spacer(),
                              if (filteredImportantDates.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: goldLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: gold.withOpacity(0.4), width: 1),
                                  ),
                                  child: Text(
                                    '${filteredImportantDates.length} event${filteredImportantDates.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color.fromARGB(255, 140, 105, 30),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // List or empty state
                        Expanded(
                          child: filteredImportantDates.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.event_available_outlined,
                                          size: 44,
                                          color: textMid.withOpacity(0.35)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No Islamic events this month',
                                        style: TextStyle(
                                          color: textMid,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                  itemCount: filteredImportantDates.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1, color: border),
                                  itemBuilder: (context, index) {
                                    final event = filteredImportantDates[index];
                                    final DateTime eventDate = event['date'];
                                    final String eventName = event['event'];

                                    final bool isToday =
                                        eventDate.year == DateTime.now().year &&
                                            eventDate.month ==
                                                DateTime.now().month &&
                                            eventDate.day == DateTime.now().day;
                                    final bool isPast = eventDate.isBefore(
                                        DateTime(
                                            DateTime.now().year,
                                            DateTime.now().month,
                                            DateTime.now().day));
                                    final int daysUntil = eventDate
                                        .difference(DateTime(
                                            DateTime.now().year,
                                            DateTime.now().month,
                                            DateTime.now().day))
                                        .inDays;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        children: [
                                          // Date badge
                                          Container(
                                            width: 46,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 7),
                                            decoration: BoxDecoration(
                                              color: isToday
                                                  ? navy
                                                  : isPast
                                                      ? offWhite
                                                      : skyLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isToday
                                                    ? gold.withOpacity(0.6)
                                                    : isPast
                                                        ? border
                                                        : skyBlue
                                                            .withOpacity(0.4),
                                                width: isToday ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${eventDate.day}',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: isToday
                                                        ? gold
                                                        : isPast
                                                            ? textMid
                                                            : const Color
                                                                .fromARGB(255,
                                                                30, 90, 160),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                Text(
                                                  DateFormat('MMM')
                                                      .format(eventDate)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                    color: isToday
                                                        ? gold.withOpacity(0.75)
                                                        : isPast
                                                            ? textMid
                                                                .withOpacity(
                                                                    0.6)
                                                            : const Color
                                                                .fromARGB(255,
                                                                30, 90, 160),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 12),

                                          // Event name + date
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  eventName,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: isPast
                                                        ? textMid
                                                        : textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat.yMMMMd()
                                                      .format(eventDate),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: textMid),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Status pill
                                          if (isToday)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: navy,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color:
                                                        gold.withOpacity(0.5),
                                                    width: 1),
                                              ),
                                              child: const Text('Today',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: gold)),
                                            )
                                          else if (!isPast)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: skyLight,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: skyBlue
                                                        .withOpacity(0.4),
                                                    width: 1),
                                              ),
                                              child: Text(
                                                daysUntil == 0
                                                    ? 'Tomorrow'
                                                    : 'In ${daysUntil}d',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color.fromARGB(
                                                      255, 30, 90, 160),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Day cell builder helper ───────────────────────────────────────────
  Widget _dayCell({
    required int day,
    required String hijri,
    required int prayersDone,
    required bool hasFasted,
    required Color bg,
    required Color dayColor,
    required Color hijriColor,
    required Color borderColor,
    double borderWidth = 1.0,
  }) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: dayColor,
            ),
          ),
          if (hijri.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                hijri,
                style: TextStyle(fontSize: 8, color: hijriColor),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Prayer dots — one per prayer completed, up to 5
          if (prayersDone > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  prayersDone.clamp(0, 5),
                  (_) => Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 0.7),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 72, 200, 155),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          // Small gold dot if fasted
          if (hasFasted)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 1),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 212, 175, 95),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

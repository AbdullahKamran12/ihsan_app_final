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

  @override
  void initState() {
    super.initState();
    _initializeData();
    fetchFullYearHijriCalendar(DateTime.now().year);
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
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

    final String url = 'https://api.aladhan.com/v1/gToHCalendar/$month/$year';

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

  @override
  Widget build(BuildContext context) {
    final filteredImportantDates = _importantDates.where((event) {
      DateTime eventDate = event['date'];
      return eventDate.month == _focusedDay.month &&
          eventDate.year == _focusedDay.year;
    }).toList();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(
          context, 'Calendar', const MoreOptionsScreen(), screenFrom),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Select a date to set or change your daily activities",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      )
                    ],
                  ),
                  Container(
                    height: 400,
                    child: TableCalendar(
                      focusedDay: _focusedDay,
                      firstDay: DateTime(_focusedDay.year, 1, 1),
                      lastDay: DateTime(_focusedDay.year, 12, 31),
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                      ),
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        // Normalize the selected day to remove time information
                        DateTime normalizedDay = DateTime(selectedDay.year,
                            selectedDay.month, selectedDay.day);

                        // Check if an activity exists for the selected day
                        DailyActivity? selectedActivity =
                            dailyActivities[normalizedDay];

                        // If no activity exists, create a new one
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

                          // Add the new activity to the dailyActivities map
                          dailyActivities[normalizedDay] = selectedActivity;
                        }

                        // Navigate to the dailyActivitiesScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => dailyActivitiesScreen(
                              selectedDate: normalizedDay,
                              dailyActivity: selectedActivity,
                            ),
                          ),
                        );
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          DateTime normalizedDay =
                              DateTime(day.year, day.month, day.day);
                          String hijriDate = _hijriDates[normalizedDay] ?? "";

                          DailyActivity? dailyActivity =
                              dailyActivities[normalizedDay];

                          return Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(minHeight: 70),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${day.day}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hijriDate.isNotEmpty ? hijriDate : "",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredImportantDates.isEmpty
                        ? Center(
                            child: Text(
                                "No important Islamic dates found for this month."))
                        : ListView.builder(
                            itemCount: filteredImportantDates.length,
                            itemBuilder: (context, index) {
                              final event = filteredImportantDates[index];
                              DateTime eventDate = event['date'];
                              String eventName = event['event'];
                              return ListTile(
                                leading: const Icon(Icons.event,
                                    color: Colors.white),
                                title: Text(eventName),
                                subtitle:
                                    Text(DateFormat.yMMMd().format(eventDate)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/calender.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class dailyActivitiesScreen extends StatefulWidget {
  final DateTime selectedDate;
  final DailyActivity? dailyActivity;
  const dailyActivitiesScreen(
      {super.key, required this.selectedDate, this.dailyActivity});

  @override
  _dailyActivitiesScreenState createState() => _dailyActivitiesScreenState();
}

class _dailyActivitiesScreenState extends State<dailyActivitiesScreen> {
  late DailyActivity _activity;

  @override
  void initState() {
    super.initState();
    _activity = widget.dailyActivity!;
  }

  void _saveActivity() async {
    setState(() {
      dailyActivities[widget.selectedDate] = _activity;
    });

    final prefs = await SharedPreferences.getInstance();
    await saveDailyActivitiesToSharedPreferences(prefs);
    print(dailyActivities);

    Navigator.pop(context, _activity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(
          context, 'Daily Activity Tracker', const CalendarScreen(), null),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Date: ${widget.selectedDate.toLocal()}"),
            TextFormField(
              initialValue: _activity.quranPagesRead.toString(),
              decoration: InputDecoration(labelText: "Quran Pages Read"),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _activity.quranPagesRead = int.tryParse(value) ?? 0;
                });
              },
            ),
            SwitchListTile(
              title: Text("Zikr Counted"),
              value: _activity.zikrCount,
              onChanged: (bool value) {
                setState(() {
                  _activity.zikrCount = value;
                });
              },
            ),
            SwitchListTile(
              title: Text("Fasting"),
              value: _activity.isFasting,
              onChanged: (bool value) {
                setState(() {
                  _activity.isFasting = value;
                });
              },
            ),
            ..._activity.prayers.keys.map((prayer) {
              return SwitchListTile(
                title: Text(prayer),
                value: _activity.prayers[prayer] ?? false,
                onChanged: (bool value) {
                  setState(() {
                    _activity.prayers[prayer] = value;
                  });
                },
              );
            }).toList(),
            ElevatedButton(
              onPressed: _saveActivity,
              child: Text("Save Activity"),
            ),
          ],
        ),
      ),
    );
  }
}
